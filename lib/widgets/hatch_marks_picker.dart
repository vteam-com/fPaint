// ignore: fcheck_one_class_per_file
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/hatch_marks.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/material_free.dart';

/// Live controls for [HatchMarks]: angle (relative to the stroke), spacing,
/// length, taper and curve. Every change is reported through [onChanged] as a
/// whole value.
class HatchMarksControls extends StatefulWidget {
  /// Creates a [HatchMarksControls].
  const HatchMarksControls({
    super.key,
    required this.marks,
    required this.onChanged,
  });

  /// The marks geometry to edit.
  final HatchMarks marks;

  /// Called with the updated geometry after every slider change.
  final ValueChanged<HatchMarks> onChanged;

  @override
  State<HatchMarksControls> createState() => _HatchMarksControlsState();
}

class _HatchMarksControlsState extends State<HatchMarksControls> {
  late HatchMarks _marks = widget.marks;
  @override
  void didUpdateWidget(covariant HatchMarksControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.marks != widget.marks) {
      _marks = widget.marks;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.small,
      children: <Widget>[
        AppSlider(
          key: Keys.hatchMarksAngleSlider,
          label: l10n.hatchAngle,
          valueLabel: l10n.degreesValue(_marks.angleDegrees),
          value: _marks.angleDegrees.toDouble(),
          min: AppHatchMarks.minAngleDegrees.toDouble(),
          max: AppHatchMarks.maxAngleDegrees.toDouble(),
          divisions: AppHatchMarks.angleDivisions,
          onChanged: (double value) => _update(_marks.copyWith(angleDegrees: value.round())),
        ),
        AppSlider(
          key: Keys.hatchMarksSpacingSlider,
          label: l10n.hatchSpacing,
          valueLabel: l10n.pixelsValue(_marks.spacing),
          value: _marks.spacing.toDouble(),
          min: AppHatchMarks.minSpacing.toDouble(),
          max: AppHatchMarks.maxSpacing.toDouble(),
          divisions: AppHatchMarks.maxSpacing - AppHatchMarks.minSpacing,
          onChanged: (double value) => _update(_marks.copyWith(spacing: value.round())),
        ),
        AppSlider(
          key: Keys.hatchMarksLengthSlider,
          label: l10n.hatchLength,
          valueLabel: l10n.pixelsValue(_marks.length),
          value: _marks.length.toDouble(),
          min: AppHatchMarks.minLength.toDouble(),
          max: AppHatchMarks.maxLength.toDouble(),
          divisions: AppHatchMarks.maxLength - AppHatchMarks.minLength,
          onChanged: (double value) => _update(_marks.copyWith(length: value.round())),
        ),
        AppSlider(
          key: Keys.hatchMarksTaperSlider,
          label: l10n.hatchTaper,
          valueLabel: l10n.percentageValue(_marks.taperPercent),
          value: _marks.taperPercent.toDouble(),
          min: AppMath.zero.toDouble(),
          max: AppLimits.percentMax.toDouble(),
          divisions: AppLimits.sliderDivisions,
          onChanged: (double value) => _update(_marks.copyWith(taperPercent: value.round())),
        ),
        AppSlider(
          key: Keys.hatchMarksCurveSlider,
          label: l10n.hatchCurve,
          valueLabel: l10n.percentageValue(_marks.curvePercent),
          value: _marks.curvePercent.toDouble(),
          min: AppHatchMarks.minCurvePercent.toDouble(),
          max: AppHatchMarks.maxCurvePercent.toDouble(),
          divisions: AppHatchMarks.curveDivisions,
          onChanged: (double value) => _update(_marks.copyWith(curvePercent: value.round())),
        ),
      ],
    );
  }

  void _update(HatchMarks next) {
    setState(() {
      _marks = next;
    });
    widget.onChanged(next);
  }
}

/// Shows the hatch-marks settings ([HatchMarksControls]) in a bottom sheet
/// that leaves the canvas visible.
void showHatchMarksPicker({
  required BuildContext context,
  required HatchMarks marks,
  required ValueChanged<HatchMarks> onChanged,
}) {
  final AppLocalizations l10n = context.l10n;
  showAppBottomSheet<void>(
    context: context,
    barrierColor: AppColors.transparent,
    builder: (BuildContext _) {
      return AppBottomSheetContent(
        title: l10n.toolHatchMarks,
        titleIcon: const AppSvgIcon(icon: AppIcon.hatch),
        child: HatchMarksControls(
          marks: marks,
          onChanged: onChanged,
        ),
      );
    },
  );
}
