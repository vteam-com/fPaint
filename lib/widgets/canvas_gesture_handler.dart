import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
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
  final Map<int, Offset> _pointerPositions = <int, ui.Offset>{};
  PreparedSmudgeStrokeSource? _preparedSmudgeSource;
  double _scaleFactor = 1.0;
  ui.Path? _smudgeClipPath;
  ImagePlacementLayerRestoreState? _smudgeLayerRestoreState;
  Future<PreparedSmudgeStrokeSource?>? _smudgePreparation;
  ui.Image? _smudgeSourceImage;
  final List<Offset> _smudgeStrokePoints = <Offset>[];
  @override
  Widget build(final BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context, listen: false);
    final AppPreferences appPreferences = AppPreferences.of(context, listen: true);
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

  /// Appends a sampled pointer position to the active smudge stroke.
  void _appendSmudgePoint(
    final Offset position,
    final double brushSize,
  ) {
    final double spacing = resolveSmudgeStepSpacing(brushSize);
    if (_smudgeStrokePoints.isNotEmpty && (_smudgeStrokePoints.last - position).distance < spacing) {
      return;
    }
    _smudgeStrokePoints.add(position);
  }

  /// Bakes the smudge patch into a full-layer image snapshot.
  Future<ui.Image> _bakeSmudgeLayerImage({
    required final ui.Image sourceImage,
    required final SmudgeStrokeRasterResult strokeResult,
  }) {
    return renderCanvasImage(
      width: sourceImage.width,
      height: sourceImage.height,
      draw: (final ui.Canvas canvas) {
        canvas.drawImage(sourceImage, Offset.zero, ui.Paint());
        canvas.drawImage(strokeResult.image, strokeResult.bounds.topLeft, ui.Paint());
      },
    );
  }

  /// Clears the in-progress smudge stroke state.
  void _clearSmudgeStroke() {
    _smudgeStrokePoints.clear();
    _smudgeLayerRestoreState = null;
    _preparedSmudgeSource = null;
    _smudgePreparation = null;
    _smudgeSourceImage = null;
    _smudgeClipPath = null;
  }

  /// Rasterizes the active smudge stroke and commits it as a rectangular replacement.
  Future<void> _commitSmudgeStroke(final AppProvider appProvider) async {
    final ui.Image? sourceImage = _smudgeSourceImage;
    final ImagePlacementLayerRestoreState? layerRestoreState = _smudgeLayerRestoreState;
    if (sourceImage == null || layerRestoreState == null || _smudgeStrokePoints.length < AppMath.pair) {
      return;
    }

    final PreparedSmudgeStrokeSource? preparedSource =
        _preparedSmudgeSource ??
        await _smudgePreparation ??
        await prepareSmudgeStrokeSource(
          sourceImage: sourceImage,
          clipPath: _smudgeClipPath,
        );
    if (preparedSource == null) {
      return;
    }

    final SmudgeStrokeRasterResult? result = await rasterizeSmudgeStroke(
      sourceImage: sourceImage,
      strokePoints: _smudgeStrokePoints,
      brushSize: appProvider.brushSize,
      preparedSource: preparedSource,
    );
    if (result == null) {
      return;
    }

    final ui.Image bakedImage = await _bakeSmudgeLayerImage(
      sourceImage: sourceImage,
      strokeResult: result,
    );

    appProvider.undoProvider.executeAction(
      name: ActionType.smudge.name,
      forward: () {
        final LayerProvider targetLayer = appProvider.layers.get(layerRestoreState.layerIndex);
        appProvider.layers.selectedLayerIndex = layerRestoreState.layerIndex;
        targetLayer.replaceWithRasterImage(
          imageToAdd: bakedImage,
          tool: ActionType.smudge,
        );
        appProvider.update();
      },
      backward: () {
        _restoreSmudgeLayerState(
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
      } else if (_smudgeSourceImage != null) {
        _appendSmudgePoint(appProvider.toCanvas(event.localPosition), appProvider.brushSize);
        await _commitSmudgeStroke(appProvider);
      }
      _activePointerId = -1;
      _clearSmudgeStroke();
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

      if (_smudgeSourceImage != null) {
        _appendSmudgePoint(adjustedPosition, appProvider.brushSize);
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
        appProvider.selectorCreationStart(adjustedPosition);
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
          appProvider.textToolState.size = selectedText.size;
          appProvider.textToolState.color = selectedText.color;
          appProvider.textToolState.fontWeight = selectedText.fontWeight;
          appProvider.textToolState.fontStyle = selectedText.fontStyle;
          appProvider.textToolState.textAlign = selectedText.textAlign;
          appProvider.selectedTextObject = selectedText;
          appProvider.update();
          return;
        }

        // Text creation opens a dialog on pointer down, so pointer up may not
        // reach this listener. Clear active pointer to avoid locking tools.
        _activePointerId = -1;
        _showTextDialog(appProvider, adjustedPosition);
        return;
      }

      if (appProvider.selectedAction == ActionType.fill) {
        if (await appProvider.prepareFloodFillSelection(adjustedPosition)) {
          return;
        }

        if (appProvider.fillModel.mode == FillMode.solid) {
          appProvider.fillModel.gradientPoints.clear();
          appProvider.floodFillSolidAction(adjustedPosition);
        } else {
          if (appProvider.fillModel.gradientPoints.isEmpty) {
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
        _startSmudgeStroke(appProvider, adjustedPosition);
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

  /// Restores the selected layer state captured before the current smudge stroke.
  void _restoreSmudgeLayerState({
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

  /// Starts tracking a smudge stroke from [position].
  void _startSmudgeStroke(
    final AppProvider appProvider,
    final Offset position,
  ) {
    _smudgeLayerRestoreState = appProvider.captureSelectedLayerRestoreState();
    _smudgeSourceImage = appProvider.layers.selectedLayer.toImageForStorage(appProvider.layers.size);
    _smudgeClipPath = appProvider.selectorModel.isVisible && appProvider.selectorModel.path1 != null
        ? ui.Path.from(appProvider.selectorModel.path1!)
        : null;
    _preparedSmudgeSource = null;
    final Future<PreparedSmudgeStrokeSource?> preparation = prepareSmudgeStrokeSource(
      sourceImage: _smudgeSourceImage!,
      clipPath: _smudgeClipPath,
    );
    _smudgePreparation = preparation;
    unawaited(
      preparation.then((final PreparedSmudgeStrokeSource? preparedSource) {
        if (identical(_smudgePreparation, preparation)) {
          _preparedSmudgeSource = preparedSource;
        }
      }),
    );
    _smudgeStrokePoints
      ..clear()
      ..add(position);
  }
}
