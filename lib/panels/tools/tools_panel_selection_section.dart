part of 'tools_panel.dart';

extension _ToolsPanelSelectionSection on ToolsPanel {
  /// Builds a titled panel block used by the side tools panel.
  Widget _buildPanelSection({
    required final String title,
    required final Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.small,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SidePanelHeader(
            title: title,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: AppSpacing.small),
          child,
        ],
      ),
    );
  }

  /// Builds the selection-tools row and its mode-specific controls.
  Widget _buildSelectionSection({
    required final BuildContext context,
    required final AppProvider appProvider,
  }) {
    final AppLocalizations l10n = context.l10n;
    final LayersProvider layers = LayersProvider.of(context);
    final bool selectorIsActive = appProvider.selectedAction == ActionType.selector;
    final List<Widget> topRowButtons = <Widget>[
      KeyedSubtree(
        key: Keys.toolSelector,
        child: _buildActionPicker(
          key: Keys.toolSelectorModeRectangle,
          minimal: minimal,
          name: l10n.toolRectangle,
          icon: AppIcon.selectorSquare,
          isSelected: selectorIsActive && appProvider.selectorModel.mode == SelectorMode.rectangle,
          onPressed: () {
            appProvider.activateSelectionAction();
            appProvider.setSelectorMode(SelectorMode.rectangle);
          },
        ),
      ),
      _buildActionPicker(
        key: Keys.toolSelectorModeCircle,
        minimal: minimal,
        name: l10n.toolCircle,
        icon: AppIcon.selectorCircle,
        isSelected: selectorIsActive && appProvider.selectorModel.mode == SelectorMode.circle,
        onPressed: () {
          appProvider.activateSelectionAction();
          appProvider.setSelectorMode(SelectorMode.circle);
        },
      ),
      _buildActionPicker(
        key: Keys.toolSelectorModeLine,
        minimal: minimal,
        name: l10n.toolLine,
        icon: AppIcon.selectorPolygon,
        isSelected: selectorIsActive && appProvider.selectorModel.mode == SelectorMode.line,
        onPressed: () {
          appProvider.activateSelectionAction();
          appProvider.setSelectorMode(SelectorMode.line);
        },
      ),
      _buildActionPicker(
        key: Keys.toolSelectorModeLasso,
        minimal: minimal,
        name: l10n.toolLasso,
        icon: AppIcon.lasso,
        isSelected: selectorIsActive && appProvider.selectorModel.mode == SelectorMode.lasso,
        onPressed: () {
          appProvider.activateSelectionAction();
          appProvider.setSelectorMode(SelectorMode.lasso);
        },
      ),
      _buildActionPicker(
        key: Keys.toolSelectorModeWand,
        minimal: minimal,
        name: l10n.toolMagic,
        icon: AppIcon.autoFixHigh,
        isSelected: selectorIsActive && appProvider.selectorModel.mode == SelectorMode.wand,
        onPressed: () {
          appProvider.activateSelectionAction();
          appProvider.setSelectorMode(SelectorMode.wand);
        },
      ),
    ];
    final List<Widget> content = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Wrap(
              spacing: minimal ? AppSpacing.thin : AppSpacing.small,
              runSpacing: minimal ? AppSpacing.thin : AppSpacing.small,
              alignment: WrapAlignment.start,
              children: topRowButtons,
            ),
          ),
          if (appProvider.selectorModel.isVisible) ...<Widget>[
            const SizedBox(width: AppSpacing.small),
            _buildActionPicker(
              key: Keys.toolSelectorCancel,
              minimal: minimal,
              name: l10n.cancel,
              icon: AppIcon.selectorCancel,
              color: AppColors.layerHiddenWarning,
              onPressed: () {
                appProvider.clearSelectionAndRestorePreviousTool();
              },
            ),
          ],
        ],
      ),
    ];

    if (appProvider.selectorModel.mode == SelectorMode.wand) {
      content.add(addToolOptionTolerance(context, appProvider));
    }

    if (appProvider.selectorModel.isVisible) {
      content.addAll(<Widget>[
        const AppDivider(),
        Wrap(
          spacing: minimal ? AppSpacing.thin : AppSpacing.small,
          runSpacing: minimal ? AppSpacing.thin : AppSpacing.small,
          alignment: WrapAlignment.center,
          children: <Widget>[
            _buildActionPicker(
              key: Keys.toolSelectorCopy,
              minimal: minimal,
              name: l10n.copyToClipboard,
              icon: AppIcon.clipboardCopy,
              color: AppColors.textPrimary,
              onPressed: () => appProvider.regionCopy(),
            ),
            _buildActionPicker(
              key: Keys.toolSelectorCut,
              minimal: minimal,
              name: l10n.cut,
              icon: ActionType.cut.icon,
              color: AppColors.textPrimary,
              onPressed: () => appProvider.regionCut(),
            ),
          ],
        ),
        const AppDivider(),
        Wrap(
          spacing: minimal ? AppSpacing.thin : AppSpacing.small,
          runSpacing: minimal ? AppSpacing.thin : AppSpacing.small,
          alignment: WrapAlignment.center,
          children: <Widget>[
            _buildActionPicker(
              minimal: minimal,
              name: l10n.toolReplace,
              icon: AppIcon.selectorReplace,
              isSelected: appProvider.selectorModel.math == SelectorMath.replace,
              onPressed: () {
                appProvider.setSelectorMath(SelectorMath.replace);
              },
            ),
            _buildActionPicker(
              minimal: minimal,
              name: l10n.toolAdd,
              icon: AppIcon.selectorAdd,
              isSelected: appProvider.selectorModel.math == SelectorMath.add,
              onPressed: () {
                appProvider.setSelectorMath(SelectorMath.add);
              },
            ),
            _buildActionPicker(
              minimal: minimal,
              name: l10n.toolRemove,
              icon: AppIcon.selectorRemove,
              isSelected: appProvider.selectorModel.math == SelectorMath.remove,
              onPressed: () {
                appProvider.setSelectorMath(SelectorMath.remove);
              },
            ),
          ],
        ),
        const AppDivider(),
        Wrap(
          spacing: minimal ? AppSpacing.thin : AppSpacing.small,
          runSpacing: minimal ? AppSpacing.thin : AppSpacing.small,
          alignment: WrapAlignment.center,
          children: <Widget>[
            _buildActionPicker(
              minimal: minimal,
              name: l10n.toolInvert,
              icon: AppIcon.selectorInvert,
              onPressed: () {
                appProvider.selectorModel.invert(
                  Rect.fromLTWH(
                    0,
                    0,
                    layers.size.width,
                    layers.size.height,
                  ),
                );
                appProvider.update();
              },
            ),
            _buildActionPicker(
              minimal: minimal,
              name: l10n.toolCrop,
              icon: AppIcon.canvasCrop,
              onPressed: () {
                final ShellProvider shellProvider = ShellProvider.of(context);
                shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
                shellProvider.update();

                appProvider.crop();
                appProvider.update();
              },
            ),
          ],
        ),
        const AppDivider(),
        _EffectsSection(
          minimal: minimal,
          l10n: l10n,
          appProvider: appProvider,
        ),
      ]);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: content,
    );
  }
}
