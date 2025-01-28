import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/panels/canvas_panel.dart';
import 'package:fpaint/panels/side_panel.dart';

import 'models/app_model.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(final BuildContext context) {
    // Ensure that AppModel is provided above this widget in the widget tree and listening
    final AppModel appModel = AppModel.get(context, listen: true);
    final ScrollController scrollControllerX = ScrollController();
    final ScrollController scrollControllerY = ScrollController();

    return Scaffold(
      backgroundColor: Colors.grey,
      body: Row(
        children: [
          // Left side panels
          const SidePanel(),
          // Canvas on the right
          Expanded(
            child: Center(
              child: Listener(
                // Pinch/Zoom scaling for WEB
                onPointerSignal: (final PointerSignalEvent event) {
                  if (event is PointerScaleEvent) {
                    appModel.scale = appModel.scale * event.scale;
                  }
                },
                // Pinch/Zoom scaling for Desktop
                onPointerPanZoomUpdate: (final event) {
                  appModel.scale = appModel.scale * event.scale;
                },

                // Draw Start
                onPointerDown: (PointerDownEvent details) {
                  if (appModel.userActionStartingOffset == null) {
                    double scrollOffsetX = scrollControllerX.offset;
                    double scrollOffsetY = scrollControllerY.offset;
                    Offset adjustedPosition = details.localPosition +
                        Offset(scrollOffsetX, scrollOffsetY);
                    _onUserActionStart(
                      context,
                      adjustedPosition / appModel.scale,
                    );
                  }
                },
                // Draw Update
                onPointerMove: (PointerEvent details) {
                  if (details is PointerMoveEvent) {
                    if (details.buttons == kPrimaryButton &&
                        appModel.userActionStartingOffset != null) {
                      double scrollOffsetX = scrollControllerX.offset;
                      double scrollOffsetY = scrollControllerY.offset;
                      Offset adjustedPosition = details.localPosition +
                          Offset(scrollOffsetX, scrollOffsetY);
                      _onUserActionUpdate(
                        appModel,
                        adjustedPosition / appModel.scale,
                      );
                    }
                  }
                },
                // Draw End
                onPointerUp: (PointerUpEvent details) {
                  _onUserActionEnded(appModel);
                },
                // Draw End
                onPointerCancel: (PointerCancelEvent details) {
                  _onUserActionEnded(appModel);
                },

                //
                // Render canvas
                //
                child: SingleChildScrollView(
                  controller: scrollControllerY,
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    controller: scrollControllerX,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: appModel.width,
                      height: appModel.height,
                      child: CanvasPanel(appModel: appModel),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // Undo/Redo
      floatingActionButton: floatingActionButtons(appModel),
    );
  }

  void _onUserActionStart(final BuildContext context, Offset position) {
    final AppModel appModel = AppModel.get(context);

    appModel.userActionStartingOffset = position;

    appModel.currentUserAction = UserAction(
      positions: [position, position],
      tool: appModel.selectedTool,
      brushColor: appModel.brushColor,
      fillColor: appModel.fillColor,
      brushSize: appModel.brusSize,
      brushStyle: appModel.brushStyle,
    );

    appModel.addUserAction(action: appModel.currentUserAction);
  }

  void _onUserActionUpdate(AppModel appModel, Offset position) {
    if (appModel.userActionStartingOffset != null) {
      if (appModel.selectedTool == Tools.eraser) {
        // Eraser implementation
        appModel.addUserAction(
          start: appModel.userActionStartingOffset!,
          end: position,
          type: appModel.selectedTool,
          colorStroke: Colors.transparent,
          colorFill: Colors.transparent,
        );
        appModel.userActionStartingOffset = position;
      } else if (appModel.selectedTool == Tools.draw) {
        // Cumulate more points in the draw path onthe selected layer
        appModel.layers.list[appModel.selectedLayerIndex]
            .appendPositionToLastUserAction(position);
        appModel.update();
      } else {
        // Existing shape logic
        appModel.updateLastUserAction(position);
        appModel.update();
      }
    }
  }

  void _onUserActionEnded(
    AppModel appModel,
  ) {
    if (appModel.currentUserAction?.tool == Tools.draw) {
      // Optimize list of draw actions into a single path
    }

    appModel.currentUserAction = null;
    appModel.userActionStartingOffset = null;
    appModel.update();
  }

  /// Builds a column of floating action buttons for the paint application,
  /// including buttons for undo, redo, zoom in, zoom out,
  ///  and a button that displays the current zoom level and canvas size.
  Widget floatingActionButtons(AppModel paintModel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          backgroundColor: Colors.grey.shade800,
          foregroundColor: Colors.white,
          onPressed: () => paintModel.undo(),
          child: const Icon(Icons.undo),
        ),
        FloatingActionButton(
          backgroundColor: Colors.grey.shade800,
          foregroundColor: Colors.white,
          onPressed: () => paintModel.redo(),
          child: const Icon(Icons.redo),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          backgroundColor: Colors.grey.shade800,
          foregroundColor: Colors.white,
          onPressed: () => paintModel.scale += 0.10,
          child: const Icon(Icons.zoom_in),
        ),
        FloatingActionButton(
          backgroundColor: Colors.grey.shade800,
          foregroundColor: Colors.white,
          onPressed: () => paintModel.scale = 1,
          child: Text(
            '${(paintModel.scale * 100).toInt()}%\n${paintModel.canvasSize.width.toInt()}\n${paintModel.canvasSize.height.toInt()}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        FloatingActionButton(
          backgroundColor: Colors.grey.shade800,
          foregroundColor: Colors.white,
          onPressed: () => paintModel.scale -= 0.10,
          child: const Icon(Icons.zoom_out),
        ),
      ],
    );
  }
}
