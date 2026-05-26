// ignore: fcheck_one_class_per_file
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/widgets/base_picker.dart';
import 'package:fpaint/widgets/material_free.dart';

/// A widget that allows the user to pick the halftone dot-size percentage.
class HalftoneSizePicker extends BasePicker<int> {
  /// Creates a [HalftoneSizePicker].
  const HalftoneSizePicker({
    super.key,
    required super.title,
    required super.value,
    required super.onChanged,
  }) : super(
         min: AppMath.zero,
         max: AppLimits.percentMax,
         divisions: AppLimits.sliderDivisions,
       );

  @override
  HalftoneSizePickerState createState() => HalftoneSizePickerState();
}

/// The state for [HalftoneSizePicker].
class HalftoneSizePickerState extends BasePickerState<int> {
  @override
  int clampValue(final int value) {
    return value.clamp(AppMath.zero, AppLimits.percentMax);
  }

  @override
  Widget buildPickerWidget() {
    return AppSlider(
      value: currentValue.toDouble(),
      min: AppMath.zero.toDouble(),
      max: AppLimits.percentMax.toDouble(),
      divisions: AppLimits.sliderDivisions,
      onChanged: (final double value) => updateValue(value.toInt()),
    );
  }

  @override
  String formatValue(final int value) {
    final AppLocalizations l10n = context.l10n;
    return l10n.percentageValue(value);
  }
}

/// Shows a dialog containing a [HalftoneSizePicker].
void showHalftoneSizePicker({
  required final BuildContext context,
  required final int value,
  required final ValueChanged<int> onChanged,
}) {
  final AppLocalizations l10n = context.l10n;
  showPickerDialog(
    context: context,
    title: l10n.toolHalftone,
    child: HalftoneSizePicker(
      title: l10n.toolHalftone,
      value: value,
      onChanged: (final int newValue) {
        onChanged(newValue);
      },
    ),
  );
}
