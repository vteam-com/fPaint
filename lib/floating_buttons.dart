import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';

/// Builds a column of floating action buttons for the paint application,
/// including buttons for undo, redo, zoom in, zoom out,
///  and a button that displays the current zoom level and canvas size.
Widget floatingActionButtons(final AppModel appModel) {
  final undoButton = FloatingActionButton(
    backgroundColor: Colors.grey.shade600,
    foregroundColor: Colors.white,
    tooltip: appModel.selectedLayer.actionHistory(20).join('\n'),
    onPressed: () => appModel.undo(),
    child: const Icon(Icons.undo),
  );

  final redo = FloatingActionButton(
    backgroundColor: Colors.grey.shade600,
    foregroundColor: Colors.white,
    onPressed: () => appModel.redo(),
    child: const Icon(Icons.redo),
  );

  Color colorBackground = Colors.grey.shade600;
  Color colorForegound = Colors.white;
  if (appModel.deviceSizeSmall) {
    if (appModel.showMenu) {
      colorBackground = Colors.blue;
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 5,
      children: [
        if (!appModel.showMenu) undoButton,
        if (!appModel.showMenu) redo,
        FloatingActionButton(
          backgroundColor: colorBackground,
          foregroundColor: colorForegound,
          tooltip: 'Menu',
          onPressed: () {
            appModel.showMenu = !appModel.showMenu;
            appModel.isSidePanelExpanded = true;
          },
          child: Icon(
            appModel.showMenu
                ? Icons.double_arrow_rounded
                : Icons.more_vert_outlined,
          ),
        ),
      ],
    );
  }

  return Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      undoButton,
      redo,
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
          '${(appModel.canvas.scale * 100).toInt()}%\n${appModel.canvas.size.width.toInt()}\n${appModel.canvas.size.height.toInt()}',
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
