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
        onPressed: () {
          shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
          appProvider.applyScaleToCanvas(
            scaleDelta: 1.10,
            anchorPoint: appProvider.canvasCenter,
          );
        },
        icon: Icons.zoom_in,
      ),

      /// Center and fit image
      myFloatButton(
        onPressed: () {
          shellProvider.canvasPlacement = CanvasAutoPlacement.fit;
          appProvider.update();
          // Its still unclear why but this is needed to update the canvas and the Selectors/Fill widget correctly
          Future<void>.delayed(const Duration(milliseconds: 100), () {
            appProvider.update();
          });
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
        onPressed: () {
          shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
          appProvider.applyScaleToCanvas(
            scaleDelta: 0.90,
            anchorPoint: appProvider.canvasCenter,
          );
        },
        icon: Icons.zoom_out,
      ),
      myFloatButton(
        onPressed: () {
          shellProvider.shellMode = ShellMode.hidden;
          shellProvider.update();
        },
        icon: Icons.arrow_drop_down,
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
    heroTag: null,
    backgroundColor: AppColors.colorFloatButtonBackground,
    foregroundColor: Colors.white,
    tooltip: tooltip,
    onPressed: () {
      Future<void>.microtask(() => onPressed());
    },
    child: child ?? Icon(icon!),
  );
}
