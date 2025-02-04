import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/panels/canvas_panel.dart';
import 'package:fpaint/panels/side_panel.dart';
import 'package:fpaint/panels/tools/flood_fill.dart';

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
                onPointerDown: (final PointerDownEvent details) async {
                  if (appModel.isCurrentSelectionReadyForAction) {
                    if (appModel.userActionStartingOffset == null) {
                      final double scrollOffsetX = scrollControllerX.offset;
                      final double scrollOffsetY = scrollControllerY.offset;
                      final Offset adjustedPosition = details.localPosition +
                          Offset(scrollOffsetX, scrollOffsetY);
                      await _onUserActionStart(
                        appModel: appModel,
                        position: adjustedPosition / appModel.scale,
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Selection is hidden.'),
                      ),
                    );
                  }
                },
                // Draw Update
                onPointerMove: (final PointerEvent details) {
                  if (details is PointerMoveEvent) {
                    if (details.buttons == kPrimaryButton &&
                        appModel.userActionStartingOffset != null) {
                      final double scrollOffsetX = scrollControllerX.offset;
                      final double scrollOffsetY = scrollControllerY.offset;
                      final Offset adjustedPosition = details.localPosition +
                          Offset(scrollOffsetX, scrollOffsetY);
                      _onUserActionUpdate(
                        appModel: appModel,
                        position: adjustedPosition / appModel.scale,
                      );
                    }
                  }
                },
                // Draw End
                onPointerUp: (final PointerUpEvent details) {
                  _onUserActionEnded(appModel);
                },
                // Draw End
                onPointerCancel: (final PointerCancelEvent details) {
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

  Future<void> _onUserActionStart({
    required final AppModel appModel,
    required final Offset position,
  }) async {
    appModel.userActionStartingOffset = position;
    if (appModel.selectedTool == Tools.fill) {
      // Create a flattened image from the current layer
      final ui.Image img =
          await appModel.selectedLayer.toImageForStorage(appModel.canvasSize);

      // Perform flood fill at the clicked position
      final ui.Image filledImage = await applyFloodFill(
        image: img,
        x: position.dx.toInt(),
        y: position.dy.toInt(),
        newColor: appModel.fillColor,
        tolerance: appModel.tolerance,
      );
      appModel.selectedLayer
          .addImage(imageToAdd: filledImage, tool: Tools.fill);
      appModel.update();
    } else {
      appModel.currentUserAction = UserAction(
        tool: appModel.selectedTool,
        positions: [position, position],
        brushColor: appModel.brushColor,
        fillColor: appModel.fillColor,
        brushSize: appModel.brusSize,
        brushStyle: appModel.brushStyle,
      );

      appModel.addUserAction(action: appModel.currentUserAction!);
    }
  }

  void _onUserActionUpdate({
    required final AppModel appModel,
    required final Offset position,
  }) {
    if (appModel.userActionStartingOffset != null) {
      if (appModel.selectedTool == Tools.eraser) {
        // Eraser implementation
        appModel.updateLastUserAction(
          start: appModel.userActionStartingOffset!,
          end: position,
          type: appModel.selectedTool,
          colorStroke: Colors.transparent,
          colorFill: Colors.transparent,
        );
        appModel.userActionStartingOffset = position;
      } else if (appModel.selectedTool == Tools.draw) {
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
  Widget floatingActionButtons(final AppModel appModel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          backgroundColor: Colors.grey.shade800,
          foregroundColor: Colors.white,
          tooltip:
              'Undo\n---------------\n${appModel.selectedLayer.actionHistory(20).join('\n')}',
          onPressed: () => appModel.undo(),
          child: const Icon(Icons.undo),
        ),
        FloatingActionButton(
          backgroundColor: Colors.grey.shade800,
          foregroundColor: Colors.white,
          onPressed: () => appModel.redo(),
          child: const Icon(Icons.redo),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          backgroundColor: Colors.grey.shade800,
          foregroundColor: Colors.white,
          onPressed: () => appModel.scale += 0.10,
          child: const Icon(Icons.zoom_in),
        ),
        FloatingActionButton(
          backgroundColor: Colors.grey.shade800,
          foregroundColor: Colors.white,
          onPressed: () => appModel.scale = 1,
          child: Text(
            '${(appModel.scale * 100).toInt()}%\n${appModel.canvasSize.width.toInt()}\n${appModel.canvasSize.height.toInt()}',
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
          onPressed: () => appModel.scale -= 0.10,
          child: const Icon(Icons.zoom_out),
        ),
      ],
    );
  }
}
