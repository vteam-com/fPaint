import 'package:flutter/widget_previews.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/helpers/shortcut_tooltip.dart';
import 'package:fpaint/helpers/shortcuts_constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_command.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/panels/side_panel/menu.dart';
import 'package:fpaint/panels/side_panel/recent_files_dialog.dart';
import 'package:fpaint/panels/side_panel/share_panel.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/overlay_control_widgets.dart';
import 'package:fpaint/widgets/shell_selection_sub_toolbar.dart';
import 'package:fpaint/widgets/toolbar_icon_button.dart';

part 'shell_top_bar_responsive_groups.dart';

const String _canvasZoomAndSizeFormat = '{zoom}%\n{width}\n{height}';
const String _canvasZoomFormat = '{zoom}%';
const String _placeholderZoom = '{zoom}';
const String _placeholderWidth = '{width}';
const String _placeholderHeight = '{height}';
const double _toolbarCenterActionEstimatedWidth = AppLayout.toolbarButtonWidth;
const double _shellTopBarPreviewWidth = AppLayout.sidePanelExpandedMin;

/// Estimated width of one icon action at [profile]'s icon size, so the
/// responsive toolbar keeps more actions at denser (mouse) sizing.
double _iconActionWidth(InteractionLayoutProfile profile) => profile.iconSize + AppSpacing.medium + AppSpacing.medium;

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
  Widget build(BuildContext context) {
    final InteractionLayoutProfile interactionProfile = shellProvider.interactionLayoutProfile;
    final AppLocalizations l10n = context.l10n;
    final Widget leadingToolbarButton = shellProvider.deviceSizeSmall
        ? buildToolbarIconButton(
            key: Keys.floatActionMenuToggle,
            tooltip: shellProvider.showMenu
                ? l10n.cancel
                : tooltipWithShortcut(
                    l10n.menuTooltip,
                    singleKeyShortcut(ShortcutKeys.tab),
                  ),
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
            tooltip: tooltipWithShortcut(
              l10n.menuTooltip,
              singleKeyShortcut(ShortcutKeys.tab),
            )!,
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
              // A thin vertical inset keeps the grouped surfaces off the bar
              // edges, like native desktop toolbars.
              padding: EdgeInsets.symmetric(
                horizontal: interactionProfile.buttonSpacing,
                vertical: AppSpacing.thin,
              ),
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
  required ShellProvider shellProvider,
  required String tooltip,
  required InteractionLayoutProfile interactionProfile,
}) {
  return buildToolbarIconButton(
    key: Keys.floatActionToggle,
    tooltip: tooltip,
    icon: _desktopShellCycleIcon(shellProvider),
    interactionProfile: interactionProfile,
    onPressed: () {
      Future<void>.microtask(() => _cycleDesktopShellState(shellProvider));
    },
  );
}

AppIcon _desktopShellCycleIcon(ShellProvider shellProvider) {
  if (shellProvider.shellMode == ShellMode.hidden) {
    return AppIcon.menu;
  }
  if (shellProvider.isSidePanelExpanded) {
    return AppIcon.keyboardDoubleArrowLeft;
  }
  return AppIcon.arrowDropDown;
}

