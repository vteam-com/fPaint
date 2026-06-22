import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/effect_labels.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/effect_preview_bottom_sheet.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/overlay_control_widgets.dart';
import 'package:fpaint/widgets/toolbar_icon_button.dart';

const int _selectionModeButtonCount = AppMath.four + AppMath.one;
const int _selectionVisibleActionsCount = AppMath.six;
const int _selectionMathButtonCount = AppMath.triple;
const int _selectionCanvasActionButtonCount = AppMath.pair;
const int _selectionEffectsButtonCount = AppMath.one;
const int _selectionToggleButtonCount = AppMath.one;

/// Returns whether the shell should show a dedicated selection sub-toolbar.
bool shouldShowSelectionSubToolbar(final AppProvider appProvider) {
  return appProvider.selectedAction == ActionType.selector || appProvider.selectorModel.isVisible;
}

/// Estimates the width needed by the selection sub-toolbar.
double estimateSelectionSubToolbarWidth(
  final double toolbarIconActionEstimatedWidth, {
  final bool includeToggleButton = false,
}) {
  final int totalButtons =
      _selectionModeButtonCount +
      _selectionVisibleActionsCount +
      _selectionMathButtonCount +
      _selectionCanvasActionButtonCount +
      _selectionEffectsButtonCount +
      (includeToggleButton ? _selectionToggleButtonCount : AppMath.zero);

  return (totalButtons * toolbarIconActionEstimatedWidth) + ((totalButtons - AppMath.one) * AppSpacing.small);
}

