part of 'shell_top_bar.dart';

const double _toolbarGroupHorizontalPadding = AppSpacing.small * 2;

/// Responsive toolbar domain that keeps related actions inside one shared surface.
class _ToolbarActionGroup {
  const _ToolbarActionGroup({
    required this.actions,
    required this.spacing,
    this.minimumVisibleActions = AppMath.zero,
    this.isHorizontallyScrollable = false,
    this.usesCustomSurface = false,
  });

  final List<_ToolbarActionEntry> actions;
  final double spacing;
  final int minimumVisibleActions;
  final bool isHorizontallyScrollable;
  final bool usesCustomSurface;
}

/// Concrete responsive group after lower-priority actions have been trimmed.
class _ResolvedToolbarActionGroup {
  const _ResolvedToolbarActionGroup({
    required this.actions,
    required this.spacing,
    required this.isHorizontallyScrollable,
    required this.usesCustomSurface,
  });

  final List<_ToolbarActionEntry> actions;
  final double spacing;
  final bool isHorizontallyScrollable;
  final bool usesCustomSurface;
}

/// Lowest-priority action that can still be removed from a responsive group.
class _ToolbarActionRemovalCandidate {
  const _ToolbarActionRemovalCandidate({
    required this.groupIndex,
    required this.actionIndex,
    required this.action,
  });

  final int groupIndex;
  final int actionIndex;
  final _ToolbarActionEntry action;
}

