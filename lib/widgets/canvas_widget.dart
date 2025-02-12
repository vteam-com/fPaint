import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/panels/canvas_panel.dart';
import 'package:fpaint/panels/tools/flood_fill.dart';
import 'package:fpaint/widgets/selector_widget.dart';

/// Provides a canvas widget that supports scaling and panning.
///
/// The [CanvasWidget] is a stateful widget that allows the user to scale and pan the content
/// within a bounded canvas area. It manages the scaling and panning state, and updates the
/// [AppModel] with the current scale and offset values.
///
/// The [CanvasWidget] takes in the [canvasWidth], [canvasHeight], and [child] widgets to be
/// displayed within the canvas. The [child] widget is transformed based on the current scale
/// and offset values.
///
/// The scaling and panning behavior is implemented using the [GestureDetector] widget, which
/// listens for scale and pan gestures from the user. The scale and offset values are updated
/// accordingly, and the [AppModel] is updated to persist the changes.

class CanvasWidget extends StatefulWidget {
  const CanvasWidget({
    super.key,
    required this.canvasWidth,
    required this.canvasHeight,
  });
  final double canvasWidth;
  final double canvasHeight;

  @override
  CanvasWidgetState createState() => CanvasWidgetState();
}

class CanvasWidgetState extends State<CanvasWidget> {
  int _activePointerId = -1;
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  Offset? _lastFocalPoint;
  double _lastScale = 1.0;
  Offset? _panStartFocalPoint;

  bool get isPanningOrScaling =>
      _panStartFocalPoint != null || _lastFocalPoint != null;

  @override
  void initState() {
    super.initState();
    final appModel = AppModel.of(context);
    _scale = appModel.canvas.scale;
    _offset = appModel.offset;
  }

