import 'package:flutter/widgets.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/panels/side_panel/menu.dart';
import 'package:fpaint/panels/side_panel/recent_files_dialog.dart';
import 'package:fpaint/panels/side_panel/share_panel.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/material_free.dart';

const String _canvasZoomAndSizeFormat = '{zoom}%\n{width}\n{height}';
const String _placeholderZoom = '{zoom}';
const String _placeholderWidth = '{width}';
const String _placeholderHeight = '{height}';

/// Full-width top toolbar combining shell actions and canvas controls.
class ShellTopBar extends StatelessWidget {
  const ShellTopBar({
    super.key,
    required this.appProvider,
    required this.shellProvider,
  });

  /// Current application state used by toolbar actions.
  final AppProvider appProvider;

  /// Current shell state used by layout and toolbar actions.
  final ShellProvider shellProvider;

  @override
  Widget build(final BuildContext context) {
    final InteractionLayoutProfile interactionProfile = shellProvider.interactionLayoutProfile;
    final AppLocalizations l10n = context.l10n;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.shellChromeBackground,
        border: Border(
          bottom: BorderSide(
            color: AppColors.shellChromeDivider,
            width: AppStroke.thin,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          if (shellProvider.deviceSizeSmall)
            _buildToolbarIconButton(
              key: Keys.floatActionMenuToggle,
              tooltip: shellProvider.showMenu ? l10n.cancel : l10n.menuTooltip,
              icon: shellProvider.showMenu ? AppIcon.close : AppIcon.menu,
              interactionProfile: interactionProfile,
              onPressed: () {
                Future<void>.microtask(() {
                  if (shellProvider.shellMode == ShellMode.hidden) {
                    shellProvider.shellMode = ShellMode.full;
                    shellProvider.showMenu = true;
                    return;
                  }
                  shellProvider.showMenu = !shellProvider.showMenu;
                });
              },
            )
          else
            _buildDesktopShellCycleButton(
              shellProvider: shellProvider,
              tooltip: l10n.menuTooltip,
              interactionProfile: interactionProfile,
            ),
          const Spacer(),
          _buildPrimaryToolbarActions(
            context,
            shellProvider,
            interactionProfile,
          ),
          const Spacer(),
          buildCanvasToolbarActions(
            context,
            shellProvider,
            appProvider,
          ),
          const Spacer(),
          const MainMenu(),
        ],
      ),
    );
  }
}

/// Builds the desktop shell control that cycles expanded, narrow, and hidden states.
Widget _buildDesktopShellCycleButton({
  required final ShellProvider shellProvider,
  required final String tooltip,
  required final InteractionLayoutProfile interactionProfile,
}) {
  return _buildToolbarIconButton(
    key: Keys.floatActionToggle,
    tooltip: tooltip,
    icon: _desktopShellCycleIcon(shellProvider),
    interactionProfile: interactionProfile,
    onPressed: () {
      Future<void>.microtask(() => _cycleDesktopShellState(shellProvider));
    },
  );
}

AppIcon _desktopShellCycleIcon(final ShellProvider shellProvider) {
  if (shellProvider.shellMode == ShellMode.hidden) {
    return AppIcon.menu;
  }
  if (shellProvider.isSidePanelExpanded) {
    return AppIcon.keyboardDoubleArrowLeft;
  }
  return AppIcon.arrowDropDown;
}

/// Rotates the desktop shell button through expanded, narrow, and hidden states.
void _cycleDesktopShellState(final ShellProvider shellProvider) {
  if (shellProvider.shellMode == ShellMode.hidden) {
    shellProvider.shellMode = ShellMode.full;
    shellProvider.isSidePanelExpanded = true;
    return;
  }

  if (shellProvider.isSidePanelExpanded) {
    shellProvider.isSidePanelExpanded = false;
    return;
  }

  shellProvider.shellMode = ShellMode.hidden;
  shellProvider.update();
}

