import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/draft_flusher.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/prepared_smudge_stroke_source.dart';
import 'package:fpaint/helpers/smudge_helper.dart';
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
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/text_editor_dialog.dart';

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
  Duration? _lastSelectionTapTimestamp;
  Offset? _lastSelectionTapCanvasPosition;

  /// Index into [_pixelBrushStrokePoints] of the *last point that has already
  /// been processed* by a previous segment call.  The next kick will send only
  /// [_pixelBrushStrokePoints.sublist(_lastKickedPointIndex)] to the isolate.
  int _lastKickedPointIndex = 0;

  /// Monotonic token that invalidates stale async preview completions.
  int _pixelBrushStrokeGeneration = 0;

  /// Current live pixel buffer: starts as a copy of [_preparedPixelBrushSource]
  /// pixels and is updated in-place after each successful segment rasterization.
  /// This makes the effect accumulate correctly along the stroke.
  Uint8List? _livePixelBuffer;

  /// Canvas clip path active when the stroke began (may be null).
  ui.Path? _pixelBrushClipPath;

  /// Layer state captured before the stroke so it can be restored on undo.
  ImagePlacementLayerRestoreState? _pixelBrushLayerRestoreState;

  /// Which pixel-manipulation mode is active for the current stroke.
  PixelBrushMode _pixelBrushMode = PixelBrushMode.smudge;

  /// Intensity captured when the current pixel-brush stroke started.
  double _pixelBrushIntensity = AppInteraction.pixelBrushDefaultIntensity;

  /// In-flight preparation future (resolves to [_preparedPixelBrushSource]).
  Future<PreparedSmudgeStrokeSource?>? _pixelBrushPreparation;

  /// True while the isolate for a preview segment is running.
  bool _pixelBrushRasterBusy = false;

  /// The original layer image captured at stroke start.
  ui.Image? _pixelBrushSourceImage;

  /// All accumulated stroke points since the stroke began.
  final List<Offset> _pixelBrushStrokePoints = <Offset>[];

  /// True when a new preview kick was requested while the isolate was busy.
  bool _pixelBrushUpdateNeeded = false;
  final Map<int, Offset> _pointerPositions = <int, ui.Offset>{};

  /// Prepared source data for the active pixel-brush stroke (clip mask + dims).
  PreparedSmudgeStrokeSource? _preparedPixelBrushSource;
  double _scaleFactor = 1.0;

  /// The selector math mode active before a modifier-key override was applied.
  /// Non-null only during a modifier-driven selection gesture.
  SelectorMath? _previousSelectorMath;

  @override
  Widget build(final BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context, listen: false);
    final AppPreferences appPreferences = AppPreferences.of(context);
    final ShellProvider shellProvider = ShellProvider.of(context);

    return Listener(
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
    );
  }

  /// Appends a sampled pointer position to the active pixel-brush stroke.
  void _appendPixelBrushPoint(
    final Offset position,
    final double brushSize,
  ) {
    final double spacing = resolvePixelBrushStepSpacing(brushSize);
    if (_pixelBrushStrokePoints.isNotEmpty && (_pixelBrushStrokePoints.last - position).distance < spacing) {
      return;
    }
    _pixelBrushStrokePoints.add(position);
  }

  /// Clears the in-progress pixel-brush stroke state.
  void _clearPixelBrushStroke() {
    _pixelBrushStrokePoints.clear();
    _pixelBrushLayerRestoreState = null;
    _preparedPixelBrushSource = null;
    _pixelBrushPreparation = null;
    _pixelBrushSourceImage = null;
    _pixelBrushClipPath = null;
    _livePixelBuffer = null;
    _lastKickedPointIndex = 0;
    _pixelBrushStrokeGeneration++;
    _pixelBrushRasterBusy = false;
    _pixelBrushUpdateNeeded = false;
  }

  /// Commits the pixel-brush stroke as an undoable image action.
  ///
  /// If a live preview has been running we already have an up-to-date
  /// [_livePixelBuffer]; we only run a final segment for any points appended
  /// after the last kick, then convert the buffer to a [ui.Image].
  Future<void> _commitPixelBrushStroke(final AppProvider appProvider) async {
    final ui.Image? sourceImage = _pixelBrushSourceImage;
    final ImagePlacementLayerRestoreState? layerRestoreState = _pixelBrushLayerRestoreState;
    if (sourceImage == null || layerRestoreState == null || _pixelBrushStrokePoints.length < AppMath.pair) {
      if (layerRestoreState != null) {
        _restorePixelBrushLayerState(appProvider: appProvider, restoreState: layerRestoreState);
      }
      return;
    }

    final PreparedSmudgeStrokeSource? prepared =
        _preparedPixelBrushSource ??
        await _pixelBrushPreparation ??
        await preparePixelBrushSource(
          sourceImage: sourceImage,
          clipPath: _pixelBrushClipPath,
        );
    if (prepared == null) {
      _restorePixelBrushLayerState(appProvider: appProvider, restoreState: layerRestoreState);
      return;
    }

    // Apply any remaining un-kicked segment.
    Uint8List currentPixels = _livePixelBuffer ?? Uint8List.fromList(prepared.pixels);

    final int remainingStart = normalizePixelBrushRemainingStart(
      lastKickedPointIndex: _lastKickedPointIndex,
      strokePointCount: _pixelBrushStrokePoints.length,
    );
    final List<Offset> remaining = _pixelBrushStrokePoints.sublist(remainingStart);
    if (remaining.length >= AppMath.pair) {
      final PixelBrushSegmentResult? segResult = await rasterizePixelBrushSegment(
        livePixels: currentPixels,
        imageWidth: sourceImage.width,
        imageHeight: sourceImage.height,
        segmentPoints: remaining,
        brushSize: appProvider.brushSize,
        intensity: _pixelBrushIntensity,
        mode: _pixelBrushMode,
        clipMask: prepared.clipMask,
      );
      if (segResult != null) {
        currentPixels = segResult.pixels;
      }
    }

    final PixelBrushLayerPatch? committedPatch = await buildPixelBrushLayerPatch(
      pixels: currentPixels,
      imageWidth: sourceImage.width,
      imageHeight: sourceImage.height,
      strokePoints: _pixelBrushStrokePoints,
      brushSize: appProvider.brushSize,
    );
    if (committedPatch == null) {
      _restorePixelBrushLayerState(appProvider: appProvider, restoreState: layerRestoreState);
      return;
    }

    appProvider.undoProvider.executeAction(
      name: _pixelBrushMode.name,
      forward: () {
        final LayerProvider targetLayer = appProvider.layers.get(layerRestoreState.layerIndex);
        appProvider.layers.selectedLayerIndex = layerRestoreState.layerIndex;
        applyPixelBrushPatchToLayer(
          restoreState: layerRestoreState,
          targetLayer: targetLayer,
          patch: committedPatch,
          mode: _pixelBrushMode,
        );
        appProvider.update();
      },
      backward: () {
        _restorePixelBrushLayerState(
          appProvider: appProvider,
          restoreState: layerRestoreState,
        );
        appProvider.update();
      },
    );
  }

  /// Returns the distance between the first two active touch points.
  ///
  /// Returns 0.0 when fewer than two touch pointers are active.
  double _getDistanceBetweenTouchPoints() {
    if (_pointerPositions.length >= AppMath.pair) {
      final List<Offset> positions = _pointerPositions.values.toList();
      final Offset pos1 = positions[0];
      final Offset pos2 = positions[1];
      return (pos2 - pos1).distance;
    } else {
      return 0.0;
    }
  }

  /// Handles two-finger pan and pinch updates for manual canvas navigation.
  void _handleMultiTouchUpdate(
    final PointerMoveEvent event,
    final AppProvider appProvider,
    final ShellProvider shellProvider,
  ) {
    appProvider.canvasOffset += event.delta;
    final double newDistance = _getDistanceBetweenTouchPoints();
    final double distanceDelta = _baseDistance - newDistance;

    if (distanceDelta.abs() > AppInteraction.multiTouchScaleThreshold) {
      _scaleFactor = _getDistanceBetweenTouchPoints() / _baseDistance;
      _scaleFactor = max(AppInteraction.minCanvasScale, min(_scaleFactor, AppInteraction.maxCanvasScale));

      final Offset before = appProvider.toCanvas(event.localPosition);
      appProvider.layers.scale = _scaleFactor;
      final Offset after = appProvider.toCanvas(event.localPosition);
      final Offset adjustment = after - before;
      appProvider.canvasOffset += adjustment * appProvider.layers.scale;
    }

    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
    appProvider.repaintViewport();
  }

  /// Finalizes an active pointer interaction and clears temporary drawing state.
  void _handlePointerEnd(
    final AppProvider appProvider,
    final PointerEvent event,
  ) async {
    appProvider.layers.selectedLayer.isUserDrawing = false;
    final bool isSelectionActive =
        appProvider.selectedAction == ActionType.selector && !appProvider.transformModel.isVisible;

    if (_activePointerId == event.pointer) {
      if (isSelectionActive) {
        appProvider.selectorCreationEnd();
        _restoreSelectionMath(appProvider);
        if (appProvider.selectorModel.mode != SelectorMode.line || !appProvider.selectorModel.isDrawing) {
          _clearSelectionTapTracking();
        }
      } else if (_pixelBrushSourceImage != null) {
        _appendPixelBrushPoint(appProvider.toCanvas(event.localPosition), appProvider.brushSize);
        await _commitPixelBrushStroke(appProvider);
        _clearSelectionTapTracking();
      } else {
        _clearSelectionTapTracking();
      }
      _activePointerId = -1;
      _clearPixelBrushStroke();
      appProvider.layers.selectedLayer.clearCache();
      if (!mounted) {
        return;
      }
      final DraftFlusher controller = Provider.of<DraftFlusher>(context, listen: false);
      unawaited(controller.flushNow());
      appProvider.update();
    }
  }

  /// Handles pointer move events for drawing, selection, and eyedropper interactions.
  void _handlePointerMove(
    final AppProvider appProvider,
    final PointerEvent event,
  ) {
    if (appProvider.hasActiveTransformOverlay) {
      return;
    }

    final Offset adjustedPosition = appProvider.toCanvas(event.localPosition);
    final bool isSelectionActive =
        appProvider.selectedAction == ActionType.selector && !appProvider.transformModel.isVisible;

    if (appProvider.eyeDropPositionForBrush != null) {
      appProvider.eyeDropPositionForBrush = event.localPosition;
      appProvider.repaintMainView();
      return;
    }
    if (appProvider.eyeDropPositionForFill != null) {
      appProvider.eyeDropPositionForFill = event.localPosition;
      appProvider.repaintMainView();
      return;
    }

    if (isSelectionActive &&
        appProvider.selectorModel.mode == SelectorMode.line &&
        appProvider.selectorModel.isDrawing) {
      appProvider.selectorCreationPreview(adjustedPosition);
      return;
    }

    if (event.buttons == 1 && _activePointerId == event.pointer) {
      if (isSelectionActive) {
        appProvider.selectorCreationAdditionalPoint(adjustedPosition);
        return;
      }

      if (appProvider.selectedAction == ActionType.fill) {
        return;
      }

      if (_pixelBrushSourceImage != null) {
        _appendPixelBrushPoint(adjustedPosition, appProvider.brushSize);
        _kickLivePixelBrushPreview(appProvider);
        return;
      }

      if (appProvider.selectedAction == ActionType.pencil) {
        appProvider.appendLineFromLastUserAction(adjustedPosition);
      } else if (appProvider.selectedAction == ActionType.eraser) {
        appProvider.appendLineFromLastUserAction(adjustedPosition);
      } else if (appProvider.selectedAction == ActionType.brush) {
        appProvider.layers.selectedLayer.lastActionAppendPosition(position: adjustedPosition);
        appProvider.layers.repaintCanvas();
      } else {
        appProvider.updateAction(end: adjustedPosition);
        appProvider.layers.repaintCanvas();
      }
    }
  }

  /// Reads the current keyboard modifier state and temporarily overrides
  /// [selectorModel.math] for the upcoming selection gesture:
  ///   Shift + Option/Alt → intersect
  ///   Shift             → add
  ///   Option/Alt        → remove
  ///   (none)            → no override; existing math is preserved
  ///
  /// The original value is saved in [_previousSelectorMath] and restored by
  /// [_restoreSelectionMath] once the gesture completes.
  void _applySelectionModifierMath(final AppProvider appProvider) {
    final bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final bool isAltPressed = HardwareKeyboard.instance.isAltPressed;

    if (!isShiftPressed && !isAltPressed) {
      return;
    }

    final SelectorMath overrideMath;
    if (isShiftPressed && isAltPressed) {
      overrideMath = SelectorMath.intersect;
    } else if (isShiftPressed) {
      overrideMath = SelectorMath.add;
    } else {
      overrideMath = SelectorMath.remove;
    }

    _previousSelectorMath = appProvider.selectorModel.math;
    appProvider.selectorModel.math = overrideMath;
    appProvider.repaintToolOptions();
  }

  /// Restores [selectorModel.math] to the value captured before a
  /// modifier-key override, then clears the saved value.
  void _restoreSelectionMath(final AppProvider appProvider) {
    if (_previousSelectorMath != null) {
      appProvider.selectorModel.math = _previousSelectorMath!;
      _previousSelectorMath = null;
      appProvider.repaintToolOptions();
    }
  }

  void _clearSelectionTapTracking() {
    _lastSelectionTapTimestamp = null;
    _lastSelectionTapCanvasPosition = null;
  }

  /// Returns whether the current keyboard state requests sampling from all visible layers.
  bool _isSampleAllLayersModifierPressed() {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    return keyboard.isControlPressed || keyboard.isMetaPressed;
  }

  bool _tryCloseStraightLineSelectionOnDoubleTap(
    final AppProvider appProvider,
    final PointerDownEvent event,
    final Offset canvasPosition,
  ) {
    if (appProvider.selectorModel.mode != SelectorMode.line || !appProvider.selectorModel.isDrawing) {
      return false;
    }

    final Duration eventTimestamp = event.timeStamp;
    final Duration? previousTimestamp = _lastSelectionTapTimestamp;
    final Offset? previousPosition = _lastSelectionTapCanvasPosition;
    final bool isDoubleTap =
        previousTimestamp != null &&
        previousPosition != null &&
        eventTimestamp - previousTimestamp <= AppInteraction.selectionDoubleTapTimeout &&
        (canvasPosition - previousPosition).distance <=
            AppInteraction.selectionDoubleTapSlop / appProvider.layers.scale;

    _lastSelectionTapTimestamp = eventTimestamp;
    _lastSelectionTapCanvasPosition = canvasPosition;

    if (!isDoubleTap) {
      return false;
    }

    final bool didClose = appProvider.selectorCreationClosePolygon();
    if (didClose) {
      _activePointerId = -1;
      _restoreSelectionMath(appProvider);
      _clearSelectionTapTracking();
    }
    return didClose;
  }

  /// Starts pointer interactions including drawing, selection, fill, and text placement.
  void _handlePointerStart(
    final AppProvider appProvider,
    final PointerDownEvent event,
  ) async {
    if (appProvider.hasActiveTransformOverlay) {
      return;
    }

    final ui.Offset adjustedPosition = appProvider.toCanvas(event.localPosition);
    final bool isSelectionActive =
        appProvider.selectedAction == ActionType.selector && !appProvider.transformModel.isVisible;

    if (event.buttons == 1 && _activePointerId == -1) {
      if (appProvider.eyeDropPositionForBrush != null) {
        appProvider.layers.capturePainterToImage();
        appProvider.eyeDropPositionForBrush = adjustedPosition;
        return;
      }

      if (appProvider.eyeDropPositionForFill != null) {
        appProvider.layers.capturePainterToImage();
        appProvider.eyeDropPositionForFill = adjustedPosition;
        return;
      }

      _activePointerId = event.pointer;

      if (isSelectionActive) {
        _applySelectionModifierMath(appProvider);
        if (_tryCloseStraightLineSelectionOnDoubleTap(appProvider, event, adjustedPosition)) {
          return;
        }
        appProvider.selectorCreationStart(
          adjustedPosition,
          sampleAllLayers: appProvider.selectorModel.mode == SelectorMode.wand && _isSampleAllLayersModifierPressed(),
        );
        return;
      }

      if (appProvider.layers.selectedLayer.isVisible == false) {
        final AppLocalizations l10n = context.l10n;
        context.showSnackBarMessage(
          l10n.selectionIsHidden,
        );
        return;
      }

      if (appProvider.isSelectedLayerLocked) {
        _activePointerId = -1;
        _showLockedLayerMessage(appProvider);
        return;
      }

      if (appProvider.selectedAction == ActionType.text) {
        TextObject? selectedText;

        for (final UserActionDrawing action in appProvider.layers.selectedLayer.actionStack.reversed) {
          if (action.textObject != null && action.textObject!.containsPoint(adjustedPosition)) {
            selectedText = action.textObject;
            break;
          }
        }

        if (selectedText != null) {
          // Text selection is handled fully on pointer down; release active pointer
          // in case the subsequent pointer up is consumed by the modal dialog.
          _activePointerId = -1;
          appProvider.adoptTextToolStateFromObject(selectedText);
          appProvider.selectedTextObject = selectedText;
          return;
        }

        // Text creation opens a dialog on pointer down, so pointer up may not
        // reach this listener. Clear active pointer to avoid locking tools.
        _activePointerId = -1;
        _showTextDialog(appProvider, adjustedPosition);
        return;
      }

      if (appProvider.selectedAction == ActionType.fill) {
        final bool sampleAllLayers = _isSampleAllLayersModifierPressed();

        if (await appProvider.prepareFloodFillSelection(
          adjustedPosition,
          sampleAllLayers: sampleAllLayers,
        )) {
          return;
        }

        if (appProvider.fillModel.mode == FillMode.solid) {
          appProvider.fillModel.gradientPoints.clear();
          appProvider.fillModel.sampleAllLayers = sampleAllLayers;
          appProvider.floodFillSolidAction(
            adjustedPosition,
            sampleAllLayers: sampleAllLayers,
          );
        } else {
          if (appProvider.fillModel.gradientPoints.isEmpty) {
            appProvider.fillModel.sampleAllLayers = sampleAllLayers;
            if (appProvider.fillModel.mode == FillMode.linear) {
              appProvider.fillModel.addPoint(
                GradientPoint(
                  offset: appProvider.fromCanvas(
                    adjustedPosition + const Offset(-AppInteraction.linearFillHandleOffset, 0),
                  ),
                  color: appProvider.fillModel.gradientStopColors.first,
                ),
              );
              appProvider.fillModel.addPoint(
                GradientPoint(
                  offset: appProvider.fromCanvas(
                    adjustedPosition + const Offset(AppInteraction.linearFillHandleOffset, 0),
                  ),
                  color: appProvider.fillModel.gradientStopColors.last,
                ),
              );
            } else if (appProvider.fillModel.mode == FillMode.radial) {
              appProvider.fillModel.addPoint(
                GradientPoint(
                  offset: appProvider.fromCanvas(adjustedPosition),
                  color: appProvider.fillModel.gradientStopColors.first,
                ),
              );
              appProvider.fillModel.addPoint(
                GradientPoint(
                  offset: appProvider.fromCanvas(
                    adjustedPosition +
                        const Offset(AppInteraction.radialFillHandleOffset, AppInteraction.radialFillHandleOffset),
                  ),
                  color: appProvider.fillModel.gradientStopColors.last,
                ),
              );
            }
            appProvider.fillModel.isVisible = true;
            appProvider.floodFillGradientAction(appProvider.fillModel);
            appProvider.update();
          }
        }
        return;
      }

      appProvider.layers.selectedLayer.isUserDrawing = true;

      if (appProvider.selectedAction == ActionType.smudge) {
        _startPixelBrushStroke(appProvider, adjustedPosition, PixelBrushMode.smudge);
        return;
      }

      if (appProvider.selectedAction == ActionType.blurBrush) {
        _startPixelBrushStroke(appProvider, adjustedPosition, PixelBrushMode.blur);
        return;
      }

      appProvider.recordExecuteDrawingActionToSelectedLayer(
        action: UserActionDrawing(
          action: appProvider.selectedAction,
          positions: <ui.Offset>[adjustedPosition, adjustedPosition],
          brush: MyBrush(
            color: appProvider.brushColor,
            size: appProvider.brushSize,
            style: appProvider.brushStyle,
          ),
          fillColor: appProvider.fillColor,
        ),
      );
    }
  }

  void _handleUserPanningTheCanvas(
    final ShellProvider shellProvider,
    final AppProvider appProvider,
    final Offset offsetDelta,
  ) {
    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
    appProvider.canvasPan(
      offsetDelta: offsetDelta,
      notifyListener: false,
      notifyViewport: true,
    );
  }

  /// Applies user-driven canvas scaling around [anchorPoint].
  void _handleUserScalingTheCanvas(
    final ShellProvider shellProvider,
    final AppProvider appProvider,
    final Offset anchorPoint,
    final double scaleDelta,
  ) {
    if (scaleDelta == 1) {
      return;
    }

    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;

    appProvider.applyScaleToCanvas(
      scaleDelta: scaleDelta,
      anchorPoint: anchorPoint,
      notifyListener: false,
      notifyViewport: true,
    );
  }

  /// Fires an incremental pixel-brush rasterization for live drag preview.
  ///
  /// Sends only the *new* segment of points since the last successful kick so
  /// each isolate call is O(segment) rather than O(full stroke). The resulting
  /// pixel buffer is stored in [_livePixelBuffer] and fed back as the starting
  /// state for the next segment, making the effect accumulate correctly.
  ///
  /// Skips if a rasterization is already running; marks that a re-run is
  /// needed so the next completion triggers another pass.
  void _kickLivePixelBrushPreview(final AppProvider appProvider) {
    if (_pixelBrushRasterBusy) {
      _pixelBrushUpdateNeeded = true;
      return;
    }
    // Need at least one overlap point (the last processed point) plus one new
    // point so the isolate has a valid segment.
    final int currentLength = _pixelBrushStrokePoints.length;
    final int segmentStart = _lastKickedPointIndex > AppMath.zero ? _lastKickedPointIndex : AppMath.zero;
    if (currentLength - segmentStart < AppMath.pair) {
      return;
    }
    final ui.Image? sourceImage = _pixelBrushSourceImage;
    final ImagePlacementLayerRestoreState? restoreState = _pixelBrushLayerRestoreState;
    if (sourceImage == null || restoreState == null) {
      return;
    }
    _pixelBrushRasterBusy = true;
    _pixelBrushUpdateNeeded = false;

    // Snapshot the segment we are about to process.
    final List<Offset> segmentPoints = List<Offset>.of(_pixelBrushStrokePoints.sublist(segmentStart));
    // After this kick succeeds the new "last processed" index will be:
    final int nextLastIndex = currentLength - AppMath.one;
    final double brushSize = appProvider.brushSize;
    final PixelBrushMode mode = _pixelBrushMode;
    final Uint8List? startPixels = _livePixelBuffer;
    final int strokeGeneration = _pixelBrushStrokeGeneration;

    unawaited(
      (() async {
        final PreparedSmudgeStrokeSource? prepared = _preparedPixelBrushSource ?? await _pixelBrushPreparation;
        if (strokeGeneration != _pixelBrushStrokeGeneration) {
          return;
        }
        if (!mounted || _pixelBrushSourceImage == null || prepared == null) {
          _pixelBrushRasterBusy = false;
          if (mounted && _pixelBrushUpdateNeeded && _pixelBrushSourceImage != null) {
            _kickLivePixelBrushPreview(appProvider);
          }
          return;
        }

        // Use the current live buffer (or the original source for the first kick).
        final Uint8List basePixels = startPixels ?? Uint8List.fromList(prepared.pixels);

        final PixelBrushSegmentResult? result = await rasterizePixelBrushSegment(
          livePixels: basePixels,
          imageWidth: sourceImage.width,
          imageHeight: sourceImage.height,
          segmentPoints: segmentPoints,
          brushSize: brushSize,
          intensity: _pixelBrushIntensity,
          mode: mode,
          clipMask: prepared.clipMask,
        );
        if (strokeGeneration != _pixelBrushStrokeGeneration) {
          return;
        }
        _pixelBrushRasterBusy = false;
        if (!mounted || _pixelBrushSourceImage == null) {
          return;
        }

        if (result != null) {
          // Persist the updated pixel state so the next segment continues from here.
          _livePixelBuffer = result.pixels;
          _lastKickedPointIndex = nextLastIndex;

          final PixelBrushLayerPatch? livePatch = await buildPixelBrushLayerPatch(
            pixels: result.pixels,
            imageWidth: result.width,
            imageHeight: result.height,
            strokePoints: _pixelBrushStrokePoints,
            brushSize: brushSize,
          );
          if (!mounted || _pixelBrushSourceImage == null) {
            return;
          }
          if (livePatch != null) {
            final LayerProvider liveLayer = appProvider.layers.get(restoreState.layerIndex);
            applyPixelBrushPatchToLayer(
              restoreState: restoreState,
              targetLayer: liveLayer,
              patch: livePatch,
              mode: _pixelBrushMode,
            );
            appProvider.layers.repaintCanvas();
          }
        }

        if (_pixelBrushUpdateNeeded) {
          _kickLivePixelBrushPreview(appProvider);
        }
      })(),
    );
  }

  /// Updates the shell interaction modality based on the current pointer kind.
  void _registerInputModality(
    final ShellProvider shellProvider,
    final PointerDeviceKind kind,
  ) {
    switch (kind) {
      case PointerDeviceKind.touch:
        shellProvider.interactionInputModality = InteractionInputModality.touch;
        return;
      case PointerDeviceKind.stylus:
      case PointerDeviceKind.invertedStylus:
        shellProvider.interactionInputModality = InteractionInputModality.pen;
        return;
      case PointerDeviceKind.mouse:
      case PointerDeviceKind.trackpad:
      case PointerDeviceKind.unknown:
        shellProvider.interactionInputModality = InteractionInputModality.mouse;
        return;
    }
  }

  /// Restores the selected layer state captured before the current pixel-brush stroke.
  void _restorePixelBrushLayerState({
    required final AppProvider appProvider,
    required final ImagePlacementLayerRestoreState restoreState,
  }) {
    final LayerProvider targetLayer = appProvider.layers.get(restoreState.layerIndex);
    appProvider.layers.selectedLayerIndex = restoreState.layerIndex;
    targetLayer.actionStack
      ..clear()
      ..addAll(restoreState.originalActions);
    targetLayer.redoStack
      ..clear()
      ..addAll(restoreState.originalRedoActions);
    targetLayer.backgroundColor = restoreState.originalBackgroundColor;
    targetLayer.blendMode = restoreState.originalBlendMode;
    targetLayer.opacity = restoreState.originalOpacity;
    targetLayer.hasChanged = restoreState.originalHasChanged;
    targetLayer.clearCache();
  }

  void _showLockedLayerMessage(final AppProvider appProvider) {
    context.showSnackBarMessage(
      context.l10n.layerLockedForEditing(appProvider.layers.selectedLayer.name),
    );
  }

  /// Shows a text editor dialog at the given canvas [position].
  ///
  /// When the user finishes editing, the resulting [TextObject] is recorded
  /// as a drawing action on the currently selected layer.
  void _showTextDialog(final AppProvider appProvider, final Offset position) {
    final AppLocalizations l10n = context.l10n;
    showAppBottomSheet<void>(
      context: context,
      barrierColor: AppColors.transparent,
      builder: (final BuildContext _) {
        return TextEditorDialog(
          title: l10n.addText,
          submitLabel: l10n.addText,
          position: position,
          initialText: '',
          initialStyle: appProvider.textToolState.copy(),
          onSubmitted: (final TextObject textObject) {
            appProvider.adoptTextToolStateFromObject(textObject);
            appProvider.recordExecuteDrawingActionToSelectedLayer(
              action: UserActionDrawing(
                action: ActionType.text,
                positions: <ui.Offset>[position],
                textObject: textObject,
              ),
            );
          },
        );
      },
    );
  }

  /// Starts tracking a pixel-brush stroke from [position] with the given [mode].
  void _startPixelBrushStroke(
    final AppProvider appProvider,
    final Offset position,
    final PixelBrushMode mode,
  ) {
    _pixelBrushStrokeGeneration++;
    _pixelBrushMode = mode;
    _pixelBrushIntensity = appProvider.brushIntensity;
    _pixelBrushLayerRestoreState = appProvider.captureSelectedLayerRestoreState();
    _pixelBrushSourceImage = pixelBrushUsesCompositeBackdrop(mode)
        ? appProvider.layers.capturePainterToImageThroughLayerSync(appProvider.layers.selectedLayerIndex)
        : appProvider.layers.selectedLayer.toImageForStorage(appProvider.layers.size);
    _pixelBrushClipPath = appProvider.selectorModel.isVisible && appProvider.selectorModel.path1 != null
        ? ui.Path.from(appProvider.selectorModel.path1!)
        : null;
    _preparedPixelBrushSource = null;
    _livePixelBuffer = null;
    _lastKickedPointIndex = 0;
    final Future<PreparedSmudgeStrokeSource?> preparation = preparePixelBrushSource(
      sourceImage: _pixelBrushSourceImage!,
      clipPath: _pixelBrushClipPath,
    );
    _pixelBrushPreparation = preparation;
    unawaited(
      preparation.then((final PreparedSmudgeStrokeSource? prepared) {
        if (identical(_pixelBrushPreparation, preparation)) {
          _preparedPixelBrushSource = prepared;
        }
      }),
    );
    _appendPixelBrushPoint(position, appProvider.brushSize);
  }
}

