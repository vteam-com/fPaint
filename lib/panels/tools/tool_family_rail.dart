import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/effect_labels.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/tool_descriptor.dart';
import 'package:fpaint/models/tool_family.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/widgets/app_buttons.dart';
import 'package:fpaint/widgets/app_divider.dart';
import 'package:fpaint/widgets/app_slider.dart';
import 'package:fpaint/widgets/app_snackbar.dart';
import 'package:fpaint/widgets/effect_intensity_controls.dart';
import 'package:fpaint/widgets/side_panel_header.dart';

/// The unified tool rail: gesture tools and region adjustments grouped into
/// the Draw, Retouch, and Adjust families.
///
/// Draw and Retouch select an [ActionType] to apply by gesture; Adjust starts
/// a live effect preview. [gestureParams] holds the parameter controls for the
/// currently selected gesture tool and is placed between the gesture families
/// and Adjust so a tool's options sit directly beneath it.
class ToolFamilyRail extends StatelessWidget {
  const ToolFamilyRail({
    super.key,
    required this.minimal,
    this.gestureParams,
  });

  /// Parameter controls for the currently selected gesture tool.
  final Widget? gestureParams;

  /// Whether the rail is rendered in the compact (minimal) layout.
  final bool minimal;
  @override
  Widget build(final BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ListenableBuilder(
          listenable: appProvider.selectedActionRepaintListenable,
          builder: (final BuildContext context, final Widget? _) {
            return _gestureFamily(context, appProvider, ToolFamily.draw);
          },
        ),
        ?gestureParams,
        ListenableBuilder(
          listenable: appProvider.toolOptionsRepaintListenable,
          builder: (final BuildContext _, final Widget? _) {
            return _AdjustFamily(minimal: minimal, appProvider: appProvider);
          },
        ),
      ],
    );
  }

  /// Builds a titled group of gesture-tool buttons for [family].
  Widget _gestureFamily(
    final BuildContext context,
    final AppProvider appProvider,
    final ToolFamily family,
  ) {
    final AppLocalizations l10n = context.l10n;

    return _railSection(
      title: toolFamilyLabel(l10n, family),
      child: Wrap(
        spacing: minimal ? AppSpacing.thin : AppSpacing.small,
        runSpacing: minimal ? AppSpacing.thin : AppSpacing.small,
        alignment: WrapAlignment.center,
        children: <Widget>[
          for (final ToolDescriptor descriptor in toolsInFamily(family))
            AppButtonIcon(
              key: _gestureToolKey(descriptor.action!),
              icon: descriptor.icon,
              isSelected: appProvider.selectedAction == descriptor.action,
              tooltip: descriptor.label(l10n),
              constraints: minimal ? const BoxConstraints() : null,
              padding: EdgeInsets.all(minimal ? AppSpacing.thin : AppSpacing.small),
              onPressed: () => appProvider.selectedAction = descriptor.action!,
            ),
        ],
      ),
    );
  }

  /// Preserves the widget keys existing tests tap; tools without a prior key
  /// (pencil, brush, eraser) keep none.
  static Key? _gestureToolKey(final ActionType action) {
    switch (action) {
      case ActionType.smudge:
        return Keys.toolSmudge;
      case ActionType.blurBrush:
        return Keys.toolBlurBrush;
      case ActionType.line:
        return Keys.toolLine;
      case ActionType.rectangle:
        return Keys.toolRectangle;
      case ActionType.circle:
        return Keys.toolCircle;
      case ActionType.fill:
        return Keys.toolFill;
      case ActionType.text:
        return Keys.toolText;
      case ActionType.pencil:
      case ActionType.brush:
      case ActionType.eraser:
      case ActionType.region:
      case ActionType.image:
      case ActionType.cut:
      case ActionType.selector:
        return null;
    }
  }

  /// Wraps [child] in a padded section headed by [title].
  Widget _railSection({
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
          SidePanelHeader(title: title, padding: EdgeInsets.zero),
          const SizedBox(height: AppSpacing.small),
          child,
        ],
      ),
    );
  }
}

