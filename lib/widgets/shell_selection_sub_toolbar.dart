import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/shortcut_tooltip.dart';
import 'package:fpaint/helpers/shortcuts_constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/selector_mode_display.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/tool_kind.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/effect_preview_bottom_sheet.dart';
import 'package:fpaint/widgets/locked_layer_guard.dart';
import 'package:fpaint/widgets/overlay_control_widgets.dart';
import 'package:fpaint/widgets/toolbar_icon_button.dart';

/// Widget keys for the selection-mode buttons, in [SelectorMode] order.
const Map<SelectorMode, Key> _selectorModeKeys = <SelectorMode, Key>{
  SelectorMode.rectangle: Keys.toolSelectorModeRectangle,
  SelectorMode.circle: Keys.toolSelectorModeCircle,
  SelectorMode.line: Keys.toolSelectorModeLine,
  SelectorMode.lasso: Keys.toolSelectorModeLasso,
  SelectorMode.brush: Keys.toolSelectorModeBrush,
  SelectorMode.wand: Keys.toolSelectorModeWand,
};

final int _selectionModeButtonCount = SelectorMode.values.length;
const int _selectionScopeButtonCount = AppMath.one;
const int _selectionClipboardButtonCount = AppMath.pair;
const int _selectionMathButtonCount = AppMath.triple;
const int _selectionInvertButtonCount = AppMath.one;
const int _selectionCanvasActionButtonCount = AppMath.one;
const int _selectionEffectsButtonCount = AppMath.one;
const int _selectionToggleButtonCount = AppMath.one;

/// Returns whether the shell should show a dedicated selection sub-toolbar.
bool shouldShowSelectionSubToolbar(AppProvider appProvider) {
  return appProvider.selectedTool == ToolKind.selector || appProvider.selectorModel.isVisible;
}

/// Estimates the width needed by the selection sub-toolbar.
double estimateSelectionSubToolbarWidth(
  double toolbarIconActionEstimatedWidth, {
  required bool hasVisibleSelection,
  bool includeToggleButton = false,
}) {
  int totalButtons = _selectionModeButtonCount + _selectionScopeButtonCount;

  if (hasVisibleSelection) {
    totalButtons +=
        _selectionClipboardButtonCount +
        _selectionMathButtonCount +
        _selectionInvertButtonCount +
        _selectionCanvasActionButtonCount +
        _selectionEffectsButtonCount;
  }

  if (includeToggleButton) {
    totalButtons += _selectionToggleButtonCount;
  }

  return (totalButtons * toolbarIconActionEstimatedWidth) + ((totalButtons - AppMath.one) * AppSpacing.small);
}

