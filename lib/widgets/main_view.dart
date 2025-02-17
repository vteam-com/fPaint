import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';
import 'package:fpaint/panels/canvas_panel.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/selector_widget.dart';

/// The `MainView` widget is a stateful widget that represents the main view of the application.
/// It handles user interactions such as panning, zooming, and drawing on the canvas.
///
/// The `MainViewState` class manages the state of the `MainView` widget. It includes methods
/// for handling pointer events, centering the canvas, and updating the application model.
///
/// Methods:
/// - `build`: Builds the widget tree for the main view.
/// - `_handlePointerStart`: Handles the start of a pointer event (e.g., touch down).
/// - `_handlePointerMove`: Handles the movement of a pointer event (e.g., touch move).
/// - `_handPointerEnd`: Handles the end of a pointer event (e.g., touch up).
/// - `centerCanvas`: Centers the canvas within the viewport.
///
/// The widget tree includes a `Listener` widget to capture pointer events and a `Stack` widget
/// to overlay the canvas and selection handles. The canvas is transformed based on the current
/// offset and scale from the application model.
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

  @override
  Widget build(BuildContext context) {
    const double scaleTolerance = 0.2;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // print('LayoutBuilder ${constraints.maxWidth} ${constraints.maxHeight}');
        final ShellProvider shellModel = ShellProvider.of(context);
        final AppProvider appModel = AppProvider.of(context, listen: true);

        // Center canvas if requested
        if (shellModel.centerImageInViewPort ||
            lastViewPortSize.width != constraints.maxWidth ||
            lastViewPortSize.height != constraints.maxHeight) {
          lastViewPortSize = Size(constraints.maxWidth, constraints.maxHeight);
          // print(
          //   'Center ${constraints.maxWidth} ${constraints.maxHeight}',
          // );
          shellModel.centerImageInViewPort = false;
          centerCanvas(
            AppProvider.of(context),
            constraints.maxWidth,
            constraints.maxHeight,
          );
        }

        return Listener(
          onPointerSignal: (PointerSignalEvent event) {
            // Needed for WEB PANNING
            if (event is PointerScrollEvent) {
              appModel.offset +=
                  Offset(-event.scrollDelta.dx, -event.scrollDelta.dy);
              appModel.update();
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
                    appModel.offset += event.panDelta;
                    appModel.update();
                  } else {
                    // Scaling
                    _handleScaling(
                      appModel,
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
              _handlePointerStart(appModel, event);
            }
          },

          //
          // Pointer MOVE
          //
          onPointerMove: (final PointerEvent event) {
            if (event.kind == PointerDeviceKind.touch) {
              // ignore touch when drawing, must use the stylus
            } else {
              _handlePointerMove(appModel, event);
            }
          },

          //
          // Pointer UP/CANCEL/END
          //
          onPointerUp: (PointerUpEvent event) {
            if (event.kind == PointerDeviceKind.touch) {
              // ignore touch when drawing, must use the stylus
            } else {
              _handPointerEnd(appModel, event);
            }
          },

          onPointerCancel: (final PointerCancelEvent event) {
            if (event.kind == PointerDeviceKind.touch) {
              // ignore touch when drawing, must use the stylus
            } else {
              _handPointerEnd(appModel, event);
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
                // print('GestureDetector onScaleUpdate');
                double scaleAttempt = (details.scale - 1.0).abs();
                // print('${details.scale} $scaleAttempt');
                if (scaleAttempt < scaleTolerance) {
                  // No scaling, apply panning if using 2 fingers
                  if (details.pointerCount == 2) {
                    appModel.offset += details.focalPointDelta;
                    appModel.update();
                  }
                } else {
                  // Handle zooming/scaling
                  _handleScaling(
                    appModel,
                    details.localFocalPoint,
                    details.scale,
                  );
                }
              }
            },
            child: _displayCanvasAnSelector(appModel),
          ),
        );
      },
    );
  }

  Widget _displayCanvasAnSelector(final AppProvider appProvider) {
    return Stack(
      children: [
        Transform(
          alignment: Alignment.topLeft,
          transform: Matrix4.identity()
            ..translate(
              appProvider.offset.dx,
              appProvider.offset.dy,
            )
            ..scale(appProvider.layers.scale),
          child: const CanvasPanel(),
        ),

        //
        // Selection Widget
        //
        if (appProvider.selector.isVisible)
          SelectionHandleWidget(
            path: appProvider.getPathAdjustToCanvasSizeAndPosition(),
            enableMoveAndResize:
                appProvider.selectedAction == ActionType.selector,
            onDrag: (Offset offset) {
              appProvider.selector.translate(offset);
              appProvider.update();
            },
            onResize: (NineGridHandle handle, Offset offset) {
              appProvider.selector.nindeGridResize(handle, offset);
              appProvider.update();
            },
          ),
      ],
    );
  }

  void _handleScaling(
    final AppProvider appModel,
    final Offset anchorPoint,
    final double scaleDelta,
  ) {
    // Handle zooming/scaling

    // Step 1: Convert screen coordinates to canvas coordinates
    final Offset before = appModel.toCanvas(anchorPoint);

    // Step 2: Apply the scale change
    final double scaleDeltaResult = scaleDelta > 1 ? 1.01 : 0.99;
    appModel.layers.scale *= scaleDeltaResult;

    // Step 3: Calculate the new position on the canvas
    final Offset after = appModel.toCanvas(anchorPoint);

    // Step 4: Adjust the offset to keep the cursor anchored
    // No need to multiply by scale
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
        appModel.selectorStart(adjustedPosition);
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
        action: UserAction(
          action: appModel.selectedAction,
          positions: [adjustedPosition, adjustedPosition],
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
        appModel.selectorMove(adjustedPosition);
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
        appModel.selectorEnd();
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
  void centerCanvas(
    final AppProvider appModel,
    final double parentViewPortWidth,
    final double parentViewPortHeight,
  ) {
    final double scaledWidth = appModel.layers.width * appModel.layers.scale;
    final double scaledHeight = appModel.layers.height * appModel.layers.scale;

    final double centerX = parentViewPortWidth / 2;
    final double centerY = parentViewPortHeight / 2;

    appModel.offset = Offset(
      centerX - (scaledWidth / 2),
      centerY - (scaledHeight / 2),
    );
  }
}
