import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';

/// Builds a column of floating action buttons for the paint application,
/// including buttons for undo, redo, zoom in, zoom out,
///  and a button that displays the current zoom level and canvas size.
Widget floatingActionButtons(final AppModel appModel) {
  Color colorBackground = Colors.grey.shade600;
  Color colorForegound = Colors.white;
  if (appModel.deviceSizeSmall) {
    if (appModel.showMenu) {
      colorBackground = Colors.blue;
    }
    return FloatingActionButton(
      backgroundColor: colorBackground,
      foregroundColor: colorForegound,
      tooltip: 'Menu',
      onPressed: () {
        appModel.showMenu = !appModel.showMenu;
        appModel.isSidePanelExpanded = !appModel.isSidePanelExpanded;
      },
      child: Icon(
        appModel.showMenu
            ? Icons.double_arrow_rounded
            : Icons.more_vert_outlined,
      ),
    );
  }

  return Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      FloatingActionButton(
        backgroundColor: colorBackground,
        foregroundColor: colorForegound,
        tooltip:
            'Undo\n---------------\n${appModel.selectedLayer.actionHistory(20).join('\n')}',
        onPressed: () => appModel.undo(),
        child: const Icon(Icons.undo),
      ),
      FloatingActionButton(
        backgroundColor: colorBackground,
        foregroundColor: colorForegound,
        onPressed: () => appModel.redo(),
        child: const Icon(Icons.redo),
      ),
      const SizedBox(height: 8),
      FloatingActionButton(
        backgroundColor: colorBackground,
        foregroundColor: colorForegound,
        onPressed: () => appModel
            .setCanvasScale(((appModel.canvas.scale * 10).ceil() + 1) / 10),
        child: const Icon(Icons.zoom_in),
      ),
      FloatingActionButton(
        backgroundColor: colorBackground,
        foregroundColor: colorForegound,
        onPressed: () => appModel.resetCanvasSizeAndPlacement(),
        child: Text(
          '${(appModel.canvas.scale * 100).toInt()}%\n${appModel.canvas.canvasSize.width.toInt()}\n${appModel.canvas.canvasSize.height.toInt()}',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: colorForegound,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
      FloatingActionButton(
        backgroundColor: colorBackground,
        foregroundColor: colorForegound,
        onPressed: () => appModel
            .setCanvasScale(((appModel.canvas.scale * 10).floor() - 1) / 10),
        child: const Icon(Icons.zoom_out),
      ),
    ],
  );
}
