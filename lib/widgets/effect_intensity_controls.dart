import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/effect_labels.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/widgets/app_button_row.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/app_slider.dart';

/// Shared intensity slider and Apply/Cancel controls for an active effect preview.
///
/// Displays the selected effect's icon and name as a header, then an intensity
/// slider that drives a live canvas preview, followed by Apply and Cancel buttons.
///
/// Used by both the side panel ([_EffectsSection] in tools_panel.dart) and the
/// bottom sheet shown on tablet or when the side panel is collapsed.
class EffectIntensityControls extends StatefulWidget {
  const EffectIntensityControls({
    super.key,
    required this.appProvider,
    required this.l10n,
    required this.sliderKey,
    required this.applyButtonKey,
    required this.cancelButtonKey,
    this.onDismiss,
  });

  final AppProvider appProvider;

  /// Key placed on the Apply button.
  final Key applyButtonKey;

  /// Key placed on the Cancel button.
  final Key cancelButtonKey;

  final AppLocalizations l10n;

  /// Called after Apply or Cancel so the parent can dismiss a wrapping sheet.
  final VoidCallback? onDismiss;

  /// Key placed on the intensity [AppSlider].
  final Key sliderKey;

  @override
  State<EffectIntensityControls> createState() => _EffectIntensityControlsState();
}

class _EffectIntensityControlsState extends State<EffectIntensityControls> {
  late double _strength;

  @override
  void initState() {
    super.initState();
    _strength = widget.appProvider.effectPreviewModel.strength;
  }

  @override
  Widget build(final BuildContext context) {
    final SelectionEffect? effect = widget.appProvider.effectPreviewModel.effect;
    if (effect == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSlider(
            key: widget.sliderKey,
            icon: AppSvgIcon(icon: effect.icon, size: AppLayout.iconSize),
            label: effectLabel(widget.l10n, effect),
            value: _strength,
            valueLabel: '${(_strength * AppMath.percentScale).round()}%',
            min: AppEffects.minIntensity,
            max: AppEffects.maxIntensity,
            onChanged: (final double value) async {
              setState(() => _strength = value);
              await widget.appProvider.updateEffectPreviewStrength(value);
            },
          ),
          AppButtonRow(
            actions: <Widget>[
              AppRowSecondaryButton(
                key: widget.cancelButtonKey,
                onPressed: () {
                  widget.appProvider.cancelEffectPreview();
                  widget.onDismiss?.call();
                },
                text: widget.l10n.cancel,
              ),
              AppRowPrimaryButton(
                key: widget.applyButtonKey,
                onPressed: () async {
                  await widget.appProvider.confirmEffectPreview();
                  widget.onDismiss?.call();
                },
                text: widget.l10n.apply,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
