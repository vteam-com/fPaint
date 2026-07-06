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
import 'package:fpaint/widgets/app_divider.dart';
import 'package:fpaint/widgets/app_slider.dart';
import 'package:fpaint/widgets/side_panel_header.dart';

/// The tool rail: two sections split by interaction shape.
///
/// **Brush** holds the freehand painters (pencil, brush, smudge, eraser) plus
/// the effects (blur, sharpness, brightness, …) — an effect is just a brush,
/// tapping one arms it and you paint it on. **Elements** holds the placement /
/// shape tools (line, rectangle, circle, fill, text). Exactly one tool is active
/// across both sections at a time: arming an effect deselects the gesture tool
/// and swaps [gestureParams] for the effect's brush controls (size and
/// strength), and picking any gesture tool disarms the effect. The active tool's
/// controls render beneath whichever section owns it.
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
        return _toolSections(context, appProvider);
      },
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

  /// A wrapped grid of tool buttons for one section.
  Widget _toolGrid(
    final AppLocalizations l10n,
    final AppProvider appProvider,
    final List<ToolDescriptor> descriptors,
    final SelectionEffect? armedEffect,
  ) {
    return Wrap(
      spacing: minimal ? AppSpacing.thin : AppSpacing.small,
      runSpacing: minimal ? AppSpacing.thin : AppSpacing.small,
      alignment: WrapAlignment.center,
      children: <Widget>[
        for (final ToolDescriptor descriptor in descriptors) _toolButton(l10n, appProvider, descriptor, armedEffect),
      ],
    );
  }

  /// Builds the two tool sections: **Brush** (freehand painters + effects) and
  /// **Elements** (line, rectangle, circle, fill, text). Exactly one tool is
  /// active across both, so its controls (gesture params, or the armed effect's
  /// controls) render beneath whichever section owns it.
  Widget _toolSections(final BuildContext context, final AppProvider appProvider) {
    final AppLocalizations l10n = context.l10n;
    final SelectionEffect? armedEffect = appProvider.effectBrushModel.effect;
    final ActionType selectedAction = appProvider.selectedAction;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.small,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Brush section: freehand painters, then effects. When an effect is
          // armed its controls show here; otherwise a selected brush tool's
          // params show here.
          SidePanelHeader(title: l10n.toolSectionBrush, padding: EdgeInsets.zero),
          const SizedBox(height: AppSpacing.small),
          _toolGrid(l10n, appProvider, brushSectionTools(), armedEffect),
          if (armedEffect != null)
            _effectControls(l10n, appProvider, armedEffect)
          else if (kBrushToolOrder.contains(selectedAction) && gestureParams != null)
            gestureParams!,
          // Divider separating the Brush and Elements sections.
          const SizedBox(height: AppSpacing.medium),
          const AppDivider(),
          const SizedBox(height: AppSpacing.medium),
          // Elements section: placement / shape tools. An armed effect never
          // owns these, so params only show for a selected element tool.
          SidePanelHeader(title: l10n.toolSectionElements, padding: EdgeInsets.zero),
          const SizedBox(height: AppSpacing.small),
          _toolGrid(l10n, appProvider, elementSectionTools(), armedEffect),
          if (armedEffect == null && kElementToolOrder.contains(selectedAction) && gestureParams != null)
            gestureParams!,
        ],
      ),
    );
  }
}