/// Builds the responsive toolbar domains that must stay visually grouped.
List<_ToolbarActionGroup> _buildResponsiveToolbarActionGroups({
  required final BuildContext context,
  required final ShellProvider shellProvider,
  required final AppProvider appProvider,
  required final InteractionLayoutProfile interactionProfile,
  required final List<_ToolbarActionEntry> primaryActions,
}) {
  final AppLocalizations l10n = context.l10n;
  final bool hasActiveSelection =
      appProvider.selectedAction == ActionType.selector || appProvider.selectorModel.isVisible;
  final bool canUndo = appProvider.undoProvider.canUndo;
  final bool canRedo = appProvider.undoProvider.canRedo;
  final bool showSelectionSubToolbar = shouldShowSelectionSubToolbar(appProvider);
  final Widget selectorToggleButton = _buildSelectorToggleButton(
    appProvider: appProvider,
    l10n: l10n,
    hasActiveSelection: hasActiveSelection,
    interactionProfile: interactionProfile,
  );

  return <_ToolbarActionGroup>[
    _ToolbarActionGroup(
      actions: primaryActions.take(AppMath.four).toList(),
      spacing: AppSpacing.small,
    ),
    _ToolbarActionGroup(
      actions: primaryActions.skip(AppMath.four).toList(),
      spacing: AppSpacing.small,
    ),
    _ToolbarActionGroup(
      actions: <_ToolbarActionEntry>[
        _ToolbarActionEntry(
          child: _buildUndoRedoButton(
            interactionProfile: interactionProfile,
            enabled: canUndo,
            key: Keys.floatActionUndo,
            icon: AppIcon.undo,
            historyLabel: appProvider.undoProvider.getHistoryStringForUndo(),
            shortcutKey: ShortcutKeys.z,
            action: appProvider.undoAction,
          ),
          estimatedWidth: _toolbarIconActionEstimatedWidth,
          importance: _ToolbarActionImportance.critical,
        ),
        _ToolbarActionEntry(
          child: _buildUndoRedoButton(
            interactionProfile: interactionProfile,
            enabled: canRedo,
            key: Keys.floatActionRedo,
            icon: AppIcon.redo,
            historyLabel: appProvider.undoProvider.getHistoryStringForRedo(),
            shortcutKey: ShortcutKeys.y,
            action: appProvider.redoAction,
          ),
          estimatedWidth: _toolbarIconActionEstimatedWidth,
          importance: _ToolbarActionImportance.medium,
        ),
      ],
      spacing: interactionProfile.buttonSpacing,
      minimumVisibleActions: AppMath.one,
    ),
    _ToolbarActionGroup(
      actions: <_ToolbarActionEntry>[
        _ToolbarActionEntry(
          child: showSelectionSubToolbar
              ? buildSelectionSubToolbar(
                  context: context,
                  shellProvider: shellProvider,
                  appProvider: appProvider,
                  interactionProfile: interactionProfile,
                  horizontallyScrollable: true,
                  trailingToggleButton: selectorToggleButton,
                )
              : selectorToggleButton,
          estimatedWidth: showSelectionSubToolbar
              ? estimateSelectionSubToolbarWidth(
                  _toolbarIconActionEstimatedWidth,
                  hasVisibleSelection: appProvider.selectorModel.isVisible,
                  includeToggleButton: true,
                )
              : _toolbarIconActionEstimatedWidth,
          importance: _ToolbarActionImportance.critical,
        ),
      ],
      spacing: interactionProfile.buttonSpacing,
      minimumVisibleActions: AppMath.one,
      isHorizontallyScrollable: showSelectionSubToolbar,
      usesCustomSurface: showSelectionSubToolbar,
    ),
    _ToolbarActionGroup(
      actions: <_ToolbarActionEntry>[
        _ToolbarActionEntry(
          child: _buildZoomButton(
            key: Keys.floatActionZoomOut,
            shellProvider: shellProvider,
            appProvider: appProvider,
            interactionProfile: interactionProfile,
            tooltip: tooltipWithShortcut(
              ShortcutActions.zoomOut,
              primaryModifiedShortcut(ShortcutKeys.minus),
            )!,
            icon: AppIcon.zoomOut,
            scaleDelta: AppVisual.shrink,
          ),
          estimatedWidth: _toolbarIconActionEstimatedWidth,
          importance: _ToolbarActionImportance.medium,
        ),
        _ToolbarActionEntry(
          child: _buildCenterAndDimensionButton(shellProvider, appProvider),
          estimatedWidth: _toolbarCenterActionEstimatedWidth,
          importance: _ToolbarActionImportance.critical,
        ),
        _ToolbarActionEntry(
          child: _buildZoomButton(
            key: Keys.floatActionZoomIn,
            shellProvider: shellProvider,
            appProvider: appProvider,
            interactionProfile: interactionProfile,
            tooltip: tooltipWithShortcut(
              ShortcutActions.zoomIn,
              primaryModifiedShortcut(ShortcutKeys.plus),
            )!,
            icon: AppIcon.zoomIn,
            scaleDelta: AppVisual.enlarge,
          ),
          estimatedWidth: _toolbarIconActionEstimatedWidth,
          importance: _ToolbarActionImportance.medium,
        ),
      ],
      spacing: interactionProfile.buttonSpacing,
      minimumVisibleActions: AppMath.one,
    ),
  ];
}

