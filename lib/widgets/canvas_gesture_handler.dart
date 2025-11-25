import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/text_editor_dialog.dart';

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
  double _scaleFactor = 1.0;

  @override
  Widget build(final BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context, listen: false);
    final ShellProvider shellProvider = ShellProvider.of(context);

    return Listener(
      onPointerSignal: (final PointerSignalEvent event) {
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
      onPointerPanZoomStart: (final PointerPanZoomStartEvent event) {
        // No-op
      },
      onPointerPanZoomUpdate: (final PointerPanZoomUpdateEvent event) {
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
      onPointerPanZoomEnd: (final PointerPanZoomEndEvent event) {
        // No-op
      },
      onPointerDown: (final PointerDownEvent event) {
        if (event.kind == PointerDeviceKind.touch) {
          _pointerPositions[event.pointer] = event.localPosition;
          _getDistanceBetweenTouchPoints();

          _activePointers.add(event.pointer);

          if (_activePointers.length == 2) {
            // Set the initial focal point between two fingers
            _baseDistance = _getDistanceBetweenTouchPoints();
          } else {
            if (event.buttons == 1 && !appProvider.preferences.useApplePencil) {
              _handlePointerStart(appProvider, event);
            }
          }
        } else {
          _handlePointerStart(appProvider, event);
        }
      },
      onPointerMove: (final PointerMoveEvent event) {
        if (event.kind == PointerDeviceKind.touch) {
          _pointerPositions[event.pointer] = event.localPosition;
          _getDistanceBetweenTouchPoints();

          if (_activePointers.length == 2) {
            _handleMultiTouchUpdate(
              event,
              appProvider,
              shellProvider,
            );
          } else {
            if (event.buttons == 1 && !appProvider.preferences.useApplePencil) {
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
          if (_activePointers.length < 2) {
            _baseDistance = 0.0; // Reset base distance
          } else {
            if (event.buttons == 1 && !appProvider.preferences.useApplePencil) {
              _handlePointerEnd(appProvider, event);
            }
          }
        } else {
          _handlePointerEnd(appProvider, event);
        }
      },
      onPointerCancel: (final PointerCancelEvent event) {
        if (event.kind == PointerDeviceKind.touch) {
          _pointerPositions.remove(event.pointer);
          _getDistanceBetweenTouchPoints(); // Recalculate distance
          _activePointers.remove(event.pointer);
          if (_activePointers.length < 2) {
            _baseDistance = 0.0; // Reset base distance
          }
        } else {
          _handlePointerEnd(appProvider, event);
        }
      },
      child: widget.child,
    );
  }

  double _getDistanceBetweenTouchPoints() {
    if (_pointerPositions.length >= 2) {
      final List<Offset> positions = _pointerPositions.values.toList();
      final Offset pos1 = positions[0];
      final Offset pos2 = positions[1];
      return (pos2 - pos1).distance;
    } else {
      return 0.0;
    }
  }

  void _handleMultiTouchUpdate(
    final PointerMoveEvent event,
    final AppProvider appProvider,
    final ShellProvider shellProvider,
  ) {
    appProvider.canvasOffset += event.delta;
    final double newDistance = _getDistanceBetweenTouchPoints();
    final double distanceDelta = _baseDistance - newDistance;

    if (distanceDelta.abs() > 50) {
      _scaleFactor = _getDistanceBetweenTouchPoints() / _baseDistance;
      _scaleFactor = max(0.1, min(_scaleFactor, 10.0));

      final Offset before = appProvider.toCanvas(event.localPosition);
      appProvider.layers.scale = _scaleFactor;
      final Offset after = appProvider.toCanvas(event.localPosition);
      final Offset adjustment = after - before;
      appProvider.canvasOffset += adjustment * appProvider.layers.scale;
    }

    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
    appProvider.update();
  }

  void _handlePointerEnd(
    final AppProvider appProvider,
    final PointerEvent event,
  ) async {
    appProvider.layers.selectedLayer.isUserDrawing = false;

    if (_activePointerId == event.pointer) {
      if (appProvider.selectedAction == ActionType.selector) {
        appProvider.selectorCreationEnd();
      }
      _activePointerId = -1;
      appProvider.layers.selectedLayer.clearCache();
      appProvider.update();
    }
  }

  void _handlePointerMove(
    final AppProvider appProvider,
    final PointerEvent event,
  ) {
    final Offset adjustedPosition = appProvider.toCanvas(event.localPosition);

    if (appProvider.eyeDropPositionForBrush != null) {
      appProvider.eyeDropPositionForBrush = event.localPosition;
      appProvider.update();
      return;
    }
    if (appProvider.eyeDropPositionForFill != null) {
      appProvider.eyeDropPositionForFill = event.localPosition;
      appProvider.update();
      return;
    }

    if (event.buttons == 1 && _activePointerId == event.pointer) {
      if (appProvider.selectedAction == ActionType.selector) {
        appProvider.selectorCreationAdditionalPoint(adjustedPosition);
        return;
      }

      if (appProvider.selectedAction == ActionType.fill) {
        return;
      }

      if (appProvider.selectedAction == ActionType.pencil) {
        appProvider.appendLineFromLastUserAction(adjustedPosition);
      } else if (appProvider.selectedAction == ActionType.eraser) {
        appProvider.appendLineFromLastUserAction(adjustedPosition);
      } else if (appProvider.selectedAction == ActionType.brush) {
        appProvider.layers.selectedLayer.lastActionAppendPosition(position: adjustedPosition);
        appProvider.update();
      } else {
        appProvider.updateAction(end: adjustedPosition);
        appProvider.update();
      }
    }
  }

  void _handlePointerStart(
    final AppProvider appProvider,
    final PointerDownEvent event,
  ) async {
    final ui.Offset adjustedPosition = appProvider.toCanvas(event.localPosition);

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

      if (appProvider.selectedAction == ActionType.selector) {
        appProvider.selectorCreationStart(adjustedPosition);
        return;
      }

      if (appProvider.layers.selectedLayer.isVisible == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selection is hidden.'),
          ),
        );
        return;
      }

      if (appProvider.selectedAction == ActionType.text) {
        TextObject? selectedText;

        for (final UserActionDrawing action in appProvider.layers.selectedLayer.actionStack) {
          if (action.textObject != null && action.textObject!.containsPoint(adjustedPosition)) {
            selectedText = action.textObject;
            break;
          }
        }

        if (selectedText != null) {
          appProvider.selectedTextObject = selectedText;
          appProvider.update();
          return;
        }

        _showTextDialog(appProvider, adjustedPosition);
        return;
      }

      if (appProvider.selectedAction == ActionType.fill) {
        if (appProvider.fillModel.mode == FillMode.solid) {
          appProvider.fillModel.gradientPoints.clear();
          appProvider.floodFillSolidAction(adjustedPosition);
        } else {
          if (appProvider.fillModel.gradientPoints.isEmpty) {
            if (appProvider.fillModel.mode == FillMode.linear) {
              appProvider.fillModel.addPoint(
                GradientPoint(
                  offset: appProvider.fromCanvas(adjustedPosition + const Offset(-40, 0)),
                  color: adjustBrightness(appProvider.fillColor, 0.3),
                ),
              );
              appProvider.fillModel.addPoint(
                GradientPoint(
                  offset: appProvider.fromCanvas(adjustedPosition + const Offset(40, 0)),
                  color: adjustBrightness(appProvider.fillColor, 0.7),
                ),
              );
            } else if (appProvider.fillModel.mode == FillMode.radial) {
              appProvider.fillModel.addPoint(
                GradientPoint(
                  offset: appProvider.fromCanvas(adjustedPosition),
                  color: adjustBrightness(appProvider.fillColor, 0.3),
                ),
              );
              appProvider.fillModel.addPoint(
                GradientPoint(
                  offset: appProvider.fromCanvas(adjustedPosition + const Offset(50, 50)),
                  color: adjustBrightness(appProvider.fillColor, 0.7),
                ),
              );
            }
            appProvider.fillModel.isVisible = true;
            appProvider.floodFillGradientAction(appProvider.fillModel);
          }
        }
        return;
      }

      appProvider.layers.selectedLayer.isUserDrawing = true;

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
    appProvider.canvasPan(offsetDelta: offsetDelta);
  }

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
    );
  }

  void _showTextDialog(final AppProvider appProvider, final Offset position) {
    showDialog<void>(
      context: context,
      builder: (final BuildContext context) {
        return TextEditorDialog(
          initialFontSize: appProvider.brushSize,
          initialColor: appProvider.brushColor,
          position: position,
          onFinished: (final TextObject textObject) {
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
}
