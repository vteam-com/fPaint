import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/panels/canvas_panel.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/fill_widget.dart';
import 'package:fpaint/widgets/selector_widget.dart';

/// The main view of the application, which is a stateful widget.
/// This widget is responsible for managing the state of the main view,
/// including handling pointer events and scaling/centering the canvas.
class MainView extends StatefulWidget {
  const MainView({
    super.key,
  });

  @override
  MainViewState createState() => MainViewState();
}

class MainViewState extends State<MainView> {
  int _activePointerId = -1;
  Size lastViewPortSize = const Size(0, 0);
  double scaleTolerance = 0.01;
  final List<int> _activePointers = <int>[];
  final Map<int, Offset> _pointerPositions = <int, ui.Offset>{};
  double _scaleFactor = 1.0; // Initialize scale factor for pinch zoom
  double _baseDistance = 0.0; // Store the initial distance when pinch starts

  @override
  Widget build(final BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context, listen: true);

    return Stack(
      children: <Widget>[
        LayoutBuilder(
          builder: (
            final BuildContext context,
            final BoxConstraints constraints,
          ) {
            final ShellProvider shellProvider = ShellProvider.of(context);

            // Fit/Center the canvas if requested
            if (shellProvider.canvasPlacement == CanvasAutoPlacement.fit) {
              appProvider.canvasFitToContainer(
                containerWidth: constraints.maxWidth,
                containerHeight: constraints.maxHeight,
              );
            }

            return Listener(
              onPointerSignal: (final PointerSignalEvent event) {
                // print('onPointerSignal $event');
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

              // Not call on touch screen device like iOS
              // instead onPointerDown is used
              onPointerPanZoomStart: (final PointerPanZoomStartEvent event) {
                // print(
                //   'Listener-onPointerPanZoomStart ${event.toString()}',
                // );
              },

              //
              // PAN and SCALE for Web, Linux & Windows
              // this is not invoked for Touch devices and we skip MacOS, since trackpad behavior are received inthe onPointerSignal: event
              //
              onPointerPanZoomUpdate: (final PointerPanZoomUpdateEvent event) {
                // print(
                //   'Listener-onPointerPanZoomUpdate ${event.toString()}',
                // );

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
                // print(
                //   'Listener-onPointerPanZoomEnd ${event.toString()}',
                // );
              },

              // Pointer DOWN
              onPointerDown: (final PointerDownEvent event) {
                // print('onPointerDown');
                if (event.kind == PointerDeviceKind.touch) {
                  _pointerPositions[event.pointer] = event.localPosition;
                  _getDistanceBetweenTouchPoints();

                  _activePointers.add(event.pointer);

                  if (_activePointers.length == 2) {
                    // Set the initial focal point between two fingers
                    _baseDistance = _getDistanceBetweenTouchPoints();
                  } else {
                    if (event.buttons == 1 &&
                        !appProvider.preferences.useApplePencil) {
                      _handlePointerStart(appProvider, event);
                    }
                  }
                } else {
                  _handlePointerStart(appProvider, event);
                }
              },

              // Pointer MOVE
              onPointerMove: (final PointerMoveEvent event) {
                // print('Move');
                if (event.kind == PointerDeviceKind.touch) {
                  _pointerPositions[event.pointer] = event.localPosition;
                  _getDistanceBetweenTouchPoints();

                  if (_activePointers.length == 2) {
                    _handleMultiTouchUpdate(event, appProvider, shellProvider);
                  } else {
                    if (event.buttons == 1 &&
                        !appProvider.preferences.useApplePencil) {
                      _handlePointerMove(appProvider, event);
                    }
                  }
                } else {
                  _handlePointerMove(appProvider, event);
                }
              },

              // Pointer UP/CANCEL/END
              onPointerUp: (final PointerUpEvent event) {
                if (event.kind == PointerDeviceKind.touch) {
                  _pointerPositions.remove(event.pointer);
                  _getDistanceBetweenTouchPoints(); // Recalculate distance
                  _activePointers.remove(event.pointer);
                  if (_activePointers.length < 2) {
                    _baseDistance = 0.0; // Reset base distance
                  } else {
                    if (event.buttons == 1 &&
                        !appProvider.preferences.useApplePencil) {
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
              child: _displayCanvas(appProvider),
            );
          },
        ),

        //
        // Selection Widget
        //
        if (appProvider.selectorModel.isVisible)
          SelectionRectWidget(
            path1: appProvider.getPathAdjustToCanvasSizeAndPosition(
              appProvider.selectorModel.path1,
            ),
            path2: appProvider.getPathAdjustToCanvasSizeAndPosition(
              appProvider.selectorModel.path2,
            ),
            enableMoveAndResize:
                appProvider.selectedAction == ActionType.selector,
            onDrag: (final Offset offset) {
              appProvider.selectorModel.translate(offset);
              appProvider.update();
            },
            onResize: (final NineGridHandle handle, final Offset offset) {
              appProvider.selectorModel.nindeGridResize(handle, offset);
              appProvider.update();
            },
          ),

        //
        // Fill Widget
        //
        if (appProvider.fillModel.isVisible)
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: FillWidget(
              fillModel: appProvider.fillModel,
              onDrag: (final GradientPoint point) {
                appProvider.update();
              },
            ),
          ),
      ],
    );
  }

  void _handleMultiTouchUpdate(
    final PointerMoveEvent event,
    final AppProvider appProvider,
    final ShellProvider shellProvider,
  ) {
    // print('_handleMultiTouchUpdate $event');

    // Calculate the panning offset - Always pan when two fingers are down and moving
    appProvider.canvasOffset += event.delta;
    final double newDistance = _getDistanceBetweenTouchPoints();
    final double distanceDelta = _baseDistance - newDistance;
    // print(
    //   'last ${event.localPosition} eventDelta ${event.delta} _baseDistance $_baseDistance  $newDistance $distanceDelta',
    // );

    // Handle scaling - Always handle scaling if two fingers are down and moving
    if (distanceDelta.abs() > 50) {
      // print(distanceDelta.abs().toString());
      _scaleFactor = _getDistanceBetweenTouchPoints() / _baseDistance;
      // Limit scaling factor if needed
      _scaleFactor = max(0.1, min(_scaleFactor, 10.0));

      // Step 1: Convert screen coordinates to canvas coordinates
      final Offset before = appProvider.toCanvas(event.localPosition);

      // Step 2: Apply the scale change
      appProvider.layers.scale = _scaleFactor; // Use _scaleFactor directly

      // Step 3: Calculate the new position on the canvas
      final Offset after = appProvider.toCanvas(event.localPosition);

      // Step 4: Adjust the offset to keep the focal point anchored during zoom
      final Offset adjustment = after - before;
      appProvider.canvasOffset += adjustment * appProvider.layers.scale;
    }

    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
    // Update canvas after scaling and panning
    appProvider.update();
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

  void _handleUserPanningTheCanvas(
    final ShellProvider shellProvider,
    final AppProvider appProvider,
    final Offset offsetDelta,
  ) {
    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
    appProvider.canvasPan(offsetDelta: offsetDelta);
  }

  /// Handle zooming/scaling
  void _handleUserScalingTheCanvas(
    final ShellProvider shellProvider,
    final AppProvider appProvider,
    final Offset anchorPoint,
    final double scaleDelta,
  ) {
    if (scaleDelta == 1) {
      // nothing to scale
      return;
    }

    // Step 0: We are now in manual user placement of the canvas
    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;

    appProvider.applyScaleToCanvas(
      scaleDelta: scaleDelta,
      anchorPoint: anchorPoint,
    );
  }

  Widget _displayCanvas(final AppProvider appProvider) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          colors: <ui.Color>[
            Colors.grey.shade50,
            Colors.grey.shade500,
          ],
          stops: <double>[0, 1],
        ),
      ),
      child: Transform(
        alignment: Alignment.topLeft,
        transform: Matrix4.identity()
          ..translate(
            appProvider.canvasOffset.dx,
            appProvider.canvasOffset.dy,
          )
          ..scale(
            appProvider.layers.scale,
          ), // Use appProvider.layers.scale here
        child: const CanvasPanel(),
      ),
    );
  }

