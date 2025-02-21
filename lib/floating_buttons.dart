import 'package:flutter/material.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';

/// Builds a column of floating action buttons for the paint application,
/// including buttons for undo, redo, zoom in, zoom out,
///  and a button that displays the current zoom level and canvas size.
Widget floatingActionButtons(
  final ShellProvider shellProvider,
  final AppProvider appProvider,
) {
  final FloatingActionButton undoButton = FloatingActionButton(
    backgroundColor: Colors.grey.shade600,
    foregroundColor: Colors.white,
    tooltip: appProvider.undoProvider.getHistoryStringForUndo(),
    onPressed: () {
      Future<void>.microtask(() => appProvider.undoAction());
    },
    child: const Icon(Icons.undo),
  );

  final FloatingActionButton redo = FloatingActionButton(
    backgroundColor: Colors.grey.shade600,
    foregroundColor: Colors.white,
    tooltip: appProvider.undoProvider.getHistoryStringForRedo(),
    onPressed: () {
      Future<void>.microtask(() => appProvider.redoAction());
    },
    child: const Icon(Icons.redo),
  );

  Color colorBackground = Colors.grey.shade600;
  final Color colorForegound = Colors.white;
  if (shellProvider.deviceSizeSmall) {
    if (appProvider.showMenu) {
      colorBackground = Colors.blue;
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 5,
      children: <Widget>[
        if (!appProvider.showMenu) undoButton,
        if (!appProvider.showMenu) redo,
        FloatingActionButton(
          backgroundColor: colorBackground,
          foregroundColor: colorForegound,
          tooltip: 'Menu',
          onPressed: () {
            shellProvider.showMenu = !shellProvider.showMenu;
            shellProvider.isSidePanelExpanded = true;
          },
          child: Icon(
            appProvider.showMenu
                ? Icons.double_arrow_rounded
                : Icons.more_vert_outlined,
          ),
        ),
      ],
    );
  }

  return Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: <Widget>[
      undoButton,
      redo,
      const SizedBox(height: 8),
      // Zooom in
      FloatingActionButton(
        backgroundColor: colorBackground,
        foregroundColor: colorForegound,
        onPressed: () {
          appProvider.layers.scale =
              ((appProvider.layers.scale * 10).ceil() + 1) / 10;
          appProvider.update();
        },
        child: const Icon(Icons.zoom_in),
      ),

      /// Center and fit image
      FloatingActionButton(
        backgroundColor: colorBackground,
        foregroundColor: colorForegound,
        onPressed: () {
          shellProvider.canvasPlacement = CanvasAutoPlacement.fit;
          appProvider.update();
        },
        child: Text(
          '${(appProvider.layers.scale * 100).toInt()}%\n${appProvider.layers.size.width.toInt()}\n${appProvider.layers.size.height.toInt()}',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: colorForegound,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),

      /// Zoom out
      FloatingActionButton(
        backgroundColor: colorBackground,
        foregroundColor: colorForegound,
        onPressed: () {
          appProvider.layers.scale =
              ((appProvider.layers.scale * 10).floor() - 1) / 10;
          appProvider.update();
        },
        child: const Icon(Icons.zoom_out),
      ),
    ],
  );
}
