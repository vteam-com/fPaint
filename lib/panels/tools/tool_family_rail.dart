import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/effect_labels.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/tool_descriptor.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/widgets/app_buttons.dart';
import 'package:fpaint/widgets/app_slider.dart';
import 'package:fpaint/widgets/side_panel_header.dart';

/// The unified tool rail: every pixel-changing tool in one Brush section.
///
/// Gesture tools (pencil, brush, smudge, shapes, fill, eraser, text) and
/// effects (blur, sharpness, brightness, …) share a single flat grid, because
/// an effect is just a brush too — tapping one arms it as a brush and you paint
/// it on. Exactly one tool is active at a time: arming an effect deselects the
/// gesture tool and swaps [gestureParams] for the effect's brush controls (size
/// and strength), and picking a gesture tool disarms the effect.
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

    return ListenableBuilder(
      // Rebuild on tool change AND on effect arm/disarm + strength changes, so
      // the selection highlight and the options panel always reflect the single
      // active tool.
      listenable: Listenable.merge(<Listenable>[
        appProvider.selectedActionRepaintListenable,
        appProvider.toolOptionsRepaintListenable,
      ]),
      builder: (final BuildContext context, final Widget? _) {
        return _brushSection(context, appProvider);
      },
    );
  }

  /// Builds the single Brush section: the flat tool grid plus the controls for
  /// whichever tool is active (gesture params, or the armed effect's controls).
  Widget _brushSection(final BuildContext context, final AppProvider appProvider) {
    final AppLocalizations l10n = context.l10n;
    final SelectionEffect? armedEffect = appProvider.effectBrushModel.effect;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.small,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SidePanelHeader(title: l10n.toolSectionBrush, padding: EdgeInsets.zero),
          const SizedBox(height: AppSpacing.small),
          Wrap(
            spacing: minimal ? AppSpacing.thin : AppSpacing.small,
            runSpacing: minimal ? AppSpacing.thin : AppSpacing.small,
            alignment: WrapAlignment.center,
            children: <Widget>[
              for (final ToolDescriptor descriptor in toolRail())
                _toolButton(l10n, appProvider, descriptor, armedEffect),
            ],
          ),
          if (armedEffect == null && gestureParams != null) gestureParams!,
          if (armedEffect != null) _effectControls(l10n, appProvider, armedEffect),
        ],
      ),
    );
  }

  /// Brush controls for the [armedEffect]: brush size and strength. The effect
  /// is applied by painting it onto the canvas.
  Widget _effectControls(
    final AppLocalizations l10n,
    final AppProvider appProvider,
    final SelectionEffect armedEffect,
  ) {
    return Padding(
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
            label: effectLabel(l10n, armedEffect),
            value: appProvider.effectBrushModel.strength,
            valueLabel: '${(appProvider.effectBrushModel.strength * AppMath.percentScale).round()}%',
            min: armedEffect.bipolar ? -AppEffects.maxIntensity : AppEffects.minIntensity,
            max: AppEffects.maxIntensity,
            onChanged: (final double value) => appProvider.setEffectBrushStrength(value),
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

  /// A single rail button: a gesture tool that sets the active action, or an
  /// effect that arms/disarms itself as a brush.
  Widget _toolButton(
    final AppLocalizations l10n,
    final AppProvider appProvider,
    final ToolDescriptor descriptor,
    final SelectionEffect? armedEffect,
  ) {
    final EdgeInsets padding = EdgeInsets.all(minimal ? AppSpacing.thin : AppSpacing.small);
    final BoxConstraints? constraints = minimal ? const BoxConstraints() : null;

    if (descriptor.effect != null) {
      final SelectionEffect effect = descriptor.effect!;
      return AppButtonIcon(
        key: ValueKey<SelectionEffect>(effect),
        icon: descriptor.icon,
        isSelected: armedEffect == effect,
        tooltip: descriptor.label(l10n),
        constraints: constraints,
        padding: padding,
        onPressed: () => armedEffect == effect ? appProvider.disarmEffectBrush() : appProvider.armEffectBrush(effect),
      );
    }

    final ActionType action = descriptor.action!;
    return AppButtonIcon(
      key: _gestureToolKey(action),
      icon: descriptor.icon,
      // Suppressed while an effect brush is armed — only one tool is active.
      isSelected: appProvider.selectedAction == action && armedEffect == null,
      tooltip: descriptor.label(l10n),
      constraints: constraints,
      padding: padding,
      onPressed: () => appProvider.selectedAction = action,
    );
  }
}