/// Rotates the desktop shell button through expanded, narrow, and hidden states.
void _cycleDesktopShellState(ShellProvider shellProvider) {
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
  BuildContext context,
  ShellProvider shellProvider,
  AppProvider appProvider,
  InteractionLayoutProfile interactionProfile,
) {
  return ListenableBuilder(
    listenable: appProvider.toolbarActionsListenable,
    builder: (BuildContext _, Widget? _) {
      return LayoutBuilder(
        builder: (BuildContext _, BoxConstraints constraints) {
          final List<_ToolbarActionEntry> primaryActions = _buildPrimaryToolbarActionEntries(
            context,
            shellProvider,
            appProvider,
            interactionProfile,
          );
          if (shellProvider.deviceSizeSmall == false) {
            final List<_ToolbarActionGroup> wideGroups = _buildToolbarActionGroups(
              context: context,
              shellProvider: shellProvider,
              appProvider: appProvider,
              interactionProfile: interactionProfile,
              primaryActions: primaryActions,
              selectionLayout: _SelectionGroupLayout.fixed,
            );
            final double fullToolbarWidth =
                _estimateToolbarActionWidth(
                  wideGroups.expand((_ToolbarActionGroup group) => group.actions).toList(),
                  interactionProfile.buttonSpacing,
                ) +
                AppSpacing.large;

            if (constraints.maxWidth >= fullToolbarWidth) {
              return _buildWideToolbarRow(wideGroups);
            }
          }

          final List<_ToolbarActionGroup> visibleGroups = _selectResponsiveToolbarActionGroups(
            groups: _buildToolbarActionGroups(
              context: context,
              shellProvider: shellProvider,
              appProvider: appProvider,
              interactionProfile: interactionProfile,
              primaryActions: _filterToolbarActionsForViewport(
                actions: primaryActions,
                shellProvider: shellProvider,
              ),
              selectionLayout: _SelectionGroupLayout.scrollable,
            ),
            maxWidth: constraints.maxWidth,
            groupSpacing: interactionProfile.buttonSpacing,
          );

          if (visibleGroups.isEmpty) {
            return const SizedBox.shrink();
          }

          return Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: interactionProfile.buttonSpacing,
              children: visibleGroups
                  .map<Widget>(
                    (_ToolbarActionGroup group) => _buildResponsiveToolbarGroupWidget(group),
                  )
                  .toList(),
            ),
          );
        },
      );
    },
  );
}

/// Builds one responsive toolbar domain, allowing configured domains to scroll
/// horizontally instead of overflowing the overall toolbar row.
Widget _buildResponsiveToolbarGroupWidget(_ToolbarActionGroup group) {
  final Widget groupWidget = _buildToolbarGroupSurface(group);

  if (group.isHorizontallyScrollable == false) {
    return groupWidget;
  }

  return Flexible(child: groupWidget);
}

/// Wraps one icon-sized [child] as a toolbar entry of [importance].
_ToolbarActionEntry _iconEntry(
  Widget child,
  InteractionLayoutProfile interactionProfile,
  _ToolbarActionImportance importance,
) {
  return _ToolbarActionEntry(
    child: child,
    estimatedWidth: _iconActionWidth(interactionProfile),
    importance: importance,
  );
}

/// Builds a lowest-priority canvas transform entry that runs [transform] with
/// its undo label [label], then refits the canvas to the view.
_ToolbarActionEntry _canvasTransformEntry({
  required ShellProvider shellProvider,
  required InteractionLayoutProfile interactionProfile,
  required String label,
  required AppIcon icon,
  required Future<void> Function(String label) transform,
}) {
  return _iconEntry(
    buildToolbarIconButton(
      tooltip: label,
      icon: icon,
      interactionProfile: interactionProfile,
      onPressed: () async {
        await transform(label);
        shellProvider.requestCanvasFit();
      },
    ),
    interactionProfile,
    _ToolbarActionImportance.lowest,
  );
}

