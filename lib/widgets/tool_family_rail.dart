import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/shortcut_tooltip.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/effect_labels.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/tool_descriptor.dart';
import 'package:fpaint/models/tool_kind.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/tool_rail_port.dart';
import 'package:fpaint/widgets/app_buttons.dart';
import 'package:fpaint/widgets/app_divider.dart';
import 'package:fpaint/widgets/app_slider.dart';
import 'package:fpaint/widgets/side_panel_header.dart';

/// Brush-size range of a painted effect brush.
final BrushSizeRange _effectBrushSizeRange = ToolKind.brush.brushSizeRange(effectArmed: true);

/// Widget keys existing tests tap; tools without a prior key keep none.
const Map<ToolKind, Key> _railKeys = <ToolKind, Key>{
  ToolKind.smudge: Keys.toolSmudge,
  ToolKind.blurBrush: Keys.toolBlurBrush,
  ToolKind.line: Keys.toolLine,
  ToolKind.rectangle: Keys.toolRectangle,
  ToolKind.circle: Keys.toolCircle,
  ToolKind.fill: Keys.toolFill,
  ToolKind.text: Keys.toolText,
};

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
    this.port,
  });

  /// Parameter controls for the currently selected gesture tool.
  final Widget? gestureParams;

  /// Whether the rail is rendered in the compact (minimal) layout.
  final bool minimal;

  /// The tool state the rail reads and changes; defaults to the app provider's
  /// [AppProvider.toolRail].
  final ToolRailPort? port;
  @override
  Widget build(BuildContext context) {
    final ToolRailPort rail = port ?? AppProvider.of(context).toolRail;

    return ListenableBuilder(
      // Rebuild on tool change AND on effect arm/disarm + strength changes, so
      // the selection highlight and the options panel always reflect the single
      // active tool.
      listenable: rail.railChanges,
      builder: (BuildContext context, Widget? _) {
        return _toolSections(context, rail);
      },
    );
  }

  /// Brush controls for the [armedEffect]: brush size and strength. The effect
  /// is applied by painting it onto the canvas.
  Widget _effectControls(
    AppLocalizations l10n,
    ToolRailPort rail,
    SelectionEffect armedEffect,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSlider(
            key: Keys.effectPaintSizeSlider,
            label: l10n.brushSize,
            value: rail.brushSize,
            valueLabel: rail.brushSize.toStringAsFixed(AppMath.zero),
            min: _effectBrushSizeRange.min,
            max: _effectBrushSizeRange.max,
            onChanged: (double value) => rail.brushSize = value,
          ),
          AppSlider(
            key: Keys.effectPaintStrengthSlider,
            label: effectLabel(l10n, armedEffect),
            value: rail.effectStrength,
            valueLabel: formatFractionPercent(l10n, rail.effectStrength),
            min: armedEffect.bipolar ? -AppEffects.maxIntensity : AppEffects.minIntensity,
            max: AppEffects.maxIntensity,
            onChanged: (double value) => rail.setEffectStrength(value),
          ),
        ],
      ),
    );
  }

  /// A single rail button: a gesture tool that sets the active action, or an
  /// effect that arms/disarms itself as a brush.
  Widget _toolButton(
    AppLocalizations l10n,
    ToolRailPort rail,
    ToolDescriptor descriptor,
    SelectionEffect? armedEffect,
  ) {
    if (descriptor.effect != null) {
      final SelectionEffect effect = descriptor.effect!;
      return AppButtonIcon.toolOption(
        key: ValueKey<SelectionEffect>(effect),
        icon: descriptor.icon,
        compact: minimal,
        isSelected: rail.activeTool == descriptor,
        tooltip: descriptor.label(l10n),
        onPressed: () => armedEffect == effect ? rail.disarmEffectBrush() : rail.armEffectBrush(effect),
      );
    }

    return AppButtonIcon.toolOption(
      key: _railKeys[descriptor.tool],
      icon: descriptor.icon,
      compact: minimal,
      // Suppressed while an effect brush is armed — only one tool is active.
      isSelected: rail.activeTool == descriptor,
      tooltip: tooltipWithShortcut(descriptor.label(l10n), descriptor.shortcut),
      onPressed: () => rail.activateTool(descriptor),
    );
  }

  /// A wrapped grid of tool buttons for one section.
  Widget _toolGrid(
    AppLocalizations l10n,
    ToolRailPort rail,
    List<ToolDescriptor> descriptors,
    SelectionEffect? armedEffect,
  ) {
    return Wrap(
      spacing: minimal ? AppSpacing.thin : AppSpacing.small,
      runSpacing: minimal ? AppSpacing.thin : AppSpacing.small,
      alignment: WrapAlignment.center,
      children: <Widget>[
        for (final ToolDescriptor descriptor in descriptors) _toolButton(l10n, rail, descriptor, armedEffect),
      ],
    );
  }

  /// Builds the two tool sections: **Brush** (freehand painters + effects) and
  /// **Elements** (line, rectangle, circle, fill, text). Exactly one tool is
  /// active across both, so its controls (gesture params, or the armed effect's
  /// controls) render beneath whichever section owns it.
  Widget _toolSections(BuildContext context, ToolRailPort rail) {
    final AppLocalizations l10n = context.l10n;
    final SelectionEffect? armedEffect = rail.armedEffect;
    final ToolKind selectedTool = rail.selectedTool;

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
          _toolGrid(l10n, rail, brushSectionTools(), armedEffect),
          if (armedEffect != null)
            _effectControls(l10n, rail, armedEffect)
          else if (kBrushToolOrder.contains(selectedTool) && gestureParams != null)
            gestureParams!,
          // Divider separating the Brush and Elements sections.
          const SizedBox(height: AppSpacing.medium),
          const AppDivider(),
          const SizedBox(height: AppSpacing.medium),
          // Elements section: placement / shape tools. An armed effect never
          // owns these, so params only show for a selected element tool.
          SidePanelHeader(title: l10n.toolSectionElements, padding: EdgeInsets.zero),
          const SizedBox(height: AppSpacing.small),
          _toolGrid(l10n, rail, elementSectionTools(), armedEffect),
          if (armedEffect == null && kElementToolOrder.contains(selectedTool) && gestureParams != null) gestureParams!,
        ],
      ),
    );
  }
}
