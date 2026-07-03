import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/draft_flusher.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/smudge_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/image_placement_layer_restore_state.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/providers/app_provider_tools.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/text_editor_dialog.dart';

part 'canvas_gesture_handler_pixel_brush.dart';
part 'canvas_gesture_handler_state_methods.dart';

/// Handles pointer, pan, and zoom gestures over the canvas widget tree.
class CanvasGestureHandler extends StatefulWidget {
  const CanvasGestureHandler({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<CanvasGestureHandler> createState() => _CanvasGestureHandlerState();
}

class _CanvasGestureHandlerState extends State<CanvasGestureHandler> {
  int _activePointerId = -1;
  final List<int> _activePointers = <int>[];
  double _baseDistance = 0.0;

  /// Whether the active gesture is a paint-mode effect stroke: it reuses the
  /// pixel-brush gesture capture but commits the armed Adjust effect on
  /// pointer-up instead of a smudge/blur dab.
  bool _effectBrushStroke = false;
  Offset? _lastSelectionTapCanvasPosition;
  Duration? _lastSelectionTapTimestamp;

  /// Canvas clip path active when the stroke began (may be null).
  ui.Path? _pixelBrushClipPath;

  /// Intensity captured when the current pixel-brush stroke started.
  double _pixelBrushIntensity = AppInteraction.pixelBrushDefaultIntensity;

  /// Layer state captured before the stroke so it can be restored on undo.
  ImagePlacementLayerRestoreState? _pixelBrushLayerRestoreState;

  /// Which pixel-manipulation mode is active for the current stroke.
  PixelBrushMode _pixelBrushMode = PixelBrushMode.smudge;

  /// Monotonic token that invalidates a stale one-shot commit render when a new
  /// stroke starts (or this one is cleared) while it is still rasterizing.
  int _pixelBrushStrokeGeneration = 0;

  /// Bounds enclosing the stroke's dab footprints; the committed patch's
  /// preferred bounds.
  ui.Rect? _pixelBrushStrokePatchBounds;

  /// All accumulated stroke points since the stroke began (canvas space).
  final List<Offset> _pixelBrushStrokePoints = <Offset>[];
  final Map<int, Offset> _pointerPositions = <int, ui.Offset>{};

  /// The selector math mode active before a modifier-key override was applied.
  /// Non-null only during a modifier-driven selection gesture.
  SelectorMath? _previousSelectorMath;
  double _scaleFactor = 1.0;
  Uint8List? _smudgeSourceBytes;
  int _smudgeSourceHeight = 0;
  int _smudgeSourceRegionLeft = 0;
  int _smudgeSourceRegionTop = 0;
  List<int>? _smudgeSourceSignature;
  int _smudgeSourceWidth = 0;
  @override
  void dispose() {
    // Free the per-session smudge source cache (a full-canvas CPU buffer).
    _clearSmudgeSourceCache();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context, listen: false);
    final AppPreferences appPreferences = AppPreferences.of(context);
    final ShellProvider shellProvider = ShellProvider.of(context);

    return MouseRegion(
      onExit: (final PointerExitEvent _) {
        if (_activePointerId == -1 && appProvider.brushSizePreviewPosition != null) {
          appProvider.hideDrawingToolPreview();
        }
      },
      child: Listener(
        onPointerSignal: (final PointerSignalEvent event) {
          _registerInputModality(shellProvider, event.kind);
          if (event is PointerScrollEvent) {
            _handleUserPanningTheCanvas(
              shellProvider,
              appProvider,
              Offset(-event.scrollDelta.dx, -event.scrollDelta.dy),
            );
          } else {
            if (event is PointerScaleEvent) {
              _handleUserScalingTheCanvas(
                shellProvider,
                appProvider,
                event.localPosition,
                event.scale,
              );
            }
          }
        },
        onPointerHover: (final PointerHoverEvent event) {
          _registerInputModality(shellProvider, event.kind);
          if (_activePointerId != -1 || !_supportsHoverPreview(event.kind)) {
            return;
          }

          if (_shouldShowDrawingToolPreview(appProvider) && !appProvider.hasActiveTransformOverlay) {
            _updateDrawingToolPreview(appProvider, event.localPosition);
            return;
          }

          if (appProvider.brushSizePreviewPosition != null) {
            appProvider.hideDrawingToolPreview();
          }
        },
        onPointerPanZoomStart: (final PointerPanZoomStartEvent _) {
          shellProvider.interactionInputModality = InteractionInputModality.mouse;
        },
        onPointerPanZoomUpdate: (final PointerPanZoomUpdateEvent event) {
          _registerInputModality(shellProvider, event.kind);
          if (event.scale == 1) {
            // Panning
            _handleUserPanningTheCanvas(
              shellProvider,
              appProvider,
              event.panDelta,
            );
          } else {
            // Scaling
            _handleUserScalingTheCanvas(
              shellProvider,
              appProvider,
              event.localPosition,
              event.scale,
            );
          }
        },
        onPointerPanZoomEnd: (final PointerPanZoomEndEvent _) {
          // No-op
        },
        onPointerDown: (final PointerDownEvent event) {
          _registerInputModality(shellProvider, event.kind);
          if (event.kind == PointerDeviceKind.touch) {
            _pointerPositions[event.pointer] = event.localPosition;
            _getDistanceBetweenTouchPoints();

            _activePointers.add(event.pointer);

            if (_activePointers.length == AppMath.pair) {
              // Set the initial focal point between two fingers
              _baseDistance = _getDistanceBetweenTouchPoints();
            } else {
              if (event.buttons == 1 && !appPreferences.useApplePencil) {
                _handlePointerStart(appProvider, event);
              }
            }
          } else {
            _handlePointerStart(appProvider, event);
          }
        },
        onPointerMove: (final PointerMoveEvent event) {
          _registerInputModality(shellProvider, event.kind);
          if (event.kind == PointerDeviceKind.touch) {
            _pointerPositions[event.pointer] = event.localPosition;
            _getDistanceBetweenTouchPoints();

            if (_activePointers.length == AppMath.pair) {
              _handleMultiTouchUpdate(
                event,
                appProvider,
                shellProvider,
              );
            } else {
              if (event.buttons == 1 && !appPreferences.useApplePencil) {
                _handlePointerMove(appProvider, event);
              }
            }
          } else {
            _handlePointerMove(appProvider, event);
          }
        },
        onPointerUp: (final PointerUpEvent event) {
          if (event.kind == PointerDeviceKind.touch) {
            _pointerPositions.remove(event.pointer);
            _getDistanceBetweenTouchPoints(); // Recalculate distance
            _activePointers.remove(event.pointer);
            if (_activePointers.length < AppMath.pair) {
              _baseDistance = 0.0; // Reset base distance
            }
            _handlePointerEnd(appProvider, event);
          } else {
            _handlePointerEnd(appProvider, event);
          }
        },
        onPointerCancel: (final PointerCancelEvent event) {
          if (event.kind == PointerDeviceKind.touch) {
            _pointerPositions.remove(event.pointer);
            _getDistanceBetweenTouchPoints(); // Recalculate distance
            _activePointers.remove(event.pointer);
            if (_activePointers.length < AppMath.pair) {
              _baseDistance = 0.0; // Reset base distance
            }
          } else {
            _handlePointerEnd(appProvider, event);
          }
        },
        child: widget.child,
      ),
    );
  }
}

/// Encapsulates a cropped raster patch and its destination bounds for
/// committing a pixel-brush stroke to a layer.
class PixelBrushLayerPatch {
  const PixelBrushLayerPatch({
    required this.bounds,
    required this.image,
  });