  /// Handles the start of a pointer event.
  ///
  /// This method is called when a pointer (such as a finger or stylus)
  /// starts interacting with the widget. It performs necessary actions
  /// to initialize the interaction.
  ///
  void _handlePointerStart(
    final AppProvider appProvider,
    final PointerDownEvent event,
  ) async {
    final ui.Offset adjustedPosition =
        appProvider.toCanvas(event.localPosition);
    if (event.buttons == 1 && _activePointerId == -1) {
      //
      // Remember what pointer/button the drawing started on
      //
      _activePointerId = event.pointer;

      // deal with Selector
      if (appProvider.selectedAction == ActionType.selector) {
        appProvider.selectorCreationStart(adjustedPosition);
        return;
      }

      // Make sure we can draw on this layer
      if (appProvider.layers.selectedLayer.isVisible == false) {
        //
        // Inform the user that they are attempting to draw on a layer that is hidden
        //
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selection is hidden.'),
          ),
        );
        return;
      }

      //
      // Special case, one clik action flood fill does not need to be tracked
      //
      if (appProvider.selectedAction == ActionType.fill) {
        if (appProvider.fillModel.mode == FillMode.solid) {
          appProvider.fillModel.gradientPoints.clear();
          appProvider.floodFillAction(adjustedPosition);
        } else {
          if (appProvider.fillModel.gradientPoints.isEmpty) {
            appProvider.fillModel.addPoint(
              GradientPoint(
                offset: adjustedPosition + const Offset(100, 100),
                color: Colors.red,
              ),
            );
            appProvider.fillModel.addPoint(
              GradientPoint(
                offset: adjustedPosition + const Offset(-100, -100),
                color: Colors.blue,
              ),
            );
            appProvider.update();
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

  /// Handles the pointer move event.
  ///
  /// This method is called when a pointer moves within the widget's bounds.
  /// It performs necessary actions based on the pointer's movement.
  ///
  void _handlePointerMove(
    final AppProvider appProvider,
    final PointerEvent event,
  ) {
    //
    // Translate the input position to the canvas position and scale
    //
    final Offset adjustedPosition = appProvider.toCanvas(event.localPosition);

    // debugPrint('DRAW MOVE ${details.buttons} P:${details.pointer}');

    if (event.buttons == 1 && _activePointerId == event.pointer) {
      // Update the Selector
      if (appProvider.selectedAction == ActionType.selector) {
        appProvider.selectorCreationAdditionalPoint(adjustedPosition);
        return;
      }

      if (appProvider.selectedAction == ActionType.fill) {
        // ignore fill movement, flood fill is performed on the PointerStart event
        return;
      }

      if (appProvider.selectedAction == ActionType.pencil) {
        // Add the pixel
        appProvider.appendLineFromLastUserAction(adjustedPosition);
      } else if (appProvider.selectedAction == ActionType.eraser) {
        // Eraser implementation
        appProvider.appendLineFromLastUserAction(adjustedPosition);
      } else if (appProvider.selectedAction == ActionType.brush) {
        // Cumulate more points in the draw path on the selected layer
        appProvider.layers.selectedLayer
            .lastActionAppendPosition(position: adjustedPosition);
        appProvider.update();
      } else {
        // Existing shape logic
        appProvider.updateAction(end: adjustedPosition);
        appProvider.update();
      }
    }
  }

  /// Handles the end of a pointer event.
  ///
  /// This method is called when a pointer that was previously in contact
  /// with the screen is lifted off. It is typically used to finalize any
  /// interactions that were started during the pointer down or move events.
  void _handlePointerEnd(
    final AppProvider appProvider,
    final PointerEvent event,
  ) async {
    // debugPrint('UP ${details.buttons}');
    appProvider.layers.selectedLayer.isUserDrawing = false;

    if (_activePointerId == event.pointer) {
      if (appProvider.selectedAction == ActionType.selector) {
        appProvider.selectorCreationEnd();
      }
      _activePointerId = -1;
      // trigger a Thumbnail update
      appProvider.layers.selectedLayer.clearCache();
      appProvider.update();
    }
  }
}
