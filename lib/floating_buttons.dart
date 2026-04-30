import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';
import 'package:fpaint/widgets/material_free.dart';

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
  return ListenableBuilder(
    listenable: appProvider.undoProvider,
    builder: (final BuildContext _, final Widget? _) {
      final AppLocalizations l10n = context.l10n;
      final bool hasActiveSelection = appProvider.selectorModel.isVisible;
      final bool canUndo = appProvider.undoProvider.canUndo;
      final bool canRedo = appProvider.undoProvider.canRedo;

      final Widget selectorToggleButton = _buildSelectorToggleButton(
        appProvider: appProvider,
        l10n: l10n,
        hasActiveSelection: hasActiveSelection,
      );
      final Widget undoButton = _buildUndoButton(appProvider);
      final Widget redoButton = _buildRedoButton(appProvider);

      if (shellProvider.deviceSizeSmall) {
        return _buildMobileFabRow(
          context: context,
          shellProvider: shellProvider,
          appProvider: appProvider,
          canUndo: canUndo,
          canRedo: canRedo,
          undoButton: undoButton,
          redoButton: redoButton,
          selectorToggleButton: selectorToggleButton,
          l10n: l10n,
        );
      }

      return _buildVerticalFabColumn(
        shellProvider: shellProvider,
        appProvider: appProvider,
        canUndo: canUndo,
        canRedo: canRedo,
        undoButton: undoButton,
        redoButton: redoButton,
        selectorToggleButton: selectorToggleButton,
      );
    },
  );
}

Widget _buildSelectorToggleButton({
  required final AppProvider appProvider,
  required final AppLocalizations l10n,
  required final bool hasActiveSelection,
}) {
  return myFloatButton(
    key: Keys.floatActionSelector,
    icon: hasActiveSelection ? AppIcon.selectorCancel : AppIcon.selector,
    tooltip: hasActiveSelection ? l10n.cancel : l10n.toolSelector,
    onPressed: appProvider.toggleSelectionOverlayFromFab,
  );
}

/// Builds the undo FAB using current undo history tooltip content.
Widget _buildUndoButton(final AppProvider appProvider) {
  return myFloatButton(
    key: Keys.floatActionUndo,
    icon: AppIcon.undo,
    tooltip: appProvider.undoProvider.getHistoryStringForUndo(),
    onPressed: () {
      Future<void>.microtask(() => appProvider.undoAction());
    },
  );
}

/// Builds the redo FAB using current redo history tooltip content.
Widget _buildRedoButton(final AppProvider appProvider) {
  return myFloatButton(
    key: Keys.floatActionRedo,
    icon: AppIcon.redo,
    tooltip: appProvider.undoProvider.getHistoryStringForRedo(),
    onPressed: () {
      Future<void>.microtask(() => appProvider.redoAction());
    },
  );
}

/// Builds the compact mobile FAB row with menu states and conditional actions.
Widget _buildMobileFabRow({
  required final BuildContext context,
  required final ShellProvider shellProvider,
  required final AppProvider appProvider,
  required final bool canUndo,
  required final bool canRedo,
  required final Widget undoButton,
  required final Widget redoButton,
  required final Widget selectorToggleButton,
  required final AppLocalizations l10n,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.end,
    crossAxisAlignment: CrossAxisAlignment.end,
    spacing: AppSpacing.sm - AppStroke.thin,
    children: <Widget>[
      if (!shellProvider.showMenu && canUndo) undoButton,
      if (!shellProvider.showMenu && canRedo) redoButton,
      if (!shellProvider.showMenu)
        myFloatButton(
          key: Keys.floatActionMenuToggle,
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
      if (!shellProvider.showMenu) selectorToggleButton,
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

/// Builds the vertical FAB stack used on tablet/desktop layouts.
Widget _buildVerticalFabColumn({
  required final ShellProvider shellProvider,
  required final AppProvider appProvider,
  required final bool canUndo,
  required final bool canRedo,
  required final Widget undoButton,
  required final Widget redoButton,
  required final Widget selectorToggleButton,
}) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.end,
    spacing: AppSpacing.xs,
    children: <Widget>[
      if (canUndo) undoButton,
      if (canRedo) redoButton,
      selectorToggleButton,

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
        child: AppText(
          _canvasZoomAndSizeFormat
              .replaceFirst(_placeholderZoom, (appProvider.layers.scale * AppLimits.percentMax).toInt().toString())
              .replaceFirst(_placeholderWidth, appProvider.layers.size.width.toInt().toString())
              .replaceFirst(_placeholderHeight, appProvider.layers.size.height.toInt().toString()),
          textAlign: TextAlign.center,
          variant: AppTextVariant.label,
          color: AppColors.floatingButtonForeground,
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
  final Color foregroundColor = AppPalette.white,
  final String? tooltip,
  required final void Function() onPressed,
  final Widget? child,
}) {
  final Widget button = GestureDetector(
    key: key,
    onTap: () {
      Future<void>.microtask(() => onPressed());
    },
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        width: AppLayout.toolbarButtonSize,
        height: AppLayout.toolbarButtonSize,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.floatingButtonBackground,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: child ?? AppSvgIcon(icon: icon!, color: foregroundColor),
          ),
        ),
      ),
    ),
  );
  if (tooltip != null) {
    return AppTooltip(message: tooltip, child: button);
  }
  return button;
}