  final ui.Rect bounds;
  final ui.Image image;
}

/// Maps a pixel-brush [mode] to its persisted layer action type.
ActionType pixelBrushActionType(final PixelBrushMode mode) {
  return mode == PixelBrushMode.smudge ? ActionType.smudge : ActionType.blurBrush;
}

/// Returns whether [actionType] is a persisted pixel-brush action.
bool isPixelBrushPersistedActionType(final ActionType actionType) {
  return actionType == ActionType.smudge || actionType == ActionType.blurBrush;
}

/// Restores the target layer baseline state and applies [patch] as the latest
/// pixel-brush action for [mode].
void applyPixelBrushPatchToLayer({
  required final ImagePlacementLayerRestoreState restoreState,
  required final LayerProvider targetLayer,
  required final PixelBrushLayerPatch patch,
  required final PixelBrushMode mode,
  final bool retainCache = false,
}) {
  targetLayer.actionStack
    ..clear()
    ..addAll(restoreState.originalActions);
  targetLayer.redoStack.clear();
  targetLayer.backgroundColor = restoreState.originalBackgroundColor;
  targetLayer.blendMode = restoreState.originalBlendMode;
  targetLayer.opacity = restoreState.originalOpacity;
  targetLayer.hasChanged = restoreState.originalHasChanged;
  // When the caller supplies an incrementally-composited cache, append without
  // clearing it (a full-stack replay + thumbnail rebuild per commit is the
  // smudge/blur perf bottleneck); otherwise fall back to the cache-clearing
  // append.
  final void Function(UserActionDrawing) append = retainCache
      ? targetLayer.appendDrawingActionRetainingCache
      : targetLayer.appendDrawingAction;
  // A single patch action, rendered with BlendMode.src, fully REPLACES its
  // region (see [_renderAction] for smudge/blurBrush). No separate `cut` clear:
  // a clear-then-srcOver pair leaves a sub-1 alpha ring at anti-aliased edges
  // when replayed under the display cache's fractional scale — the white
  // rectangle around the stroke. src replaces cleanly at any scale.
  append(
    UserActionDrawing(
      action: pixelBrushActionType(mode),
      positions: <Offset>[patch.bounds.topLeft, patch.bounds.bottomRight],
      brush: MyBrush(
        color: AppColors.transparent,
        size: AppMath.zero.toDouble(),
      ),
      fillColor: AppColors.transparent,
      image: patch.image,
    ),
  );
}

/// Compacts historical pixel-brush actions by flattening the layer when the
/// number of persisted smudge/blur gestures exceeds [maxGestureCount].
///
/// This keeps redraw cost bounded over long drawing sessions.
void compactPixelBrushLayerHistory({
  required final LayerProvider targetLayer,
  required final int maxGestureCount,
}) {
  int persistedPixelBrushCount = AppMath.zero;
  for (final UserActionDrawing action in targetLayer.actionStack) {
    if (isPixelBrushPersistedActionType(action.action)) {
      persistedPixelBrushCount++;
    }
  }

  if (persistedPixelBrushCount <= maxGestureCount) {
    return;
  }

  final ui.Image flattenedLayerImage = targetLayer.toImageForStorage(targetLayer.size);
  targetLayer.actionStack
    ..clear()
    ..add(
      UserActionDrawing(
        action: ActionType.image,
        positions: <Offset>[
          Offset.zero,
          Offset(targetLayer.size.width, targetLayer.size.height),
        ],
        image: flattenedLayerImage,
      ),
    );
  targetLayer.redoStack.clear();
  targetLayer.hasChanged = true;
  targetLayer.clearCache();
}

/// Copies an RGBA rectangle from [pixels] into a tightly packed patch buffer.
Uint8List copyPixelBrushRect({
  required final Uint8List pixels,
  required final int imageWidth,
  required final int left,
  required final int top,
  required final int width,
  required final int height,
}) {
  final Uint8List result = Uint8List(width * height * AppMath.bytesPerPixel);
  final int rowByteCount = width * AppMath.bytesPerPixel;
  for (int row = AppMath.zero; row < height; row++) {
    final int sourceOffset = (((top + row) * imageWidth) + left) * AppMath.bytesPerPixel;
    final int destinationOffset = row * rowByteCount;
    result.setRange(
      destinationOffset,
      destinationOffset + rowByteCount,
      pixels,
      sourceOffset,
    );
  }
  return result;
}
