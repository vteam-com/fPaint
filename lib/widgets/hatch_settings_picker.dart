// ignore: fcheck_one_class_per_file
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/hatch_pattern.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/material_free.dart';

/// Live controls for a [HatchPattern]: the cross-hatch switch plus angle,
/// spacing and line-weight sliders. Every change is reported through
/// [onChanged] as a whole pattern so the caller decides where each field lives
/// (brush style vs. fill flag for `crossed`, shared geometry for the rest).
class HatchSettingsControls extends StatefulWidget {
  /// Creates a [HatchSettingsControls].
  const HatchSettingsControls({
    super.key,
    required this.pattern,
    required this.onChanged,
  });

  /// Called with the updated pattern after every slider or switch change.
  final ValueChanged<HatchPattern> onChanged;

  /// The pattern to edit; [HatchPattern.crossed] drives the switch.
  final HatchPattern pattern;
  @override
  State<HatchSettingsControls> createState() => _HatchSettingsControlsState();
}

class _HatchSettingsControlsState extends State<HatchSettingsControls> {
  late HatchPattern _pattern = widget.pattern;
  @override
  void didUpdateWidget(covariant HatchSettingsControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pattern != widget.pattern) {
      _pattern = widget.pattern;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.small,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            AppText(l10n.hatchCrossed),
            AppSwitch(
              key: Keys.hatchCrossedToggle,
              value: _pattern.crossed,
              onChanged: (bool value) => _update(_pattern.copyWith(crossed: value)),
            ),
          ],
        ),
        AppSlider(
          key: Keys.hatchAngleSlider,
          label: l10n.hatchAngle,
          valueLabel: l10n.degreesValue(_pattern.angleDegrees),
          value: _pattern.angleDegrees.toDouble(),
          min: AppHatch.minAngleDegrees.toDouble(),
          max: AppHatch.maxAngleDegrees.toDouble(),
          divisions: AppHatch.angleDivisions,
          onChanged: (double value) => _update(_pattern.copyWith(angleDegrees: value.round())),
        ),
        AppSlider(
          key: Keys.hatchSpacingSlider,
          label: l10n.hatchSpacing,
          valueLabel: l10n.pixelsValue(_pattern.spacing),
          value: _pattern.spacing.toDouble(),
          min: AppHatch.minSpacing.toDouble(),
          max: AppHatch.maxSpacing.toDouble(),
          divisions: AppHatch.maxSpacing - AppHatch.minSpacing,
          onChanged: (double value) => _update(_pattern.copyWith(spacing: value.round())),
        ),
        AppSlider(
          key: Keys.hatchLineWidthSlider,
          label: l10n.hatchLineWidth,
          valueLabel: l10n.pixelsValue(_pattern.lineWidth),
          value: _pattern.lineWidth.toDouble(),
          min: AppHatch.minLineWidth.toDouble(),
          max: AppHatch.maxLineWidth.toDouble(),
          divisions: AppHatch.maxLineWidth - AppHatch.minLineWidth,
          onChanged: (double value) => _update(_pattern.copyWith(lineWidth: value.round())),
        ),
      ],
    );
  }

  void _update(HatchPattern next) {
    setState(() {
      _pattern = next;
    });
    widget.onChanged(next);
  }
}

/// Shows the hatch settings ([HatchSettingsControls]) in a bottom sheet that
/// leaves the canvas visible, so the pattern can be tuned against the artwork.
void showHatchSettingsPicker({
  required BuildContext context,
  required HatchPattern pattern,
  required ValueChanged<HatchPattern> onChanged,
}) {
  final AppLocalizations l10n = context.l10n;
  showAppBottomSheet<void>(
    context: context,
    barrierColor: AppColors.transparent,
    builder: (BuildContext _) {
      return AppBottomSheetContent(
        title: l10n.toolHatching,
        titleIcon: const AppSvgIcon(icon: AppIcon.hatch),
        child: HatchSettingsControls(
          pattern: pattern,
          onChanged: onChanged,
        ),
      );
    },
  );
}