/// Builds the document and shell actions shown on the left side of the top bar.
Widget _buildPrimaryToolbarActions(
  final BuildContext context,
  final ShellProvider shellProvider,
  final InteractionLayoutProfile interactionProfile,
) {
  final AppLocalizations l10n = context.l10n;

  return Row(
    mainAxisSize: MainAxisSize.min,
    spacing: AppSpacing.small,
    children: <Widget>[
      _buildToolbarIconButton(
        tooltip: l10n.startOverTooltip,
        icon: AppIcon.powerSettingsNew,
        interactionProfile: interactionProfile,
        onPressed: () => onFileNew(context),
      ),
      _buildToolbarIconButton(
        tooltip: l10n.importTooltip,
        icon: AppIcon.fileDownload,
        interactionProfile: interactionProfile,
        onPressed: () => showAppBottomSheet<void>(
          context: context,
          builder: (final BuildContext _) {
            return ImportDialog(parentContext: context);
          },
        ),
      ),
      _buildToolbarIconButton(
        key: Keys.sidePanelExportButton,
        tooltip: l10n.exportTooltip,
        icon: AppIcon.iosShare,
        interactionProfile: interactionProfile,
        onPressed: () => sharePanel(context),
      ),
      _buildToolbarIconButton(
        tooltip: l10n.rotateCanvasTooltip,
        icon: AppIcon.rotate90DegreesCw,
        interactionProfile: interactionProfile,
        onPressed: () async {
          final AppProvider appProvider = AppProvider.of(context);
          await appProvider.rotateCanvas90(l10n.rotateCanvasTooltip);
          shellProvider.requestCanvasFit();
        },
      ),
      _buildToolbarIconButton(
        tooltip: l10n.flipHorizontalTooltip,
        icon: AppIcon.flipHorizontal,
        interactionProfile: interactionProfile,
        onPressed: () async {
          final AppProvider appProvider = AppProvider.of(context);
          await appProvider.flipCanvasHorizontal(l10n.flipHorizontalTooltip);
          shellProvider.requestCanvasFit();
        },
      ),
      _buildToolbarIconButton(
        tooltip: l10n.flipVerticalTooltip,
        icon: AppIcon.flipVertical,
        interactionProfile: interactionProfile,
        onPressed: () async {
          final AppProvider appProvider = AppProvider.of(context);
          await appProvider.flipCanvasVertical(l10n.flipVerticalTooltip);
          shellProvider.requestCanvasFit();
        },
      ),
    ],
  );
}

/// Builds the canvas actions shown on the right side of the top toolbar.
///
/// The [context] parameter is the [BuildContext] used to access the application's providers.
/// The [shellProvider] parameter is the [ShellProvider] instance used to manage the application's shell.
/// The [appProvider] parameter is the [AppProvider] instance used to manage the application's state.
Widget buildCanvasToolbarActions(
  final BuildContext context,
  final ShellProvider shellProvider,
  final AppProvider appProvider,
) {
  return ListenableBuilder(
    listenable: appProvider.undoProvider,
    builder: (final BuildContext _, final Widget? _) {
      final AppLocalizations l10n = context.l10n;
      final InteractionLayoutProfile interactionProfile = shellProvider.interactionLayoutProfile;
      final bool hasActiveSelection = appProvider.selectorModel.isVisible;
      final bool canUndo = appProvider.undoProvider.canUndo;
      final bool canRedo = appProvider.undoProvider.canRedo;

      final Widget selectorToggleButton = _buildSelectorToggleButton(
        appProvider: appProvider,
        l10n: l10n,
        hasActiveSelection: hasActiveSelection,
        interactionProfile: interactionProfile,
      );
      final Widget undoButton = _buildUndoButton(
        appProvider,
        interactionProfile,
        enabled: canUndo,
      );
      final Widget redoButton = _buildRedoButton(
        appProvider,
        interactionProfile,
        enabled: canRedo,
      );
      final Widget? shellToggleButton = shellProvider.deviceSizeSmall
          ? _buildSmallScreenShellToggleButton(
              shellProvider: shellProvider,
              tooltip: l10n.menuTooltip,
              interactionProfile: interactionProfile,
            )
          : null;

      return _buildToolbarDock(
        shellProvider: shellProvider,
        appProvider: appProvider,
        undoButton: undoButton,
        redoButton: redoButton,
        selectorToggleButton: selectorToggleButton,
        shellToggleButton: shellToggleButton,
        interactionProfile: interactionProfile,
      );
    },
  );
}

/// Builds the small-screen shell control that toggles between hidden and full.
Widget _buildSmallScreenShellToggleButton({
  required final ShellProvider shellProvider,
  required final String tooltip,
  required final InteractionLayoutProfile interactionProfile,
}) {
  return _buildToolbarIconButton(
    key: Keys.floatActionToggle,
    tooltip: tooltip,
    icon: shellProvider.shellMode == ShellMode.hidden ? AppIcon.menu : AppIcon.close,
    interactionProfile: interactionProfile,
    onPressed: () {
      Future<void>.microtask(() => _toggleSmallScreenShellState(shellProvider));
    },
  );
}

/// Builds the selector toggle floating action button.
Widget _buildSelectorToggleButton({
  required final AppProvider appProvider,
  required final AppLocalizations l10n,
  required final bool hasActiveSelection,
  required final InteractionLayoutProfile interactionProfile,
}) {
  return _buildToolbarIconButton(
    key: Keys.floatActionSelector,
    tooltip: hasActiveSelection ? l10n.cancel : l10n.toolSelector,
    icon: hasActiveSelection ? AppIcon.selectorCancel : AppIcon.selector,
    interactionProfile: interactionProfile,
    onPressed: () {
      Future<void>.microtask(() => appProvider.toggleSelectionOverlayFromFab());
    },
  );
}

/// Builds the undo FAB using current undo history tooltip content.
Widget _buildUndoButton(
  final AppProvider appProvider,
  final InteractionLayoutProfile interactionProfile, {
  required final bool enabled,
}) {
  return _buildHistoryButton(
    key: Keys.floatActionUndo,
    icon: AppIcon.undo,
    tooltip: appProvider.undoProvider.getHistoryStringForUndo(),
    action: appProvider.undoAction,
    interactionProfile: interactionProfile,
    enabled: enabled,
  );
}