/// Builds the selection-focused sub-toolbar embedded in the top shell toolbar.
Widget buildSelectionSubToolbar({
  required final BuildContext context,
  required final ShellProvider shellProvider,
  required final AppProvider appProvider,
  required final InteractionLayoutProfile interactionProfile,
  final Widget? trailingToggleButton,
}) {
  final AppLocalizations l10n = context.l10n;
  final bool hasVisibleSelection = appProvider.selectorModel.isVisible;
  final bool isSelectionToolActive = appProvider.selectedAction == ActionType.selector;

  final List<Widget> buttons = <Widget>[
    buildToolbarIconButton(
      key: Keys.toolSelectorModeRectangle,
      tooltip: l10n.toolRectangle,
      icon: AppIcon.selectorSquare,
      interactionProfile: interactionProfile,
      isSelected: isSelectionToolActive && appProvider.selectorModel.mode == SelectorMode.rectangle,
      onPressed: () {
        Future<void>.microtask(() {
          appProvider.activateSelectionAction();
          appProvider.setSelectorMode(SelectorMode.rectangle);
        });
      },
    ),
    buildToolbarIconButton(
      key: Keys.toolSelectorModeCircle,
      tooltip: l10n.toolCircle,
      icon: AppIcon.selectorCircle,
      interactionProfile: interactionProfile,
      isSelected: isSelectionToolActive && appProvider.selectorModel.mode == SelectorMode.circle,
      onPressed: () {
        Future<void>.microtask(() {
          appProvider.activateSelectionAction();
          appProvider.setSelectorMode(SelectorMode.circle);
        });
      },
    ),
    buildToolbarIconButton(
      key: Keys.toolSelectorModeLine,
      tooltip: l10n.toolLine,
      icon: AppIcon.selectorPolygon,
      interactionProfile: interactionProfile,
      isSelected: isSelectionToolActive && appProvider.selectorModel.mode == SelectorMode.line,
      onPressed: () {
        Future<void>.microtask(() {
          appProvider.activateSelectionAction();
          appProvider.setSelectorMode(SelectorMode.line);
        });
      },
    ),
    buildToolbarIconButton(
      key: Keys.toolSelectorModeLasso,
      tooltip: l10n.toolLasso,
      icon: AppIcon.selectorLasso,
      interactionProfile: interactionProfile,
      isSelected: isSelectionToolActive && appProvider.selectorModel.mode == SelectorMode.lasso,
      onPressed: () {
        Future<void>.microtask(() {
          appProvider.activateSelectionAction();
          appProvider.setSelectorMode(SelectorMode.lasso);
        });
      },
    ),
    buildToolbarIconButton(
      key: Keys.toolSelectorModeWand,
      tooltip: l10n.toolMagic,
      icon: AppIcon.selectorWand,
      interactionProfile: interactionProfile,
      isSelected: isSelectionToolActive && appProvider.selectorModel.mode == SelectorMode.wand,
      onPressed: () {
        Future<void>.microtask(() {
          appProvider.activateSelectionAction();
          appProvider.setSelectorMode(SelectorMode.wand);
        });
      },
    ),
  ];

  if (hasVisibleSelection) {
    buttons.addAll(<Widget>[
      buildToolbarIconButton(
        key: Keys.toolSelectorCopy,
        tooltip: l10n.copyToClipboard,
        icon: AppIcon.clipboardCopy,
        interactionProfile: interactionProfile,
        color: AppColors.textPrimary,
        onPressed: () {
          Future<void>.microtask(() => appProvider.regionCopy());
        },
      ),
      buildToolbarIconButton(
        key: Keys.toolSelectorCut,
        tooltip: l10n.cut,
        icon: ActionType.cut.icon,
        interactionProfile: interactionProfile,
        color: AppColors.textPrimary,
        onPressed: () {
          Future<void>.microtask(() => appProvider.regionCut());
        },
      ),
      buildToolbarIconButton(
        tooltip: l10n.toolReplace,
        icon: AppIcon.selectorMathReplace,
        interactionProfile: interactionProfile,
        isSelected: appProvider.selectorModel.math == SelectorMath.replace,
        onPressed: () {
          Future<void>.microtask(() => appProvider.setSelectorMath(SelectorMath.replace));
        },
      ),
      buildToolbarIconButton(
        tooltip: l10n.toolAdd,
        icon: AppIcon.selectorMathAdd,
        interactionProfile: interactionProfile,
        isSelected: appProvider.selectorModel.math == SelectorMath.add,
        onPressed: () {
          Future<void>.microtask(() => appProvider.setSelectorMath(SelectorMath.add));
        },
      ),
      buildToolbarIconButton(
        tooltip: l10n.toolRemove,
        icon: AppIcon.selectorMathRemove,
        interactionProfile: interactionProfile,
        isSelected: appProvider.selectorModel.math == SelectorMath.remove,
        onPressed: () {
          Future<void>.microtask(() => appProvider.setSelectorMath(SelectorMath.remove));
        },
      ),
      buildToolbarIconButton(
        tooltip: l10n.toolInvert,
        icon: AppIcon.selectorMathInvert,
        interactionProfile: interactionProfile,
        onPressed: () {
          Future<void>.microtask(() {
            appProvider.selectorModel.invert(
              Rect.fromLTWH(
                AppMath.zero.toDouble(),
                AppMath.zero.toDouble(),
                appProvider.layers.size.width,
                appProvider.layers.size.height,
              ),
            );
            appProvider.update();
          });
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

  return buildOverlayControlSurface(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.small,
      children: buttons,
    ),
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
  Widget build(final BuildContext context) {
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
  required final BuildContext context,
  required final AppProvider appProvider,
  required final AppLocalizations l10n,
}) {
  final RenderBox button = context.findRenderObject()! as RenderBox;
  final Offset offset = button.localToGlobal(
    Offset(button.size.width / AppMath.pair, button.size.height),
  );

  showAppMenu<SelectionEffect>(
    context: context,
    position: RelativeRect.fromLTRB(
      offset.dx,
      offset.dy,
      offset.dx,
      offset.dy,
    ),
    items: SelectionEffect.values
        .map(
          (final SelectionEffect effect) => AppPopupMenuItem<SelectionEffect>(
            value: effect,
            child: Row(
              spacing: AppSpacing.medium,
              children: <Widget>[
                AppSvgIcon(
                  icon: effect.icon,
                  size: AppLayout.iconSize,
                ),
                AppText(effectLabel(l10n, effect)),
              ],
            ),
          ),
        )
        .toList(),
  ).then((final SelectionEffect? selected) {
    if (selected == null) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    if (appProvider.isSelectedLayerLocked) {
      context.showSnackBarMessage(
        l10n.layerLockedForEditing(appProvider.layers.selectedLayer.name),
      );
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