/// Builds the primary document actions shown on wide desktop toolbars.
List<_ToolbarActionEntry> _buildPrimaryToolbarActionEntries(
  BuildContext context,
  ShellProvider shellProvider,
  AppProvider appProvider,
  InteractionLayoutProfile interactionProfile,
) {
  final AppLocalizations l10n = context.l10n;

  return <_ToolbarActionEntry>[
    _iconEntry(
      buildToolbarIconButton(
        tooltip: l10n.startOverTooltip,
        icon: AppCommand.newDocument.icon,
        interactionProfile: interactionProfile,
        onPressed: () => onFileNew(context),
      ),
      interactionProfile,
      _ToolbarActionImportance.lowest,
    ),
    _iconEntry(
      buildToolbarIconButton(
        tooltip: l10n.importTooltip,
        icon: AppCommand.importFile.icon,
        interactionProfile: interactionProfile,
        onPressed: () => showImportSheet(context),
      ),
      interactionProfile,
      _ToolbarActionImportance.low,
    ),
    _iconEntry(
      buildToolbarIconButton(
        key: Keys.sidePanelExportButton,
        tooltip: l10n.exportTooltip,
        icon: AppCommand.exportFile.icon,
        interactionProfile: interactionProfile,
        onPressed: () => sharePanel(context),
      ),
      interactionProfile,
      _ToolbarActionImportance.low,
    ),
    _iconEntry(
      buildToolbarIconButton(
        key: Keys.floatActionPaste,
        tooltip: AppCommand.paste.tooltip(l10n.paste),
        icon: AppCommand.paste.icon,
        interactionProfile: interactionProfile,
        onPressed: () {
          Future<void>.microtask(() => appProvider.paste());
        },
      ),
      interactionProfile,
      _ToolbarActionImportance.low,
    ),
    _canvasTransformEntry(
      shellProvider: shellProvider,
      interactionProfile: interactionProfile,
      label: l10n.rotateCanvasTooltip,
      icon: AppIcon.rotate90DegreesCw,
      transform: appProvider.rotateCanvas90,
    ),
    _canvasTransformEntry(
      shellProvider: shellProvider,
      interactionProfile: interactionProfile,
      label: l10n.flipHorizontalTooltip,
      icon: AppIcon.flipHorizontal,
      transform: appProvider.flipCanvasHorizontal,
    ),
    _canvasTransformEntry(
      shellProvider: shellProvider,
      interactionProfile: interactionProfile,
      label: l10n.flipVerticalTooltip,
      icon: AppIcon.flipVertical,
      transform: appProvider.flipCanvasVertical,
    ),
  ];
}

/// Builds the wide desktop toolbar with every group spread across the strip.
Widget _buildWideToolbarRow(List<_ToolbarActionGroup> groups) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: groups.map<Widget>(_buildToolbarGroupSurface).toList(),
  );
}

/// Filters toolbar actions using the current viewport-level priority floor.
List<_ToolbarActionEntry> _filterToolbarActionsForViewport({
  required List<_ToolbarActionEntry> actions,
  required ShellProvider shellProvider,
}) {
  if (shellProvider.deviceSizeSmall == false) {
    return actions;
  }

  return actions
      .where(
        (_ToolbarActionEntry entry) => entry.importance.index <= _ToolbarActionImportance.medium.index,
      )
      .toList();
}

/// Estimates the width of [actions] including inter-button spacing.
double _estimateToolbarActionWidth(
  List<_ToolbarActionEntry> actions,
  double spacing,
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
int _indexOfLeastImportantAction(List<_ToolbarActionEntry> actions) {
  int removalIndex = -AppMath.one;

  for (int index = actions.length - AppMath.one; index >= AppMath.zero; index--) {
    if (removalIndex < AppMath.zero || actions[index].importance.index > actions[removalIndex].importance.index) {
      removalIndex = index;
    }
  }

  return removalIndex;
}

/// Wraps one toolbar group in its shared surface, unless it brings its own.
Widget _buildToolbarGroupSurface(_ToolbarActionGroup group) {
  if (group.usesCustomSurface) {
    return group.actions.single.child;
  }

  return _buildToolbarButtonGroup(
    children: group.actions.map((_ToolbarActionEntry entry) => entry.child).toList(),
    spacing: group.spacing,
  );
}

/// Builds a toolbar button group, collapsing empty groups out of the layout.
Widget _buildToolbarButtonGroup({
  required List<Widget> children,
  required double spacing,
}) {
  if (children.isEmpty) {
    return const SizedBox.shrink();
  }

  return buildOverlayControlSurface(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: spacing,
      children: children,
    ),
  );
}