/// Builds the redo FAB using current redo history tooltip content.
Widget _buildRedoButton(
  final AppProvider appProvider,
  final InteractionLayoutProfile interactionProfile, {
  required final bool enabled,
}) {
  return _buildHistoryButton(
    key: Keys.floatActionRedo,
    icon: AppIcon.redo,
    tooltip: appProvider.undoProvider.getHistoryStringForRedo(),
    action: appProvider.redoAction,
    interactionProfile: interactionProfile,
    enabled: enabled,
  );
}

/// Builds a shared floating action button for undo/redo history actions.
Widget _buildHistoryButton({
  required final Key key,
  required final AppIcon icon,
  required final String tooltip,
  required final void Function() action,
  required final InteractionLayoutProfile interactionProfile,
  required final bool enabled,
}) {
  return _buildToolbarIconButton(
    key: key,
    tooltip: enabled ? tooltip : null,
    icon: icon,
    interactionProfile: interactionProfile,
    enabled: enabled,
    onPressed: () {
      Future<void>.microtask(action);
    },
  );
}

/// Builds the toolbar row of history, selection, zoom, and shell controls.
Widget _buildToolbarDock({
  required final ShellProvider shellProvider,
  required final AppProvider appProvider,
  required final Widget undoButton,
  required final Widget redoButton,
  required final Widget selectorToggleButton,
  required final Widget? shellToggleButton,
  required final InteractionLayoutProfile interactionProfile,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    spacing: interactionProfile.buttonSpacing,
    children: <Widget>[
      undoButton,
      redoButton,
      selectorToggleButton,
      ?shellToggleButton,
      _buildZoomButton(
        key: Keys.floatActionZoomOut,
        shellProvider: shellProvider,
        appProvider: appProvider,
        interactionProfile: interactionProfile,
        icon: AppIcon.zoomOut,
        scaleDelta: AppVisual.shrink,
      ),
      _buildCenterAndDimensionButton(shellProvider, appProvider),
      _buildZoomButton(
        key: Keys.floatActionZoomIn,
        shellProvider: shellProvider,
        appProvider: appProvider,
        interactionProfile: interactionProfile,
        icon: AppIcon.zoomIn,
        scaleDelta: AppVisual.enlarge,
      ),
    ],
  );
}

/// Builds a zoom control button that applies [scaleDelta] around the canvas center.
Widget _buildZoomButton({
  required final Key key,
  required final ShellProvider shellProvider,
  required final AppProvider appProvider,
  required final InteractionLayoutProfile interactionProfile,
  required final AppIcon icon,
  required final double scaleDelta,
}) {
  return _buildToolbarIconButton(
    key: key,
    icon: icon,
    interactionProfile: interactionProfile,
    onPressed: () {
      Future<void>.microtask(() {
        shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
        appProvider.applyScaleToCanvas(
          scaleDelta: scaleDelta,
          anchorPoint: appProvider.canvasCenter,
        );
      });
    },
  );
}

/// Builds the center/fit control that recenter the canvas and displays zoom and size.
Widget _buildCenterAndDimensionButton(
  final ShellProvider shellProvider,
  final AppProvider appProvider,
) {
  return AppButton(
    key: Keys.floatActionCenter,
    onPressed: () {
      Future<void>.microtask(() {
        shellProvider.canvasPlacement = CanvasAutoPlacement.fit;
        appProvider.update();
        // Its still unclear why but this is needed to update the canvas and the Selectors/Fill widget correctly
        Future<void>.delayed(const Duration(milliseconds: AppLimits.percentMax), () {
          appProvider.update();
        });
      });
    },
    child: Center(
      child: AppText(
        _canvasZoomAndSizeFormat
            .replaceFirst(_placeholderZoom, (appProvider.layers.scale * AppLimits.percentMax).toInt().toString())
            .replaceFirst(_placeholderWidth, appProvider.layers.size.width.toInt().toString())
            .replaceFirst(_placeholderHeight, appProvider.layers.size.height.toInt().toString()),
        textAlign: TextAlign.center,
        variant: AppTextVariant.label,
      ),
    ),
  );
}

/// Builds a standard icon action for the top toolbar.
Widget _buildToolbarIconButton({
  final Key? key,
  final String? tooltip,
  required final AppIcon icon,
  required final InteractionLayoutProfile interactionProfile,
  final bool enabled = true,
  required final VoidCallback onPressed,
}) {
  return AppButtonIcon(
    key: key,
    tooltip: tooltip,
    icon: icon,
    size: interactionProfile.iconSize,
    enabled: enabled,
    onPressed: onPressed,
  );
}

/// Toggles the small-screen shell action between hidden and full states.
void _toggleSmallScreenShellState(final ShellProvider shellProvider) {
  switch (shellProvider.shellMode) {
    case ShellMode.hidden:
      shellProvider.shellMode = ShellMode.full;
      break;
    default:
      shellProvider.shellMode = ShellMode.hidden;
  }
  shellProvider.update();
}