/// The Adjust family: region-effect buttons plus the live preview controls.
class _AdjustFamily extends StatelessWidget {
  const _AdjustFamily({
    required this.minimal,
    required this.appProvider,
  });
  final AppProvider appProvider;
  final bool minimal;
  @override
  Widget build(final BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool paintMode = appProvider.effectBrushModel.paintMode;
    final SelectionEffect? selectedEffect = paintMode
        ? appProvider.effectBrushModel.effect
        : appProvider.effectPreviewModel.effect;
    final bool hasPreview = appProvider.effectPreviewModel.isVisible;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.small,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: SidePanelHeader(
                  title: toolFamilyLabel(l10n, ToolFamily.adjust),
                  padding: EdgeInsets.zero,
                ),
              ),
              AppButtonIcon(
                key: Keys.effectPaintModeToggle,
                icon: AppIcon.brush,
                isSelected: paintMode,
                tooltip: l10n.paint,
                constraints: minimal ? const BoxConstraints() : null,
                padding: EdgeInsets.all(minimal ? AppSpacing.thin : AppSpacing.small),
                onPressed: () => appProvider.setEffectPaintMode(enabled: !paintMode),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.small),
          Wrap(
            spacing: minimal ? AppSpacing.thin : AppSpacing.small,
            runSpacing: minimal ? AppSpacing.thin : AppSpacing.small,
            alignment: WrapAlignment.center,
            children: <Widget>[
              for (final ToolDescriptor descriptor in toolsInFamily(ToolFamily.adjust))
                AppButtonIcon(
                  key: ValueKey<SelectionEffect>(descriptor.effect!),
                  icon: descriptor.icon,
                  isSelected: selectedEffect == descriptor.effect,
                  tooltip: descriptor.label(l10n),
                  constraints: minimal ? const BoxConstraints() : null,
                  padding: EdgeInsets.all(minimal ? AppSpacing.thin : AppSpacing.small),
                  onPressed: () => _onEffectPressed(
                    context,
                    l10n,
                    descriptor.effect!,
                    selectedEffect,
                    hasPreview: hasPreview,
                    paintMode: paintMode,
                  ),
                ),
            ],
          ),
          if (!paintMode && hasPreview) const AppDivider(),
          if (!paintMode && hasPreview)
            EffectIntensityControls(
              key: ValueKey<SelectionEffect?>(selectedEffect),
              appProvider: appProvider,
              l10n: l10n,
              sliderKey: Keys.effectIntensitySlider,
              applyButtonKey: Keys.effectIntensityPanelApplyButton,
              cancelButtonKey: Keys.effectIntensityCancelButton,
            ),
          if (paintMode && selectedEffect != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.small),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppSlider(
                    key: Keys.effectPaintSizeSlider,
                    label: l10n.brushSize,
                    value: appProvider.brushSize,
                    valueLabel: appProvider.brushSize.toStringAsFixed(AppMath.zero),
                    min: AppInteraction.minCanvasScale,
                    max: AppLimits.pixelBrushSizeMax.toDouble(),
                    onChanged: (final double value) => appProvider.brushSize = value,
                  ),
                  AppSlider(
                    key: Keys.effectPaintStrengthSlider,
                    label: effectLabel(l10n, selectedEffect),
                    value: appProvider.effectBrushModel.strength,
                    valueLabel: '${(appProvider.effectBrushModel.strength * AppMath.percentScale).round()}%',
                    min: AppEffects.minIntensity,
                    max: AppEffects.maxIntensity,
                    onChanged: (final double value) => appProvider.setEffectBrushStrength(value),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Handles an effect button tap. In Paint mode it arms/disarms the effect for
  /// brushing; otherwise it toggles the whole-region Apply preview.
  Future<void> _onEffectPressed(
    final BuildContext context,
    final AppLocalizations l10n,
    final SelectionEffect effect,
    final SelectionEffect? selectedEffect, {
    required final bool hasPreview,
    required final bool paintMode,
  }) async {
    if (paintMode) {
      if (selectedEffect == effect) {
        appProvider.disarmEffectBrush();
      } else {
        appProvider.armEffectBrush(effect);
      }
      return;
    }

    if (hasPreview && selectedEffect == effect) {
      appProvider.cancelEffectPreview();
      return;
    }

    if (appProvider.isSelectedLayerLocked) {
      context.showSnackBarMessage(
        l10n.layerLockedForEditing(appProvider.layers.selectedLayer.name),
      );
      return;
    }

    await appProvider.startEffectPreview(effect);
  }
}
