import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/draft_flusher.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/prepared_smudge_stroke_source.dart';
import 'package:fpaint/helpers/smudge_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/image_placement_layer_restore_state.dart';
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

  /// Index into [_pixelBrushStrokePoints] of the *last point that has already
  /// been processed* by a previous segment call.  The next kick will send only
  /// [_pixelBrushStrokePoints.sublist(_lastKickedPointIndex)] to the isolate.
  int _lastKickedPointIndex = 0;
  Offset? _lastSelectionTapCanvasPosition;
  Duration? _lastSelectionTapTimestamp;

  /// Current live pixel buffer: starts as a copy of [_preparedPixelBrushSource]
  /// pixels and is updated in-place after each successful segment rasterization.
  /// This makes the effect accumulate correctly along the stroke.
  Uint8List? _livePixelBuffer;

  /// Canvas clip path active when the stroke began (may be null).
  ui.Path? _pixelBrushClipPath;

  /// Intensity captured when the current pixel-brush stroke started.
  double _pixelBrushIntensity = AppInteraction.pixelBrushDefaultIntensity;

  /// Layer state captured before the stroke so it can be restored on undo.
  ImagePlacementLayerRestoreState? _pixelBrushLayerRestoreState;

  /// Which pixel-manipulation mode is active for the current stroke.
  PixelBrushMode _pixelBrushMode = PixelBrushMode.smudge;

  /// In-flight preparation future (resolves to [_preparedPixelBrushSource]).
  Future<PreparedSmudgeStrokeSource?>? _pixelBrushPreparation;

  /// True while the isolate for a preview segment is running.
  bool _pixelBrushRasterBusy = false;

  /// The original layer image captured at stroke start.
  ui.Image? _pixelBrushSourceImage;

  /// Monotonic token that invalidates stale async preview completions.
  int _pixelBrushStrokeGeneration = 0;

  /// Incrementally maintained stroke patch bounds for fast live preview updates.
  ui.Rect? _pixelBrushStrokePatchBounds;

  /// All accumulated stroke points since the stroke began.
  final List<Offset> _pixelBrushStrokePoints = <Offset>[];

  /// The layer being modified by the active pixel-brush stroke.
  ///
  /// Kept in state so [_clearPixelBrushStroke] can clear the live-preview
  /// overlay without needing an [AppProvider] reference.
  LayerProvider? _pixelBrushTargetLayer;

  /// True when a new preview kick was requested while the isolate was busy.
  bool _pixelBrushUpdateNeeded = false;
  final Map<int, Offset> _pointerPositions = <int, ui.Offset>{};

  /// Prepared source data for the active pixel-brush stroke (clip mask + dims).
  PreparedSmudgeStrokeSource? _preparedPixelBrushSource;

  /// The selector math mode active before a modifier-key override was applied.
  /// Non-null only during a modifier-driven selection gesture.
  SelectorMath? _previousSelectorMath;
  double _scaleFactor = 1.0;
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

/// Returns whether [mode] needs a composited backdrop instead of only the
/// selected layer as input.
bool pixelBrushUsesCompositeBackdrop(final PixelBrushMode mode) {
  return mode == PixelBrushMode.smudge || mode == PixelBrushMode.blur;
}

/// Clamps the resume index used for pending stroke points to valid bounds.
int normalizePixelBrushRemainingStart({
  required final int lastKickedPointIndex,
  required final int strokePointCount,
}) {
  return lastKickedPointIndex.clamp(AppMath.zero, strokePointCount);
}