/// Builds the selector toggle floating action button.
Widget _buildSelectorToggleButton({
  required AppProvider appProvider,
  required AppLocalizations l10n,
  required bool hasActiveSelection,
  required InteractionLayoutProfile interactionProfile,
}) {
  return buildToolbarIconButton(
    key: Keys.floatActionSelector,
    tooltip: hasActiveSelection ? l10n.cancel : AppCommand.selector.tooltip(l10n.toolSelector),
    icon: hasActiveSelection ? AppIcon.selectorCancel : AppCommand.selector.icon,
    interactionProfile: interactionProfile,
    useSourceColors: hasActiveSelection,
    onPressed: () {
      Future<void>.microtask(() => appProvider.toggleSelectionOverlayFromFab());
    },
  );
}

/// Builds either the undo or redo FAB with history-aware tooltip content.
///
/// This keeps undo/redo construction in one place so both actions stay in sync
/// for enabled-state handling, shortcut labeling, and dispatch behavior.
Widget _buildUndoRedoButton({
  required InteractionLayoutProfile interactionProfile,
  required bool enabled,
  required Key key,
  required AppCommand command,
  required String historyLabel,
  required void Function() action,
}) {
  return _buildHistoryButton(
    key: key,
    icon: command.icon,
    tooltip: command.tooltip(historyLabel),
    action: action,
    interactionProfile: interactionProfile,
    enabled: enabled,
  );
}

/// Builds a shared floating action button for undo/redo history actions.
Widget _buildHistoryButton({
  required Key key,
  required AppIcon icon,
  required String tooltip,
  required void Function() action,
  required InteractionLayoutProfile interactionProfile,
  required bool enabled,
}) {
  return buildToolbarIconButton(
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

/// Builds a zoom control button that applies [scaleDelta] around the canvas center.
Widget _buildZoomButton({
  required Key key,
  required ShellProvider shellProvider,
  required AppProvider appProvider,
  required InteractionLayoutProfile interactionProfile,
  required AppCommand command,
  required String label,
  required double scaleDelta,
}) {
  return buildToolbarIconButton(
    key: key,
    tooltip: command.tooltip(label),
    icon: command.icon,
    interactionProfile: interactionProfile,
    onPressed: () {
      Future<void>.microtask(() {
        shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
        appProvider.zoomAboutCenter(scaleDelta);
      });
    },
  );
}

/// Builds the center/fit control that recenter the canvas and displays zoom and size.
Widget _buildCenterAndDimensionButton(
  ShellProvider shellProvider,
  AppProvider appProvider,
) {
  final String zoomPercentage = (appProvider.layers.scale * AppLimits.percentMax).toInt().toString();
  final String canvasWidth = appProvider.layers.size.width.toInt().toString();
  final String canvasHeight = appProvider.layers.size.height.toInt().toString();
  final String zoomAndSizeDetails = _canvasZoomAndSizeFormat
      .replaceFirst(_placeholderZoom, zoomPercentage)
      .replaceFirst(_placeholderWidth, canvasWidth)
      .replaceFirst(_placeholderHeight, canvasHeight);

  return AppButton(
    key: Keys.floatActionCenter,
    tooltip:
        '${tooltipWithShortcut(ShortcutActions.fitCanvasToView, primaryModifiedShortcut(ShortcutKeys.zero))!}\n$zoomAndSizeDetails',
    onPressed: () {
      Future<void>.microtask(() {
        shellProvider.requestCanvasFitAndRepaint(appProvider.repaintViewport);
      });
    },
    child: Center(
      child: AppText(
        _canvasZoomFormat.replaceFirst(_placeholderZoom, zoomPercentage),
        textAlign: TextAlign.center,
        variant: AppTextVariant.body,
      ),
    ),
  );
}

/// Widget preview entry for [ShellTopBar].
@Preview(name: 'ShellTopBar')
Widget shellTopBarPreview() {
  final AppProvider appProvider = AppProvider();
  final ShellProvider shellProvider = ShellProvider();
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(_shellTopBarPreviewWidth, AppLayout.shellTopBarHeight)),
      child: Localizations(
        locale: const Locale('en'),
        delegates: AppLocalizations.localizationsDelegates,
        child: SizedBox(
          height: AppLayout.shellTopBarHeight,
          child: ShellTopBar(
            appProvider: appProvider,
            shellProvider: shellProvider,
          ),
        ),
      ),
    ),
  );
}
