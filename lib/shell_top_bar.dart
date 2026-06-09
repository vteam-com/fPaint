import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
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
const double _toolbarIconActionEstimatedWidth = AppLayout.iconSize + AppSpacing.medium + AppSpacing.medium;
const double _toolbarCenterActionEstimatedWidth = AppLayout.toolbarButtonWidth;

enum _ToolbarActionImportance {
  critical,
  medium,
  low,
  lowest,
}

class _ToolbarActionEntry {
  const _ToolbarActionEntry({
    required this.child,
    required this.estimatedWidth,
    required this.importance,
  });

  final Widget child;
  final double estimatedWidth;
  final _ToolbarActionImportance importance;
}

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
    final Widget leadingToolbarButton = shellProvider.deviceSizeSmall
        ? _buildToolbarIconButton(
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
        : _buildDesktopShellCycleButton(
            shellProvider: shellProvider,
            tooltip: l10n.menuTooltip,
            interactionProfile: interactionProfile,
          );

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
          leadingToolbarButton,
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: interactionProfile.buttonSpacing),
              child: _buildResponsiveToolbarActions(
                context,
                shellProvider,
                appProvider,
                interactionProfile,
              ),
            ),
          ),
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
}

/// Builds the responsive middle strip for the top toolbar.
Widget _buildResponsiveToolbarActions(
  final BuildContext context,
  final ShellProvider shellProvider,
  final AppProvider appProvider,
  final InteractionLayoutProfile interactionProfile,
) {
  return ListenableBuilder(
    listenable: appProvider.viewportRepaintListenable,
    builder: (final BuildContext _, final Widget? _) {
      return ListenableBuilder(
        listenable: appProvider,
        builder: (final BuildContext _, final Widget? _) {
          return ListenableBuilder(
            listenable: appProvider.undoProvider,
            builder: (final BuildContext _, final Widget? _) {
              return LayoutBuilder(
                builder: (final BuildContext _, final BoxConstraints constraints) {
                  final List<_ToolbarActionEntry> primaryActions = _buildPrimaryToolbarActionEntries(
                    context,
                    shellProvider,
                    appProvider,
                    interactionProfile,
                  );
                  final List<_ToolbarActionEntry> actions = _filterToolbarActionsForViewport(
                    actions: _buildResponsiveToolbarActionEntries(
                      context,
                      shellProvider,
                      appProvider,
                      interactionProfile,
                    ),
                    shellProvider: shellProvider,
                  );
                  final double fullToolbarWidth =
                      _estimateToolbarActionWidth(actions, interactionProfile.buttonSpacing) + AppSpacing.large;

                  if (shellProvider.deviceSizeSmall == false && constraints.maxWidth >= fullToolbarWidth) {
                    return _buildWideDesktopToolbarActions(
                      context: context,
                      shellProvider: shellProvider,
                      appProvider: appProvider,
                      primaryActions: primaryActions,
                    );
                  }

                  final List<_ToolbarActionEntry> visibleActions = _selectResponsiveToolbarActions(
                    actions: actions,
                    maxWidth: constraints.maxWidth,
                    spacing: interactionProfile.buttonSpacing,
                  );

                  if (visibleActions.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Align(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: interactionProfile.buttonSpacing,
                      children: visibleActions.map((final _ToolbarActionEntry entry) => entry.child).toList(),
                    ),
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

/// Builds the primary document actions shown on wide desktop toolbars.
List<_ToolbarActionEntry> _buildPrimaryToolbarActionEntries(
  final BuildContext context,
  final ShellProvider shellProvider,
  final AppProvider appProvider,
  final InteractionLayoutProfile interactionProfile,
) {
  final AppLocalizations l10n = context.l10n;

  return <_ToolbarActionEntry>[
    _ToolbarActionEntry(
      child: _buildToolbarIconButton(
        tooltip: l10n.startOverTooltip,
        icon: AppIcon.powerSettingsNew,
        interactionProfile: interactionProfile,
        onPressed: () => onFileNew(context),
      ),
      estimatedWidth: _toolbarIconActionEstimatedWidth,
      importance: _ToolbarActionImportance.lowest,
    ),
    _ToolbarActionEntry(
      child: _buildToolbarIconButton(
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
      estimatedWidth: _toolbarIconActionEstimatedWidth,
      importance: _ToolbarActionImportance.low,
    ),
    _ToolbarActionEntry(
      child: _buildToolbarIconButton(
        key: Keys.sidePanelExportButton,
        tooltip: l10n.exportTooltip,
        icon: AppIcon.iosShare,
        interactionProfile: interactionProfile,
        onPressed: () => sharePanel(context),
      ),
      estimatedWidth: _toolbarIconActionEstimatedWidth,
      importance: _ToolbarActionImportance.low,
    ),
    _ToolbarActionEntry(
      child: _buildToolbarIconButton(
        key: Keys.floatActionPaste,
        tooltip: l10n.paste,
        icon: AppIcon.clipboardPaste,
        interactionProfile: interactionProfile,
        onPressed: () {
          Future<void>.microtask(() => appProvider.paste());
        },
      ),
      estimatedWidth: _toolbarIconActionEstimatedWidth,
      importance: _ToolbarActionImportance.low,
    ),
    _ToolbarActionEntry(
      child: _buildToolbarIconButton(
        tooltip: l10n.rotateCanvasTooltip,
        icon: AppIcon.rotate90DegreesCw,
        interactionProfile: interactionProfile,
        onPressed: () async {
          await appProvider.rotateCanvas90(l10n.rotateCanvasTooltip);
          shellProvider.requestCanvasFit();
        },
      ),
      estimatedWidth: _toolbarIconActionEstimatedWidth,
      importance: _ToolbarActionImportance.lowest,
    ),
    _ToolbarActionEntry(
      child: _buildToolbarIconButton(
        tooltip: l10n.flipHorizontalTooltip,
        icon: AppIcon.flipHorizontal,
        interactionProfile: interactionProfile,
        onPressed: () async {
          await appProvider.flipCanvasHorizontal(l10n.flipHorizontalTooltip);
          shellProvider.requestCanvasFit();
        },
      ),
      estimatedWidth: _toolbarIconActionEstimatedWidth,
      importance: _ToolbarActionImportance.lowest,
    ),
    _ToolbarActionEntry(
      child: _buildToolbarIconButton(
        tooltip: l10n.flipVerticalTooltip,
        icon: AppIcon.flipVertical,
        interactionProfile: interactionProfile,
        onPressed: () async {
          await appProvider.flipCanvasVertical(l10n.flipVerticalTooltip);
          shellProvider.requestCanvasFit();
        },
      ),
      estimatedWidth: _toolbarIconActionEstimatedWidth,
      importance: _ToolbarActionImportance.lowest,
    ),
  ];
}

/// Builds the wide desktop toolbar using the dedicated canvas toolbar dock.
Widget _buildWideDesktopToolbarActions({
  required final BuildContext context,
  required final ShellProvider shellProvider,
  required final AppProvider appProvider,
  required final List<_ToolbarActionEntry> primaryActions,
}) {
  return buildCanvasToolbarActions(
    context,
    shellProvider,
    appProvider,
    distributeWideGroups: true,
    primaryActionButtons: primaryActions.map((final _ToolbarActionEntry entry) => entry.child).toList(),
  );
}

/// Filters toolbar actions using the current viewport-level priority floor.
List<_ToolbarActionEntry> _filterToolbarActionsForViewport({
  required final List<_ToolbarActionEntry> actions,
  required final ShellProvider shellProvider,
}) {
  if (shellProvider.deviceSizeSmall == false) {
    return actions;
  }

  return actions
      .where(
        (final _ToolbarActionEntry entry) => entry.importance.index <= _ToolbarActionImportance.medium.index,
      )
      .toList();
}

/// Builds top-toolbar actions with explicit importance for narrow layouts.
List<_ToolbarActionEntry> _buildResponsiveToolbarActionEntries(
  final BuildContext context,
  final ShellProvider shellProvider,
  final AppProvider appProvider,
  final InteractionLayoutProfile interactionProfile,
) {
  final List<_ToolbarActionEntry> primaryActions = _buildPrimaryToolbarActionEntries(
    context,
    shellProvider,
    appProvider,
    interactionProfile,
  );
  final AppLocalizations l10n = context.l10n;
  final bool hasActiveSelection = appProvider.selectorModel.isVisible;
  final bool canUndo = appProvider.undoProvider.canUndo;
  final bool canRedo = appProvider.undoProvider.canRedo;

  return <_ToolbarActionEntry>[
    ...primaryActions,
    _ToolbarActionEntry(
      child: _buildUndoButton(
        appProvider,
        interactionProfile,
        enabled: canUndo,
      ),
      estimatedWidth: _toolbarIconActionEstimatedWidth,
      importance: _ToolbarActionImportance.critical,
    ),
    _ToolbarActionEntry(
      child: _buildRedoButton(
        appProvider,
        interactionProfile,
        enabled: canRedo,
      ),
      estimatedWidth: _toolbarIconActionEstimatedWidth,
      importance: _ToolbarActionImportance.medium,
    ),
    _ToolbarActionEntry(
      child: _buildSelectorToggleButton(
        appProvider: appProvider,
        l10n: l10n,
        hasActiveSelection: hasActiveSelection,
        interactionProfile: interactionProfile,
      ),
      estimatedWidth: _toolbarIconActionEstimatedWidth,
      importance: _ToolbarActionImportance.critical,
    ),
    _ToolbarActionEntry(
      child: _buildZoomButton(
        key: Keys.floatActionZoomOut,
        shellProvider: shellProvider,
        appProvider: appProvider,
        interactionProfile: interactionProfile,
        icon: AppIcon.zoomOut,
        scaleDelta: AppVisual.shrink,
      ),
      estimatedWidth: _toolbarIconActionEstimatedWidth,
      importance: _ToolbarActionImportance.medium,
    ),
    _ToolbarActionEntry(
      child: _buildCenterAndDimensionButton(shellProvider, appProvider),
      estimatedWidth: _toolbarCenterActionEstimatedWidth,
      importance: _ToolbarActionImportance.medium,
    ),
    _ToolbarActionEntry(
      child: _buildZoomButton(
        key: Keys.floatActionZoomIn,
        shellProvider: shellProvider,
        appProvider: appProvider,
        interactionProfile: interactionProfile,
        icon: AppIcon.zoomIn,
        scaleDelta: AppVisual.enlarge,
      ),
      estimatedWidth: _toolbarIconActionEstimatedWidth,
      importance: _ToolbarActionImportance.medium,
    ),
  ];
}

/// Selects the highest-value actions that fit within [maxWidth].
List<_ToolbarActionEntry> _selectResponsiveToolbarActions({
  required final List<_ToolbarActionEntry> actions,
  required final double maxWidth,
  required final double spacing,
}) {
  if (maxWidth <= AppMath.zero) {
    return const <_ToolbarActionEntry>[];
  }

  final List<_ToolbarActionEntry> visibleActions = List<_ToolbarActionEntry>.from(actions);
  double requiredWidth = _estimateToolbarActionWidth(visibleActions, spacing);

  while (visibleActions.isNotEmpty && requiredWidth > maxWidth) {
    final int removalIndex = _indexOfLeastImportantAction(visibleActions);
    if (removalIndex < AppMath.zero) {
      break;
    }
    visibleActions.removeAt(removalIndex);
    requiredWidth = _estimateToolbarActionWidth(visibleActions, spacing);
  }

  return visibleActions;
}

/// Estimates the width of [actions] including inter-button spacing.
double _estimateToolbarActionWidth(
  final List<_ToolbarActionEntry> actions,
  final double spacing,
) {
  double requiredWidth = AppMath.zero.toDouble();

  for (int index = AppMath.zero; index < actions.length; index++) {
    requiredWidth += actions[index].estimatedWidth;
    if (index > AppMath.zero) {
      requiredWidth += spacing;
    }
  }

  return requiredWidth;
}

/// Returns the least important action, preferring later actions when tied.
int _indexOfLeastImportantAction(final List<_ToolbarActionEntry> actions) {
  int removalIndex = -AppMath.one;

  for (int index = actions.length - AppMath.one; index >= AppMath.zero; index--) {
    if (removalIndex < AppMath.zero || actions[index].importance.index > actions[removalIndex].importance.index) {
      removalIndex = index;
    }
  }

  return removalIndex;
}

/// Builds the canvas actions shown on the right side of the top toolbar.
///
/// The [context] parameter is the [BuildContext] used to access the application's providers.
/// The [shellProvider] parameter is the [ShellProvider] instance used to manage the application's shell.
/// The [appProvider] parameter is the [AppProvider] instance used to manage the application's state.
Widget buildCanvasToolbarActions(
  final BuildContext context,
  final ShellProvider shellProvider,
  final AppProvider appProvider, {
  final bool distributeWideGroups = false,
  final List<Widget>? primaryActionButtons,
}) {
  return ListenableBuilder(
    listenable: appProvider.viewportRepaintListenable,
    builder: (final BuildContext _, final Widget? _) {
      return ListenableBuilder(
        listenable: appProvider,
        builder: (final BuildContext _, final Widget? _) {
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
              final Widget zoomOutButton = _buildZoomButton(
                key: Keys.floatActionZoomOut,
                shellProvider: shellProvider,
                appProvider: appProvider,
                interactionProfile: interactionProfile,
                icon: AppIcon.zoomOut,
                scaleDelta: AppVisual.shrink,
              );
              final Widget centerButton = _buildCenterAndDimensionButton(shellProvider, appProvider);
              final Widget zoomInButton = _buildZoomButton(
                key: Keys.floatActionZoomIn,
                shellProvider: shellProvider,
                appProvider: appProvider,
                interactionProfile: interactionProfile,
                icon: AppIcon.zoomIn,
                scaleDelta: AppVisual.enlarge,
              );
              final Widget? shellToggleButton = shellProvider.deviceSizeSmall
                  ? _buildSmallScreenShellToggleButton(
                      shellProvider: shellProvider,
                      tooltip: l10n.menuTooltip,
                      interactionProfile: interactionProfile,
                    )
                  : null;

              if (distributeWideGroups) {
                final List<Widget> resolvedPrimaryActionButtons = primaryActionButtons ?? const <Widget>[];
                final List<Widget> leadingPrimaryActions = resolvedPrimaryActionButtons.take(AppMath.triple).toList();
                final List<Widget> trailingPrimaryActions = resolvedPrimaryActionButtons.skip(AppMath.triple).toList();

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _buildToolbarButtonGroup(
                      children: leadingPrimaryActions,
                      spacing: AppSpacing.small,
                    ),
                    _buildToolbarButtonGroup(
                      children: trailingPrimaryActions,
                      spacing: AppSpacing.small,
                    ),
                    _buildToolbarButtonGroup(
                      children: <Widget>[undoButton, redoButton],
                      spacing: interactionProfile.buttonSpacing,
                    ),
                    _buildToolbarButtonGroup(
                      children: <Widget>[selectorToggleButton],
                      spacing: interactionProfile.buttonSpacing,
                    ),
                    _buildToolbarButtonGroup(
                      children: <Widget>[zoomOutButton, centerButton, zoomInButton],
                      spacing: interactionProfile.buttonSpacing,
                    ),
                  ],
                );
              }

              return _buildToolbarDock(
                undoButton: undoButton,
                redoButton: redoButton,
                selectorToggleButton: selectorToggleButton,
                shellToggleButton: shellToggleButton,
                interactionProfile: interactionProfile,
                zoomOutButton: zoomOutButton,
                centerButton: centerButton,
                zoomInButton: zoomInButton,
              );
            },
          );
        },
      );
    },
  );
}

/// Builds a toolbar button group, collapsing empty groups out of the layout.
Widget _buildToolbarButtonGroup({
  required final List<Widget> children,
  required final double spacing,
}) {
  if (children.isEmpty) {
    return const SizedBox.shrink();
  }

  if (children.length == AppMath.one) {
    return children.first;
  }

  return Row(
    mainAxisSize: MainAxisSize.min,
    spacing: spacing,
    children: children,
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
  required final Widget undoButton,
  required final Widget redoButton,
  required final Widget selectorToggleButton,
  required final Widget? shellToggleButton,
  required final InteractionLayoutProfile interactionProfile,
  required final Widget zoomOutButton,
  required final Widget centerButton,
  required final Widget zoomInButton,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    spacing: interactionProfile.buttonSpacing,
    children: <Widget>[
      undoButton,
      redoButton,
      selectorToggleButton,
      ?shellToggleButton,
      zoomOutButton,
      centerButton,
      zoomInButton,
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
        shellProvider.requestCanvasFit();
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
}