/// Restores the target layer baseline state and applies [patch] as the latest
/// pixel-brush action for [mode].
void applyPixelBrushPatchToLayer({
  required final ImagePlacementLayerRestoreState restoreState,
  required final LayerProvider targetLayer,
  required final PixelBrushLayerPatch patch,
  required final PixelBrushMode mode,
}) {
  targetLayer.actionStack
    ..clear()
    ..addAll(restoreState.originalActions);
  targetLayer.redoStack.clear();
  targetLayer.backgroundColor = restoreState.originalBackgroundColor;
  targetLayer.blendMode = restoreState.originalBlendMode;
  targetLayer.opacity = restoreState.originalOpacity;
  targetLayer.hasChanged = restoreState.originalHasChanged;
  targetLayer.appendDrawingAction(
    UserActionDrawing(
      action: ActionType.cut,
      positions: <Offset>[patch.bounds.topLeft, patch.bounds.bottomRight],
      fillColor: AppColors.transparent,
      path: ui.Path()..addRect(patch.bounds),
    ),
  );
  targetLayer.appendDrawingAction(
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

/// Builds a minimal layer patch image covering the modified stroke area.
Future<PixelBrushLayerPatch?> buildPixelBrushLayerPatch({
  required final Uint8List pixels,
  required final int imageWidth,
  required final int imageHeight,
  required final List<Offset> strokePoints,
  required final double brushSize,
  final ui.Rect? preferredBounds,
}) async {
  final ui.Rect? rawBounds =
      preferredBounds ??
      resolvePixelBrushPatchBounds(
        strokePoints: strokePoints,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        brushSize: brushSize,
      );
  if (rawBounds == null) {
    return null;
  }

  final int left = max(AppMath.zero, rawBounds.left.floor());
  final int top = max(AppMath.zero, rawBounds.top.floor());
  final int right = min(imageWidth, rawBounds.right.ceil());
  final int bottom = min(imageHeight, rawBounds.bottom.ceil());
  final int patchWidth = right - left;
  final int patchHeight = bottom - top;
  if (patchWidth <= AppMath.zero || patchHeight <= AppMath.zero) {
    return null;
  }

  final Uint8List patchPixels = copyPixelBrushRect(
    pixels: pixels,
    imageWidth: imageWidth,
    left: left,
    top: top,
    width: patchWidth,
    height: patchHeight,
  );
  final ui.Image patchImage = await imageFromPixels(
    patchPixels,
    patchWidth,
    patchHeight,
  );
  return PixelBrushLayerPatch(
    bounds: ui.Rect.fromLTRB(
      left.toDouble(),
      top.toDouble(),
      right.toDouble(),
      bottom.toDouble(),
    ),
    image: patchImage,
  );
}

/// Builds a live-preview layer patch covering [patchBounds] from [pixels].
///
/// Uses [imageFromPixelsFast] for a faster image-upload path compared to the
/// full [buildPixelBrushLayerPatch] API, while remaining safe on both Skia
/// and Impeller renderers.
Future<PixelBrushLayerPatch?> buildPixelBrushLayerPatchFast({
  required final Uint8List pixels,
  required final int imageWidth,
  required final int imageHeight,
  required final ui.Rect patchBounds,
}) async {
  final int left = max(AppMath.zero, patchBounds.left.floor());
  final int top = max(AppMath.zero, patchBounds.top.floor());
  final int right = min(imageWidth, patchBounds.right.ceil());
  final int bottom = min(imageHeight, patchBounds.bottom.ceil());
  final int patchWidth = right - left;
  final int patchHeight = bottom - top;
  if (patchWidth <= AppMath.zero || patchHeight <= AppMath.zero) {
    return null;
  }

  final Uint8List patchPixels = copyPixelBrushRect(
    pixels: pixels,
    imageWidth: imageWidth,
    left: left,
    top: top,
    width: patchWidth,
    height: patchHeight,
  );
  final ui.Image patchImage = await imageFromPixelsFast(patchPixels, patchWidth, patchHeight);
  return PixelBrushLayerPatch(
    bounds: ui.Rect.fromLTRB(
      left.toDouble(),
      top.toDouble(),
      right.toDouble(),
      bottom.toDouble(),
    ),
    image: patchImage,
  );
}

/// Resolves the axis-aligned patch bounds that fully contain the stroke with
/// brush radius padding, clamped to the source image.
ui.Rect? resolvePixelBrushPatchBounds({
  required final List<Offset> strokePoints,
  required final int imageWidth,
  required final int imageHeight,
  required final double brushSize,
}) {
  if (strokePoints.isEmpty) {
    return null;
  }

  final double radius = max(
    AppInteraction.smudgeMinimumRadius,
    brushSize * AppInteraction.smudgeBrushRadiusFactor,
  );
  final int padding = radius.ceil() + AppInteraction.smudgeBoundsPadding;
  double minX = strokePoints.first.dx;
  double minY = strokePoints.first.dy;
  double maxX = strokePoints.first.dx;
  double maxY = strokePoints.first.dy;

  for (final Offset point in strokePoints.skip(AppMath.one)) {
    if (point.dx < minX) {
      minX = point.dx;
    }
    if (point.dy < minY) {
      minY = point.dy;
    }
    if (point.dx > maxX) {
      maxX = point.dx;
    }
    if (point.dy > maxY) {
      maxY = point.dy;
    }
  }

  final int left = max(AppMath.zero, minX.floor() - padding);
  final int top = max(AppMath.zero, minY.floor() - padding);
  final int right = min(imageWidth - AppMath.one, maxX.ceil() + padding);
  final int bottom = min(imageHeight - AppMath.one, maxY.ceil() + padding);
  if (right < left || bottom < top) {
    return null;
  }
  return ui.Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    (right + AppMath.one).toDouble(),
    (bottom + AppMath.one).toDouble(),
  );
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
