import 'package:flutter/material.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';

/// Builds a column of floating action buttons for the paint application,
/// including buttons for undo, redo, zoom in, zoom out,
///  and a button that displays the current zoom level and canvas size.
Widget floatingActionButtons(
  final ShellProvider shellModel,
  final AppProvider appModel,
) {
  final undoButton = FloatingActionButton(
    backgroundColor: Colors.grey.shade600,
    foregroundColor: Colors.white,
    tooltip: appModel.layers.selectedLayer.getHistoryStringForUndo(),
    onPressed: () => appModel.layersUndo(),
    child: const Icon(Icons.undo),
  );

  final redo = FloatingActionButton(
    backgroundColor: Colors.grey.shade600,
    foregroundColor: Colors.white,
    tooltip: appModel.layers.selectedLayer.getHistoryStringForRedo(),
    onPressed: () => appModel.layersRedo(),
    child: const Icon(Icons.redo),
  );

  Color colorBackground = Colors.grey.shade600;
  Color colorForegound = Colors.white;
  if (shellModel.deviceSizeSmall) {
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
            shellModel.showMenu = !shellModel.showMenu;
            shellModel.isSidePanelExpanded = true;
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
        onPressed: () {
          shellModel.centerImageInViewPort = true;
          appModel
              .canvasSetScale(((appModel.layers.scale * 10).ceil() + 1) / 10);
        },
        child: const Icon(Icons.zoom_in),
      ),
      FloatingActionButton(
        backgroundColor: colorBackground,
        foregroundColor: colorForegound,
        onPressed: () => appModel.resetView(),
        child: Text(
          '${(appModel.layers.scale * 100).toInt()}%\n${appModel.layers.size.width.toInt()}\n${appModel.layers.size.height.toInt()}',
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
        onPressed: () {
          shellModel.centerImageInViewPort = true;
          appModel
              .canvasSetScale(((appModel.layers.scale * 10).floor() - 1) / 10);
        },
        child: const Icon(Icons.zoom_out),
      ),
    ],
  );
}