class PixelBrushLayerPatch {
  const PixelBrushLayerPatch({
    required this.bounds,
    required this.image,
  });

  final ui.Rect bounds;
  final ui.Image image;
}

ActionType pixelBrushActionType(final PixelBrushMode mode) {
  return mode == PixelBrushMode.smudge ? ActionType.smudge : ActionType.blurBrush;
}

bool pixelBrushUsesCompositeBackdrop(final PixelBrushMode mode) {
  return mode == PixelBrushMode.smudge || mode == PixelBrushMode.blur;
}

int normalizePixelBrushRemainingStart({
  required final int lastKickedPointIndex,
  required final int strokePointCount,
}) {
  return lastKickedPointIndex.clamp(AppMath.zero, strokePointCount);
}

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

Future<PixelBrushLayerPatch?> buildPixelBrushLayerPatch({
  required final Uint8List pixels,
  required final int imageWidth,
  required final int imageHeight,
  required final List<Offset> strokePoints,
  required final double brushSize,
}) async {
  final ui.Rect? patchBounds = resolvePixelBrushPatchBounds(
    strokePoints: strokePoints,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    brushSize: brushSize,
  );
  if (patchBounds == null) {
    return null;
  }

  final Uint8List patchPixels = copyPixelBrushRect(
    pixels: pixels,
    imageWidth: imageWidth,
    left: patchBounds.left.toInt(),
    top: patchBounds.top.toInt(),
    width: patchBounds.width.toInt(),
    height: patchBounds.height.toInt(),
  );
  final ui.Image patchImage = await imageFromPixels(
    patchPixels,
    patchBounds.width.toInt(),
    patchBounds.height.toInt(),
  );
  return PixelBrushLayerPatch(bounds: patchBounds, image: patchImage);
}

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
