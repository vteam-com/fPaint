import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';

const String _canvasZoomAndSizeFormat = '{zoom}%\n{width}\n{height}';
const String _placeholderZoom = '{zoom}';
const String _placeholderWidth = '{width}';
const String _placeholderHeight = '{height}';

/// Builds a column of floating action buttons for the paint application,
/// including buttons for undo, redo, zoom in, zoom out,
///  and a button that displays the current zoom level and canvas size.
///
/// The [context] parameter is the [BuildContext] used to access the application's providers.
/// The [shellProvider] parameter is the [ShellProvider] instance used to manage the application's shell.
/// The [appProvider] parameter is the [AppProvider] instance used to manage the application's state.
Widget floatingActionButtons(
  final BuildContext context,
  final ShellProvider shellProvider,
  final AppProvider appProvider,
) {
  final AppLocalizations l10n = context.l10n;

  final Widget undoButton = myFloatButton(
    icon: AppIcon.undo,
    tooltip: appProvider.undoProvider.getHistoryStringForUndo(),
    onPressed: () {
      Future<void>.microtask(() => appProvider.undoAction());
    },
  );

  final Widget redo = myFloatButton(
    icon: AppIcon.redo,
    tooltip: appProvider.undoProvider.getHistoryStringForRedo(),
    onPressed: () {
      Future<void>.microtask(() => appProvider.redoAction());
    },
  );

  if (shellProvider.deviceSizeSmall) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: AppSpacing.sm - AppStroke.thin,
      children: <Widget>[
        if (!shellProvider.showMenu)
          FloatingActionButton(
            heroTag: null,
            backgroundColor: AppColors.floatingButtonBackground,
            foregroundColor: Colors.white,
            tooltip: l10n.activeTool,
            onPressed: () {
              shellProvider.showMenu = !shellProvider.showMenu;
            },
            child: AppSvgIcon(icon: appProvider.selectedAction.icon, isSelected: false),
          ),
        if (!shellProvider.showMenu)
          myFloatButton(
            icon: AppIcon.colorLens,
            foregroundColor: appProvider.brushColor,
            tooltip: l10n.colorLabel,
            onPressed: () {
              showColorPicker(
                context: context,
                title: l10n.colorLabel,
                color: appProvider.brushColor,
                onSelectedColor: (final Color color) {
                  appProvider.brushColor = color;
                },
              );
            },
          ),
        if (!shellProvider.showMenu) undoButton,
        if (!shellProvider.showMenu) redo,
        if (shellProvider.showMenu)
          myFloatButton(
            icon: AppIcon.close,
            onPressed: () {
              shellProvider.showMenu = !shellProvider.showMenu;
            },
          ),
      ],
    );
  }

  return Column(
    mainAxisAlignment: MainAxisAlignment.end,
    spacing: AppSpacing.xs,
    children: <Widget>[
      undoButton,
      redo,

      // Zoom in
      myFloatButton(
        key: Keys.floatActionZoomIn,
        onPressed: () {
          shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
          appProvider.applyScaleToCanvas(
            scaleDelta: AppVisual.enlarge,
            anchorPoint: appProvider.canvasCenter,
          );
        },
        icon: AppIcon.zoomIn,
      ),

      /// Center and fit image
      myFloatButton(
        key: Keys.floatActionCenter,
        onPressed: () {
          shellProvider.canvasPlacement = CanvasAutoPlacement.fit;
          appProvider.update();
          // Its still unclear why but this is needed to update the canvas and the Selectors/Fill widget correctly
          Future<void>.delayed(const Duration(milliseconds: AppLimits.percentMax), () {
            appProvider.update();
          });
        },
        child: Text(
          _canvasZoomAndSizeFormat
              .replaceFirst(_placeholderZoom, (appProvider.layers.scale * AppLimits.percentMax).toInt().toString())
              .replaceFirst(_placeholderWidth, appProvider.layers.size.width.toInt().toString())
              .replaceFirst(_placeholderHeight, appProvider.layers.size.height.toInt().toString()),
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: AppColors.floatingButtonForeground,
            fontWeight: FontWeight.bold,
            fontSize: AppSpacing.lg,
          ),
        ),
      ),

      /// Zoom out
      myFloatButton(
        key: Keys.floatActionZoomOut,
        onPressed: () {
          shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
          appProvider.applyScaleToCanvas(
            scaleDelta: AppVisual.shrink,
            anchorPoint: appProvider.canvasCenter,
          );
        },
        icon: AppIcon.zoomOut,
      ),

      /// Show/Hide floating action panel
      myFloatButton(
        key: Keys.floatActionToggle,
        onPressed: () {
          shellProvider.shellMode = ShellMode.hidden;
          shellProvider.update();
        },
        icon: AppIcon.arrowDropDown,
      ),
    ],
  );
}

/// Creates a customized floating action button with specified properties.
///
/// The [icon] parameter specifies the icon to display on the button.
/// The [foregroundColor] parameter specifies the color of the icon.
/// The [tooltip] parameter specifies the text to display when the button is hovered over.
/// The [onPressed] parameter specifies the callback function to execute when the button is pressed.
/// The [child] parameter specifies an optional widget to display on the button instead of an icon.
Widget myFloatButton({
  final Key? key,
  final AppIcon? icon,
  final Color foregroundColor = Colors.white,
  final String? tooltip,
  required final void Function() onPressed,
  final Widget? child,
}) {
  return FloatingActionButton(
    key: key,
    heroTag: null,
    backgroundColor: AppColors.floatingButtonBackground,
    foregroundColor: foregroundColor,
    tooltip: tooltip,
    onPressed: () {
      Future<void>.microtask(() => onPressed());
    },
    child: child ?? AppSvgIcon(icon: icon!, color: foregroundColor),
  );
}
