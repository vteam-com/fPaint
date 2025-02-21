import 'package:flutter/material.dart';
import 'package:fpaint/models/constants.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';

/// Builds a column of floating action buttons for the paint application,
/// including buttons for undo, redo, zoom in, zoom out,
///  and a button that displays the current zoom level and canvas size.
Widget floatingActionButtons(
  final ShellProvider shellProvider,
  final AppProvider appProvider,
) {
  final Widget undoButton = myFloatButton(
    icon: Icons.undo,
    tooltip: appProvider.undoProvider.getHistoryStringForUndo(),
    onPressed: () {
      Future<void>.microtask(() => appProvider.undoAction());
    },
  );

  final Widget redo = myFloatButton(
    icon: Icons.redo,
    tooltip: appProvider.undoProvider.getHistoryStringForRedo(),
    onPressed: () {
      Future<void>.microtask(() => appProvider.redoAction());
    },
  );

  if (shellProvider.deviceSizeSmall) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 5,
      children: <Widget>[
        if (!shellProvider.showMenu) undoButton,
        if (!shellProvider.showMenu) redo,
        myFloatButton(
          icon: shellProvider.showMenu ? Icons.close : Icons.more_vert_outlined,
          onPressed: () {
            shellProvider.showMenu = !shellProvider.showMenu;
          },
        ),
      ],
    );
  }

  return Column(
    mainAxisAlignment: MainAxisAlignment.end,
    spacing: 4,
    children: <Widget>[
      undoButton,
      redo,

      // Zooom in
      myFloatButton(
        icon: Icons.zoom_in,
        onPressed: () {
          appProvider.layers.scale =
              ((appProvider.layers.scale * 10).ceil() + 1) / 10;
          appProvider.update();
        },
      ),

      /// Center and fit image
      myFloatButton(
        onPressed: () {
          shellProvider.canvasPlacement = CanvasAutoPlacement.fit;
          appProvider.update();
        },
        child: Text(
          '${(appProvider.layers.scale * 100).toInt()}%\n${appProvider.layers.size.width.toInt()}\n${appProvider.layers.size.height.toInt()}',
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),

      /// Zoom out
      myFloatButton(
        icon: Icons.zoom_out,
        onPressed: () {
          appProvider.layers.scale =
              ((appProvider.layers.scale * 10).floor() - 1) / 10;
          appProvider.update();
        },
      ),
      myFloatButton(
        icon: Icons.arrow_drop_down,
        onPressed: () {
          shellProvider.shellMode = ShellMode.hidden;
          shellProvider.update();
        },
      ),
    ],
  );
}

Widget myFloatButton({
  final IconData? icon,
  final String? tooltip,
  required final void Function() onPressed,
  final Widget? child,
}) {
  return FloatingActionButton(
    backgroundColor: AppColors.colorFloatButtonBackground,
    foregroundColor: Colors.white,
    tooltip: tooltip,
    onPressed: () {
      Future<void>.microtask(() => onPressed());
    },
    child: child ?? Icon(icon!),
  );
}