/// Builds the selection-focused sub-toolbar embedded in the top shell toolbar.
Widget buildSelectionSubToolbar({
  required BuildContext context,
  required ShellProvider shellProvider,
  required AppProvider appProvider,
  required InteractionLayoutProfile interactionProfile,
  bool horizontallyScrollable = false,
  Widget? trailingToggleButton,
}) {
  final AppLocalizations l10n = context.l10n;
  final bool hasVisibleSelection = appProvider.selectorModel.isVisible;
  final bool isSelectionToolActive = appProvider.selectedTool == ToolKind.selector;

  final List<Widget> buttons = <Widget>[
    for (final SelectorMode mode in SelectorMode.values)
      buildToolbarIconButton(
        key: _selectorModeKeys[mode],
        tooltip: mode.label(l10n),
        icon: mode.icon,
        interactionProfile: interactionProfile,
        isSelected: isSelectionToolActive && appProvider.selectorModel.mode == mode,
        onPressed: () {
          Future<void>.microtask(() => appProvider.activateSelectorMode(mode));
        },
      ),
  ];

  if (hasVisibleSelection) {
    buttons.addAll(<Widget>[
      buildToolbarIconButton(
        key: Keys.toolSelectorCopy,
        tooltip: tooltipWithShortcut(
          l10n.copyToClipboard,
          primaryModifiedShortcut(ShortcutKeys.c),
        ),
        icon: AppIcon.clipboardCopy,
        interactionProfile: interactionProfile,
        color: AppColors.textPrimary,
        onPressed: () {
          Future<void>.microtask(() => appProvider.regionCopy());
        },
      ),
      buildToolbarIconButton(
        key: Keys.toolSelectorCut,
        tooltip: tooltipWithShortcut(
          l10n.cut,
          primaryModifiedShortcut(ShortcutKeys.x),
        ),
        icon: AppIcon.cropFree,
        interactionProfile: interactionProfile,
        color: AppColors.textPrimary,
        onPressed: () {
          Future<void>.microtask(() => appProvider.regionCut());
        },
      ),
      // Add and Subtract are mutually-exclusive toggles. With both off the
      // selection replaces the previous one ("New"); enabling one turns the
      // other off, and tapping the active toggle returns to replace.
      buildToolbarIconButton(
        tooltip: tooltipWithShortcut(l10n.toolAdd, shiftModifierShortcutLabel()),
        icon: AppIcon.selectorMathAdd,
        interactionProfile: interactionProfile,
        isSelected: appProvider.selectorModel.math == SelectorMath.add,
        onPressed: () {
          Future<void>.microtask(() => appProvider.toggleSelectorMath(SelectorMath.add));
        },
      ),
      buildToolbarIconButton(
        tooltip: tooltipWithShortcut(l10n.toolRemove, secondaryModifierShortcutLabel()),
        icon: AppIcon.selectorMathRemove,
        interactionProfile: interactionProfile,
        isSelected: appProvider.selectorModel.math == SelectorMath.remove,
        onPressed: () {
          Future<void>.microtask(() => appProvider.toggleSelectorMath(SelectorMath.remove));
        },
      ),
      buildToolbarIconButton(
        tooltip: l10n.toolInvert,
        icon: AppIcon.selectorMathInvert,
        interactionProfile: interactionProfile,
        onPressed: () {
          Future<void>.microtask(appProvider.invertSelection);
        },
      ),
      buildToolbarIconButton(
        tooltip: l10n.toolCrop,
        icon: AppIcon.canvasCrop,
        interactionProfile: interactionProfile,
        onPressed: () {
          Future<void>.microtask(() {
            shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
            shellProvider.update();
            appProvider.crop();
            appProvider.update();
          });
        },
      ),
      _SelectionEffectsToolbarButton(
        appProvider: appProvider,
        interactionProfile: interactionProfile,
        l10n: l10n,
      ),
    ]);
  }

  if (trailingToggleButton != null) {
    buttons.add(trailingToggleButton);
  }

  final Widget buttonRow = Row(
    mainAxisSize: MainAxisSize.min,
    spacing: AppSpacing.small,
    children: buttons,
  );

  return buildOverlayControlSurface(
    child: horizontallyScrollable
        ? SingleChildScrollView(
            primary: false,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.hardEdge,
            child: buttonRow,
          )
        : buttonRow,
  );
}

/// Toolbar button that opens a selection effects menu anchored to itself.
class _SelectionEffectsToolbarButton extends StatefulWidget {
  const _SelectionEffectsToolbarButton({
    required this.appProvider,
    required this.interactionProfile,
    required this.l10n,
  });

  final AppProvider appProvider;
  final InteractionLayoutProfile interactionProfile;
  final AppLocalizations l10n;

  @override
  State<_SelectionEffectsToolbarButton> createState() => _SelectionEffectsToolbarButtonState();
}

class _SelectionEffectsToolbarButtonState extends State<_SelectionEffectsToolbarButton> {
  @override
  Widget build(BuildContext context) {
    return buildToolbarIconButton(
      key: Keys.effectsButton,
      tooltip: widget.l10n.effects,
      icon: AppIcon.autoFixHigh,
      interactionProfile: widget.interactionProfile,
      onPressed: () => _showSelectionEffectsMenu(
        context: context,
        appProvider: widget.appProvider,
        l10n: widget.l10n,
      ),
    );
  }
}

/// Opens an effects menu for the active selection and starts previewing the chosen effect.
void _showSelectionEffectsMenu({
  required BuildContext context,
  required AppProvider appProvider,
  required AppLocalizations l10n,
}) {
  showSelectionEffectsMenu(context, l10n).then((SelectionEffect? selected) {
    if (selected == null) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    if (!guardSelectedLayerUnlocked(context, appProvider)) {
      return;
    }

    final SelectionEffect? current = appProvider.effectPreviewModel.effect;
    final bool hasPreview = appProvider.effectPreviewModel.isVisible;
    if (hasPreview && current == selected) {
      appProvider.cancelEffectPreview();
      return;
    }

    startEffectPreviewWithBottomSheet(
      context,
      appProvider: appProvider,
      l10n: l10n,
      effect: selected,
    );
  });
}
