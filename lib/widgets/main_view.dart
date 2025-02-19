import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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
  final double scaleTolerance = 0.01;

  @override
  Widget build(final BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context, listen: true);
    return Stack(
      children: <Widget>[
        LayoutBuilder(
          builder:
              (final BuildContext context, final BoxConstraints constraints) {
            // print('LayoutBuilder ${constraints.maxWidth} ${constraints.maxHeight}');
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
                // Needed for WEB PANNING
                if (event is PointerScrollEvent) {
                  appProvider.offset +=
                      Offset(-event.scrollDelta.dx, -event.scrollDelta.dy);
                  appProvider.update();
                }
              },
              //
              // PAN and SCALE for Web, Linux & Windows
              // this is not invoked for Touch devices and we skip MacOS, since trackpad behavior are received the same way as Touch devices
              //
              onPointerPanZoomUpdate: !kIsWeb && Platform.isMacOS
                  ? null
                  : (final PointerPanZoomUpdateEvent event) {
                      // print('Listener onPointerPanZoomUpdate');
                      if (event.scale == 1) {
                        // Panning
                        appProvider.offset += event.panDelta;
                        appProvider.update();
                      } else {
                        // Scaling
                        _handleScaling(
                          appProvider,
                          event.localPosition,
                          event.scale,
                        );
                      }
                    },

              //
              // Pointer DOWN
              //
              onPointerDown: (final PointerDownEvent event) {
                if (event.kind == PointerDeviceKind.touch) {
                  // ignore touch when drawing, must use the stylus
                } else {
                  _handlePointerStart(appProvider, event);
                }
              },

              //
              // Pointer MOVE
              //
              onPointerMove: (final PointerEvent event) {
                if (event.kind == PointerDeviceKind.touch) {
                  // ignore touch when drawing, must use the stylus
                } else {
                  _handlePointerMove(appProvider, event);
                }
              },

              //
              // Pointer UP/CANCEL/END
              //
              onPointerUp: (final PointerUpEvent event) {
                if (event.kind == PointerDeviceKind.touch) {
                  // ignore touch when drawing, must use the stylus
                } else {
                  _handPointerEnd(appProvider, event);
                }
              },

              onPointerCancel: (final PointerCancelEvent event) {
                if (event.kind == PointerDeviceKind.touch) {
                  // ignore touch when drawing, must use the stylus
                } else {
                  _handPointerEnd(appProvider, event);
                }
              },

              //
              // Handle Touch Device Gesture iOS, Android, TouchScreen laptops
              //
              child: GestureDetector(
                // Handle two-fingers Panning and Scaling
                onScaleUpdate: (final ScaleUpdateDetails details) {
                  // supported by iOS, Android, macOS
                  if (!Platform.isLinux && !Platform.isWindows) {
                    final double scaleAttempt = (details.scale - 1.0).abs();
                    if (scaleAttempt < scaleTolerance) {
                      //
                      // PANNING
                      //
                      if (details.pointerCount == 2) {
                        appProvider.offset += details.focalPointDelta;
                        appProvider.update();
                      }
                    } else {
                      //
                      // SCALING
                      //
                      _handleScaling(
                        appProvider,
                        details.localFocalPoint,
                        details.scale,
                      );
                    }
                  }
                },
                child: _displayCanvas(appProvider),
              ),
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

  Widget _displayCanvas(final AppProvider appProvider) {
    return Transform(
      alignment: Alignment.topLeft,
      transform: Matrix4.identity()
        ..translate(
          appProvider.offset.dx,
          appProvider.offset.dy,
        )
        ..scale(appProvider.layers.scale),
      child: const CanvasPanel(),
    );
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

    appModel.update();
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

      appModel.addActionToSelectedLayer(
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
  void _handPointerEnd(
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
