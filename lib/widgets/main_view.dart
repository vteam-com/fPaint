import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';
import 'package:fpaint/panels/canvas_panel.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
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
  Offset? _lastFocalPoint;
  final Map<int, Offset> _pointerPositions = <int, ui.Offset>{};
  double _distanceBetweenFingers = 0.0;
  double _scaleFactor = 1.0; // Initialize scale factor for pinch zoom
  double _baseDistance = 0.0; // Store the initial distance when pinch starts

  @override
  Widget build(final BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context, listen: true);
    return Stack(
      children: <Widget>[
        LayoutBuilder(
          builder:
              (final BuildContext context, final BoxConstraints constraints) {
            final ShellProvider shellModel = ShellProvider.of(context);

            // Center canvas if requested
            // scale the canvas to fit the current viewport
            if (shellModel.centerImageInViewPort) {
              shellModel.centerImageInViewPort = false;
              canvasCenterAndFit(
                appProvider: appProvider,
                containerWidth: constraints.maxWidth,
                containerHeight: constraints.maxHeight,
                scaleToContainer: shellModel.fitCanvasIntoScreen,
                notifyListener: false,
              );
              shellModel.fitCanvasIntoScreen = false;
            }

            return Listener(
              onPointerSignal: (final PointerSignalEvent event) {
                // print('onPointerSignal $event');
                // Needed for WEB PANNING
                if (event is PointerScrollEvent) {
                  appProvider.offset +=
                      Offset(-event.scrollDelta.dx, -event.scrollDelta.dy);
                  appProvider.update();
                } else {
                  if (event is PointerScaleEvent) {
                    _handleScaling(
                      appProvider,
                      event.localPosition,
                      event.scale,
                    );
                    appProvider.update();
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
                  appProvider.offset += event.panDelta;
                } else {
                  // Scaling
                  _handleScaling(
                    appProvider,
                    event.localPosition,
                    event.scale,
                  );
                }
                appProvider.update();
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
                  _calculateDistance();

                  _activePointers.add(event.pointer);

                  if (_activePointers.length == 2) {
                    // Set the initial focal point between two fingers
                    _lastFocalPoint = event.localPosition;
                    _baseDistance =
                        _distanceBetweenFingers; // Record initial distance for scaling
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
                  _calculateDistance();

                  if (_activePointers.length == 2) {
                    final Offset currentFocalPoint = event.localPosition;

                    // Calculate the panning offset - Always pan when two fingers are down and moving
                    if (_lastFocalPoint != null) {
                      final Offset panDelta =
                          currentFocalPoint - _lastFocalPoint!;
                      appProvider.offset += panDelta;
                      _lastFocalPoint =
                          currentFocalPoint; // Update the focal point
                    }

                    // Handle scaling - Always handle scaling if two fingers are down and moving
                    if (_baseDistance > 0) {
                      _scaleFactor = _distanceBetweenFingers / _baseDistance;
                      // Limit scaling factor if needed
                      _scaleFactor = max(0.1, min(_scaleFactor, 10.0));

                      // Step 1: Convert screen coordinates to canvas coordinates
                      final Offset before =
                          appProvider.toCanvas(_lastFocalPoint!);

                      // Step 2: Apply the scale change
                      appProvider.layers.scale =
                          _scaleFactor; // Use _scaleFactor directly

                      // Step 3: Calculate the new position on the canvas
                      final Offset after =
                          appProvider.toCanvas(_lastFocalPoint!);

                      // Step 4: Adjust the offset to keep the focal point anchored during zoom
                      final Offset adjustment = (before - after);
                      appProvider.offset -=
                          adjustment * appProvider.layers.scale;
                    }

                    // Update canvas after scaling and panning
                    appProvider.update();
                  }
                } else {
                  _handlePointerMove(appProvider, event);
                }
              },

              // Pointer UP/CANCEL/END
              onPointerUp: (final PointerUpEvent event) {
                if (event.kind == PointerDeviceKind.touch) {
                  _pointerPositions.remove(event.pointer);
                  _calculateDistance(); // Recalculate distance
                  _activePointers.remove(event.pointer);
                  if (_activePointers.length < 2) {
                    _lastFocalPoint = null;
                    _baseDistance = 0.0; // Reset base distance
                  }
                } else {
                  _handlePointerEnd(appProvider, event);
                }
              },

              onPointerCancel: (final PointerCancelEvent event) {
                if (event.kind == PointerDeviceKind.touch) {
                  _pointerPositions.remove(event.pointer);
                  _calculateDistance(); // Recalculate distance
                  _activePointers.remove(event.pointer);
                  if (_activePointers.length < 2) {
                    _lastFocalPoint = null;
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
        if (appProvider.selector.isVisible)
          SelectionHandleWidget(
            path1: appProvider.getPathAdjustToCanvasSizeAndPosition(
              appProvider.selector.path1,
            ),
            path2: appProvider.getPathAdjustToCanvasSizeAndPosition(
              appProvider.selector.path2,
            ),
            enableMoveAndResize:
                appProvider.selectedAction == ActionType.selector,
            onDrag: (final Offset offset) {
              appProvider.selector.translate(offset);
              appProvider.update();
            },
            onResize: (final NineGridHandle handle, final Offset offset) {
              appProvider.selector.nindeGridResize(handle, offset);
              appProvider.update();
            },
          ),
      ],
    );
  }

  double _calculateDistance() {
    if (_pointerPositions.length >= 2) {
      final List<Offset> positions = _pointerPositions.values.toList();
      final Offset pos1 = positions[0];
      final Offset pos2 = positions[1];
      _distanceBetweenFingers = (pos2 - pos1).distance;
    } else {
      _distanceBetweenFingers = 0.0;
    }
    // print('_calculateDistance $_distanceBetweenFingers');
    return _distanceBetweenFingers;
  }

  /// Handle zooming/scaling
  void _handleScaling(
    final AppProvider appModel,
    final Offset anchorPoint,
    final double scaleDelta,
  ) {
    if (scaleDelta == 1) {
      // nothing to scale
      return;
    }

    // Step 1: Convert screen coordinates to canvas coordinates
    final Offset before = appModel.toCanvas(anchorPoint);

    // Step 2: Apply the scale change
    appModel.layers.scale = appModel.layers.scale * scaleDelta;

    // Step 3: Calculate the new position on the canvas
    final Offset after = appModel.toCanvas(anchorPoint);

    // Step 4: Adjust the offset to keep the cursor anchored
    final Offset adjustment = (before - after);
    appModel.offset -= adjustment * appModel.layers.scale;
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
            appProvider.offset.dx,
            appProvider.offset.dy,
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
    final AppProvider appModel,
    final PointerDownEvent event,
  ) async {
    final ui.Offset adjustedPosition = appModel.toCanvas(event.localPosition);
    if (event.buttons == 1 && _activePointerId == -1) {
      //
      // Remember what pointer/button the drawing started on
      //
      _activePointerId = event.pointer;

      // deal with Selector
      if (appModel.selectedAction == ActionType.selector) {
        appModel.selectorCreationStart(adjustedPosition);
        return;
      }

      // Make sure we can draw on this layer
      if (appModel.layers.selectedLayer.isVisible == false) {
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
      // Special case, one clik flood fill does not need to be tracked
      //
      if (appModel.selectedAction == ActionType.fill) {
        appModel.floodFillAction(adjustedPosition);
        return;
      }

      appModel.recordExecuteDrawingActionToSelectedLayer(
        action: UserActionDrawing(
          action: appModel.selectedAction,
          positions: <ui.Offset>[adjustedPosition, adjustedPosition],
          brush: MyBrush(
            color: appModel.brushColor,
            size: appModel.brusSize,
            style: appModel.brushStyle,
          ),
          fillColor: appModel.fillColor,
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
    final AppProvider appModel,
    final PointerEvent event,
  ) {
    //
    // Translate the input position to the canvas position and scale
    //
    final Offset adjustedPosition = appModel.toCanvas(event.localPosition);

    // debugPrint('DRAW MOVE ${details.buttons} P:${details.pointer}');

    if (event.buttons == 1 && _activePointerId == event.pointer) {
      // Update the Selector
      if (appModel.selectedAction == ActionType.selector) {
        appModel.selectorCreationAdditionalPoint(adjustedPosition);
        return;
      }

      if (appModel.selectedAction == ActionType.fill) {
        // ignore fill movement, flood fill is performed on the PointerStart event
        return;
      }

      if (appModel.selectedAction == ActionType.pencil) {
        // Add the pixel
        appModel.appendLineFromLastUserAction(adjustedPosition);
      } else if (appModel.selectedAction == ActionType.eraser) {
        // Eraser implementation
        appModel.appendLineFromLastUserAction(adjustedPosition);
      } else if (appModel.selectedAction == ActionType.brush) {
        // Cumulate more points in the draw path on the selected layer
        appModel.layers.selectedLayer
            .lastActionAppendPosition(position: adjustedPosition);
        appModel.update();
      } else {
        // Existing shape logic
        appModel.updateAction(end: adjustedPosition);
        appModel.update();
      }
    }
  }

  /// Handles the end of a pointer event.
  ///
  /// This method is called when a pointer that was previously in contact
  /// with the screen is lifted off. It is typically used to finalize any
  /// interactions that were started during the pointer down or move events.
  void _handlePointerEnd(
    final AppProvider appModel,
    final PointerEvent event,
  ) async {
    // debugPrint('UP ${details.buttons}');

    if (_activePointerId == event.pointer) {
      if (appModel.selectedAction == ActionType.selector) {
        appModel.selectorCreationEnd();
      }
      _activePointerId = -1;
      appModel.update();
    }
  }

  /// Centers the canvas within the view.
  ///
  /// This method adjusts the position of the canvas so that it is centered
  /// within the available space. It ensures that the canvas is properly
  /// aligned and visible to the user.
  void canvasCenterAndFit({
    required final AppProvider appProvider,
    required final double containerWidth,
    required final double containerHeight,
    required final bool scaleToContainer,
    required final bool notifyListener,
  }) {
    double adjustedScale = appProvider.layers.scale;
    if (scaleToContainer) {
      final double scaleX = containerWidth / appProvider.layers.width;
      final double scaleY = containerHeight / appProvider.layers.height;
      adjustedScale = (min(scaleX, scaleY) * 10).floor() / 10;
    }

    final double scaledWidth = (appProvider.layers.width * adjustedScale);
    final double scaledHeight = (appProvider.layers.height * adjustedScale);

    final double centerX = containerWidth / 2;
    final double centerY = containerHeight / 2;

    appProvider.offset = Offset(
      centerX - (scaledWidth / 2),
      centerY - (scaledHeight / 2),
    );
    appProvider.layers.scale = adjustedScale;
  }
}