/// Selects grouped toolbar domains and prunes only inside each domain when space is tight.
List<_ResolvedToolbarActionGroup> _selectResponsiveToolbarActionGroups({
  required final List<_ToolbarActionGroup> groups,
  required final double maxWidth,
  required final double groupSpacing,
}) {
  if (maxWidth <= AppMath.zero) {
    return const <_ResolvedToolbarActionGroup>[];
  }

  final List<List<_ToolbarActionEntry>> visibleActionsByGroup = groups
      .map<List<_ToolbarActionEntry>>(
        (final _ToolbarActionGroup group) => List<_ToolbarActionEntry>.from(group.actions),
      )
      .toList();

  double requiredWidth = _estimateToolbarGroupsWidth(
    groups: groups,
    visibleActionsByGroup: visibleActionsByGroup,
    groupSpacing: groupSpacing,
  );

  while (requiredWidth > maxWidth) {
    final _ToolbarActionRemovalCandidate? removalCandidate = _findLeastImportantResponsiveGroupAction(
      groups: groups,
      visibleActionsByGroup: visibleActionsByGroup,
    );
    if (removalCandidate == null) {
      break;
    }

    visibleActionsByGroup[removalCandidate.groupIndex].removeAt(removalCandidate.actionIndex);
    requiredWidth = _estimateToolbarGroupsWidth(
      groups: groups,
      visibleActionsByGroup: visibleActionsByGroup,
      groupSpacing: groupSpacing,
    );
  }

  final List<_ResolvedToolbarActionGroup> resolvedGroups = <_ResolvedToolbarActionGroup>[];
  for (int index = AppMath.zero; index < groups.length; index++) {
    final List<_ToolbarActionEntry> visibleActions = visibleActionsByGroup[index];
    if (visibleActions.isEmpty) {
      continue;
    }

    resolvedGroups.add(
      _ResolvedToolbarActionGroup(
        actions: visibleActions,
        spacing: groups[index].spacing,
        isHorizontallyScrollable: groups[index].isHorizontallyScrollable,
        usesCustomSurface: groups[index].usesCustomSurface,
      ),
    );
  }

  return resolvedGroups;
}

/// Estimates the total width of the currently visible grouped toolbar domains.
double _estimateToolbarGroupsWidth({
  required final List<_ToolbarActionGroup> groups,
  required final List<List<_ToolbarActionEntry>> visibleActionsByGroup,
  required final double groupSpacing,
}) {
  double requiredWidth = AppMath.zero.toDouble();
  int visibleGroupCount = AppMath.zero;

  for (int index = AppMath.zero; index < groups.length; index++) {
    final List<_ToolbarActionEntry> visibleActions = visibleActionsByGroup[index];
    if (visibleActions.isEmpty) {
      continue;
    }

    requiredWidth += _estimateToolbarGroupWidth(
      group: groups[index],
      actions: visibleActions,
      spacing: groups[index].spacing,
    );
    if (visibleGroupCount > AppMath.zero) {
      requiredWidth += groupSpacing;
    }
    visibleGroupCount++;
  }

  return requiredWidth;
}

/// Estimates one grouped toolbar domain including its shared surface padding.
double _estimateToolbarGroupWidth({
  required final _ToolbarActionGroup group,
  required final List<_ToolbarActionEntry> actions,
  required final double spacing,
}) {
  if (actions.isEmpty) {
    return AppMath.zero.toDouble();
  }

  if (group.isHorizontallyScrollable) {
    return AppMath.zero.toDouble();
  }

  return _estimateToolbarActionWidth(actions, spacing) + _toolbarGroupHorizontalPadding;
}

/// Finds the next removable action while preserving at least one action in required groups.
_ToolbarActionRemovalCandidate? _findLeastImportantResponsiveGroupAction({
  required final List<_ToolbarActionGroup> groups,
  required final List<List<_ToolbarActionEntry>> visibleActionsByGroup,
}) {
  _ToolbarActionRemovalCandidate? removalCandidate;

  for (int groupIndex = visibleActionsByGroup.length - AppMath.one; groupIndex >= AppMath.zero; groupIndex--) {
    final List<_ToolbarActionEntry> visibleActions = visibleActionsByGroup[groupIndex];
    if (visibleActions.length <= groups[groupIndex].minimumVisibleActions) {
      continue;
    }

    final int actionIndex = _indexOfLeastImportantAction(visibleActions);
    if (actionIndex < AppMath.zero) {
      continue;
    }

    final _ToolbarActionEntry action = visibleActions[actionIndex];
    if (removalCandidate == null || action.importance.index > removalCandidate.action.importance.index) {
      removalCandidate = _ToolbarActionRemovalCandidate(
        groupIndex: groupIndex,
        actionIndex: actionIndex,
        action: action,
      );
    }
  }

  return removalCandidate;
}
