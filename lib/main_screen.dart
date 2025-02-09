import 'package:flutter/material.dart';
import 'package:fpaint/panels/side_panel.dart';
import 'package:fpaint/widgets/canvas_widget.dart';
import 'package:multi_split_view/multi_split_view.dart';

import 'models/app_model.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});
  final double minSidePanelSize = 100.0;

  @override
  Widget build(final BuildContext context) {
    // Ensure that AppModel is provided above this widget in the widget tree and listening
    final AppModel appModel = AppModel.of(context, listen: true);

    return Scaffold(
      backgroundColor: Colors.grey,
      body: MultiSplitView(
        key: Key('key_side_panel_size_${appModel.isSidePanelExpanded}'),
        axis: Axis.horizontal,
        initialAreas: [
          Area(
            size: appModel.isSidePanelExpanded ? 400 : minSidePanelSize,
            min: appModel.isSidePanelExpanded ? 350 : minSidePanelSize,
            max: appModel.isSidePanelExpanded ? 600 : minSidePanelSize,
            builder: (context, area) => const SidePanel(),
          ),
          Area(
            builder: (context, area) => CanvasWidget(
              canvasWidth: appModel.canvas.width,
              canvasHeight: appModel.canvas.height,
            ),
          ),
        ],
      ),
      // Undo/Redo
      floatingActionButton: floatingActionButtons(appModel),
    );
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
          onPressed: () => appModel
              .setCanvasScale(((appModel.canvas.scale * 10).ceil() + 1) / 10),
          child: const Icon(Icons.zoom_in),
        ),
        FloatingActionButton(
          backgroundColor: Colors.grey.shade800,
          foregroundColor: Colors.white,
          onPressed: () => appModel.resetCanvasSizeAndPlacement(),
          child: Text(
            '${(appModel.canvas.scale * 100).toInt()}%\n${appModel.canvas.canvasSize.width.toInt()}\n${appModel.canvas.canvasSize.height.toInt()}',
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
          onPressed: () => appModel
              .setCanvasScale(((appModel.canvas.scale * 10).floor() - 1) / 10),
          child: const Icon(Icons.zoom_out),
        ),
      ],
    );
  }
}
