// ignore: fcheck_one_class_per_file
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/widgets/base_picker.dart';
import 'package:fpaint/widgets/material_free/material_free.dart';

/// A widget that allows the user to pick a tolerance value using a slider.
class TolerancePicker extends BasePicker<int> {
  /// Creates a [TolerancePicker].
  const TolerancePicker({
    super.key,
    required super.title,
    required super.value,
    required super.onChanged,
  }) : super(min: 1, max: AppLimits.percentMax, divisions: AppLimits.sliderDivisions);

  @override
  TolerancePickerState createState() => TolerancePickerState();
}

/// The state for [TolerancePicker].
class TolerancePickerState extends BasePickerState<int> {
  @override
  int clampValue(final int value) {
    return value.clamp(1, AppLimits.percentMax);
  }

  @override
  Widget buildPickerWidget() {
    return AppSlider(
      value: currentValue.toDouble(),
      min: 1,
      max: AppLimits.percentMax.toDouble(),
      divisions: AppLimits.sliderDivisions,
      onChanged: (final double value) => updateValue(value.toInt()),
    );
  }

  @override
  String formatValue(final int value) {
    return value.toStringAsFixed(0);
  }
}

/// Shows a dialog containing a [TolerancePicker].
void showTolerancePicker(
  final BuildContext context,
  final int value,
  final ValueChanged<int> onChanged,
) {
  final AppLocalizations l10n = context.l10n;
  showPickerDialog(
    context: context,
    title: l10n.colorTolerance,
    child: TolerancePicker(
      title: l10n.tolerance,
      value: value.toInt(),
      onChanged: (final int newValue) {
        onChanged(newValue);
      },
    ),
  );
}
