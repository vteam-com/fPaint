import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/panels/canvas_panel.dart';
import 'package:fpaint/panels/layers_panel.dart';
import 'package:fpaint/panels/tools_panel.dart';

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
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: appModel.isSidePanelExpanded ? 360 : 64,
            child: sidePanel(context),
          ),
          // Canvas on the righ
          Expanded(
            child: Center(
              child: Listener(
                onPointerSignal: (final PointerSignalEvent event) {
                  if (event is PointerScaleEvent) {
                    appModel.scale = appModel.scale * event.scale;
                  }
                },
                onPointerPanZoomUpdate: (final event) {
                  appModel.scale = appModel.scale * event.scale;
                },
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
                onPointerUp: (PointerUpEvent details) {
                  appModel.userActionStartingOffset = null;
                },
                onPointerCancel: (PointerCancelEvent details) {
                  appModel.userActionStartingOffset = null;
                },
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

  Widget sidePanel(final BuildContext context) {
    final appModel = AppModel.get(context);
    return Container(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8),
      child: Material(
        elevation: 18,
        color: Colors.grey.shade200,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        clipBehavior: Clip.none,
        child: Column(
          children: [
            //
            // Layers Panel
            //
            Expanded(
              child: LayersPanel(
                selectedLayerIndex: appModel.selectedLayerIndex,
                onSelectLayer: (final int layerIndex) =>
                    appModel.selectedLayerIndex = layerIndex,
                onAddLayer: () => _onAddLayer(context),
                onFileOpen: () => _onFileOpen(context),
                onRemoveLayer: (final int indexToRemove) =>
                    AppModel.get(context).removeLayer(indexToRemove),
                onToggleViewLayer: (indexToToggle) =>
                    AppModel.get(context).toggleLayerVisibility(indexToToggle),
              ),
            ),
            //
            // Divider
            //
            Divider(
              thickness: 8,
              height: 16,
              color: Colors.grey,
            ),

            //
            // Tools Panel
            //
            Expanded(
              child: ToolsPanel(
                currentShapeType: appModel.selectedTool,
                onShapeSelected: (final Tools tool) =>
                    appModel.selectedTool = tool,
                minimal: !appModel.isSidePanelExpanded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Method to add a new layer
  void _onAddLayer(final BuildContext context) {
    final AppModel appModel = AppModel.get(context);
    final Layer newLayer = appModel.addLayerTop();

    appModel.selectedLayerIndex = appModel.layers.getLayerIndex(newLayer);
  }

  void _onFileOpen(final BuildContext context) async {
    final AppModel appModel = AppModel.get(context);

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );

      if (result != null) {
        appModel.layers.clear();

        if (kIsWeb) {
          await readOraFileFromBytes(appModel, result.files.single.bytes!);
        } else {
          await readOraFile(appModel, result.files.single.path!);
        }
      }
    } catch (e) {
      // Handle any errors that occur during file picking/loading
      print('Error opening file: $e');
    }
  }

  void _onUserActionStart(final BuildContext context, Offset position) {
    final AppModel appModel = AppModel.get(context);

    appModel.userActionStartingOffset = position;

    if (appModel.selectedTool != Tools.draw) {
      appModel.currentUserAction = UserAction(
        start: position,
        end: position,
        type: appModel.selectedTool,
        colorOutline: appModel.colorForStroke,
        colorFill: appModel.colorForFill,
        brushSize: appModel.lineWeight,
        brushStyle: appModel.brush,
      );

      appModel.addShape(shape: appModel.currentUserAction);
    }
  }

  void _onUserActionUpdate(AppModel appModel, Offset position) {
    if (appModel.userActionStartingOffset != null) {
      if (appModel.selectedTool == Tools.eraser) {
        // Eraser implementation
        appModel.addShape(
          start: appModel.userActionStartingOffset!,
          end: position,
          type: appModel.selectedTool,
          colorStroke: Colors.transparent,
          colorFill: Colors.transparent,
        );
        appModel.userActionStartingOffset = position;
      } else if (appModel.selectedTool == Tools.draw) {
        // Existing pencil logic
        appModel.addShape(
          start: appModel.userActionStartingOffset!,
          end: position,
          type: appModel.selectedTool,
          colorFill: appModel.colorForFill,
          colorStroke: appModel.colorForStroke,
        );
        appModel.userActionStartingOffset = position;
      } else {
        // Existing shape logic
        appModel.updateLastShape(position);
      }
    }
  }

  /// Builds a column of floating action buttons for the paint application,
  /// including buttons for undo, redo, zoom in, zoom out,
  ///  and a button that displays the current zoom level and canvas size.
  Widget floatingActionButtons(AppModel paintModel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.grey.shade700,
          onPressed: () => paintModel.undo(),
          child: Icon(Icons.undo),
        ),
        FloatingActionButton(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.grey.shade700,
          onPressed: () => paintModel.redo(),
          child: Icon(Icons.redo),
        ),
        SizedBox(height: 8),
        FloatingActionButton(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.grey.shade700,
          onPressed: () => paintModel.scale += 0.10,
          child: Icon(Icons.zoom_in),
        ),
        FloatingActionButton(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.grey.shade700,
          onPressed: () => paintModel.scale = 1,
          child: Text(
            '${(paintModel.scale * 100).toInt()}%\n${paintModel.canvasSize.width.toInt()}\n${paintModel.canvasSize.height.toInt()}',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        FloatingActionButton(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.grey.shade700,
          onPressed: () => paintModel.scale -= 0.10,
          child: Icon(Icons.zoom_out),
        ),
      ],
    );
  }
}