  @override
  Widget build(BuildContext context) {
    final appModel = AppModel.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double viewportWidth = constraints.maxWidth;
        final double viewportHeight = constraints.maxHeight;

        final double scaledWidth = widget.canvasWidth * _scale;
        final double scaledHeight = widget.canvasHeight * _scale;

        final double centerX = max(0, (viewportWidth - scaledWidth) / 2);
        final double centerY = max(0, (viewportHeight - scaledHeight) / 2);

        final double topLeftTranslated = _offset.dx + centerX;
        final double topTopTranslated = _offset.dy + centerY;

        Rect? selectionRect;
        if (appModel.selector.isVisible) {
          appModel.selectorAdjusterRect = appModel.selector.getAdjustedRect(
            topLeftTranslated,
            topTopTranslated,
            _scale,
          );
          selectionRect = appModel.selectorAdjusterRect;
        }

        return GestureDetector(
          onScaleStart: (final ScaleStartDetails details) {
            // debugPrint('SSS onScaleStart {$details.pointerCount}');
            if (details.pointerCount == 2) {
              _activePointerId = -1; // cancel any drawing
              _lastFocalPoint = details.focalPoint;
              _lastScale = _scale;
              _panStartFocalPoint =
                  details.focalPoint; //Initialize PanStart on 2 finger
            }
          },
          onScaleUpdate: (final ScaleUpdateDetails details) {
            if (details.pointerCount == 2) {
              // debugPrint(
              //   'onScaleUpdate P2 ${details.scale}',
              // );
              if (isPanningOrScaling) {
                if (details.scale < 1.1 && details.scale > 0.9) {
                  // debugPrint('>>> PAN');
                  // Panning
                  final Offset delta =
                      details.focalPoint - _panStartFocalPoint!;
                  _offset += delta;
                  _panStartFocalPoint = details.focalPoint;
                } else {
                  // debugPrint('+++ Scale by $scaleDelta');
                  // Scaling
                  _scale = (_lastScale * details.scale).clamp(0.5, 4.0);
                  final Offset focalPointDelta =
                      details.focalPoint - _lastFocalPoint!;
                  _offset +=
                      focalPointDelta - focalPointDelta * (_scale / _lastScale);
                  _lastFocalPoint = details.focalPoint;
                }
              }

              if (appModel.canvas.scale != _scale ||
                  appModel.offset != _offset) {
                setState(
                  () {
                    // Update appModel with the new scale and offset
                    // debugPrint('setState > Scale $_scale  offset $_offset');
                    appModel.canvas.scale = _scale;
                    appModel.offset = _offset;
                  },
                );
              }
            }
          },
          onScaleEnd: (final ScaleEndDetails details) {
            _activePointerId = -1;
            _lastFocalPoint = null;
            _panStartFocalPoint = null;
          },
          child: Stack(
            children: [
              Transform(
                alignment: Alignment.topLeft,
                transform: Matrix4.identity()
                  ..translate(
                    topLeftTranslated,
                    topTopTranslated,
                  )
                  ..scale(_scale),
                child: SizedBox(
                  width: max(widget.canvasWidth, viewportWidth),
                  height: max(widget.canvasHeight, viewportHeight),
                  child: Listener(
                    //----------------------------------------------------------------
                    // Pinch/Zoom scaling for WEB
                    onPointerSignal: (final PointerSignalEvent event) {
                      if (event is PointerScaleEvent) {
                        appModel.setCanvasScale(
                          appModel.canvas.scale * event.scale,
                        );
                      }
                    },

                    //----------------------------------------------------------------
                    // Pinch/Zoom scaling for Desktop
                    onPointerPanZoomUpdate:
                        (final PointerPanZoomUpdateEvent event) {
                      _scaleCanvas(appModel, event.scale, event.position);
                    },

                    //----------------------------------------------------------------
                    // Draw Start
                    onPointerDown: (final PointerDownEvent event) =>
                        _handlePointerStart(appModel, event),

                    //----------------------------------------------------------------
                    // Draw Update
                    onPointerMove: (final PointerEvent event) =>
                        _handlePointerMove(appModel, event),

                    //----------------------------------------------------------------
                    // Draw End
                    onPointerUp: (PointerUpEvent event) =>
                        _handPointerEnd(appModel, event),

                    //----------------------------------------------------------------
                    // Draw End
                    onPointerCancel: (final PointerCancelEvent event) =>
                        _handPointerEnd(appModel, event),

                    //----------------------------------------------------------------
                    // Main content
                    child: CanvasPanel(appModel: appModel),
                  ),
                ),
              ),
              if (appModel.selector.isVisible && selectionRect != null)
                SelectionHandleWidget(
                  selectionRect: selectionRect,
                  enableMoveAndResize:
                      appModel.selectedTool == ActionType.selector,
                  onDrag: (Offset offset) {
                    appModel.selector.translate(offset);
                    appModel.update();
                  },
                  onResize: (SelectorHandlePosition handle, Offset offset) {
                    appModel.selector.resizeFromSides(handle, offset);
                    appModel.update();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handlePointerStart(
    final AppModel appModel,
    final PointerDownEvent event,
  ) async {
    // only draw when not panning or scalling
    if (isPanningOrScaling) {
      // debugPrint('currently panning or scaling ignore pointer down event');
    } else {
      // debugPrint('DOWN ${details.buttons} P:${details.pointer}');
      if (event.buttons == 1 && _activePointerId == -1) {
        if (appModel.isCurrentSelectionReadyForAction) {
          _activePointerId = event.pointer;

          if (appModel.selectedTool == ActionType.selector) {
            appModel.selectorStart(event.localPosition / appModel.canvas.scale);
            return;
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selection is hidden.'),
            ),
          );
        }
      }
    }
  }

  Future<void> _handlePointerMove(
    final AppModel appModel,
    final PointerEvent event,
  ) async {
    final Offset position = event.localPosition / appModel.canvas.scale;
    if (isPanningOrScaling) {
      // Currently panning or scaling so don't draw
      // debugPrint('DRAW MOVE PANNING IS ON');
    } else {
      // debugPrint('DRAW MOVE ${details.buttons} P:${details.pointer}');
      if (event.buttons == 1 && _activePointerId == event.pointer) {
        if (appModel.selectedTool == ActionType.selector) {
          appModel.selectorMove(position);
          return;
        }

        // the other tools
        if (appModel.userActionStartingOffset == null) {
          await _onUserActionStart(
            appModel: appModel,
            position: position,
          );
        } else {
          _onUserActionMove(
            appModel: appModel,
            position: event.localPosition / appModel.canvas.scale,
          );
        }
      }
    }
  }

  Future<void> _handPointerEnd(
    final AppModel appModel,
    final PointerEvent event,
  ) async {
    if (!isPanningOrScaling) {
      if (_activePointerId == event.pointer) {
        // debugPrint('UP ${details.buttons}');
        // handle the case that the user click and release the mouse withou moving
        if (appModel.selectedTool == ActionType.selector) {
          appModel.selectorEndMovement();
          return;
        }

        if (appModel.userActionStartingOffset == null &&
            (appModel.selectedTool == ActionType.pencil ||
                appModel.selectedTool == ActionType.fill ||
                appModel.selectedTool == ActionType.eraser)) {
          await _onUserActionStart(
            appModel: appModel,
            position: event.localPosition / appModel.canvas.scale,
          );
        }

        _onUserActionEnded(appModel);
      }
    }
  }

  Future<bool> _onUserActionStart({
    required final AppModel appModel,
    required final Offset position,
  }) async {
    appModel.userActionStartingOffset = position;

    if (appModel.selectedTool == ActionType.fill) {
      // Create a flattened image from the current layer
      final ui.Image img = await appModel.getImageForCurrentSelectedLayer();

      // Perform flood fill at the clicked position
      final ui.Image filledImage = await applyFloodFill(
        image: img,
        x: position.dx.toInt(),
        y: position.dy.toInt(),
        newColor: appModel.fillColor,
        tolerance: appModel.tolerance,
      );
      appModel.selectedLayer
          .addImage(imageToAdd: filledImage, tool: ActionType.fill);
      appModel.update();
      return true;
    }

    appModel.currentUserAction = UserAction(
      tool: appModel.selectedTool,
      positions: [position, position],
      brush: MyBrush(
        color: appModel.brushColor,
        size: appModel.brusSize,
        style: appModel.brushStyle,
      ),
      fillColor: appModel.fillColor,
    );

    appModel.addUserAction(action: appModel.currentUserAction!);
    return false;
  }

  void _onUserActionMove({
    required final AppModel appModel,
    required final Offset position,
  }) {
    if (appModel.userActionStartingOffset != null) {
      if (appModel.selectedTool == ActionType.selector) {
        appModel.selectorMove(position);
        return;
      }

      if (appModel.selectedTool == ActionType.pencil) {
        // Add the pixel
        appModel.updateLastUserAction(
          start: appModel.userActionStartingOffset!,
          end: position,
          type: appModel.selectedTool,
          colorStroke: appModel.brushColor,
          colorFill: appModel.brushColor,
        );
        appModel.userActionStartingOffset = position;
      } else if (appModel.selectedTool == ActionType.eraser) {
        // Eraser implementation
        appModel.updateLastUserAction(
          start: appModel.userActionStartingOffset!,
          end: position,
          type: appModel.selectedTool,
          colorStroke: Colors.transparent,
          colorFill: Colors.transparent,
        );
        appModel.userActionStartingOffset = position;
      } else if (appModel.selectedTool == ActionType.brush) {
        // Cumulate more points in the draw path on the selected layer
        appModel.layers.list[appModel.selectedLayerIndex]
            .lastActionAddPosition(position: position);
        appModel.update();
      } else {
        // Existing shape logic
        appModel.updateLastUserAction(end: position);
        appModel.update();
      }
    }
  }

  void _onUserActionEnded(
    final AppModel appModel,
  ) {
    if (appModel.selectedTool == ActionType.selector) {
      appModel.selectorEndMovement();
      return;
    }
    //debugPrint('End gesture $_activePointerId now -1');
    _activePointerId = -1;
    appModel.currentUserAction = null;
    appModel.userActionStartingOffset = null;
    appModel.selectedLayer.clearCache();
    appModel.update();
  }

  void _scaleCanvas(AppModel appModel, double scaleDelta, Offset focalPoint) {
    final double newScale = appModel.canvas.scale * scaleDelta;

    // Ensure scale remains within reasonable limits
    final double minScale = 0.1;
    final double maxScale = 5.0;
    if (newScale < minScale || newScale > maxScale) {
      return;
    }

    // Adjust canvas offset so that focalPoint remains at the same screen position
    final Offset beforeFocalCanvas =
        (focalPoint - appModel.offset) / appModel.canvas.scale;
    final Offset newOffset = focalPoint - (beforeFocalCanvas * newScale);

    appModel.offset = newOffset;
    appModel.setCanvasScale(newScale);
  }
}
