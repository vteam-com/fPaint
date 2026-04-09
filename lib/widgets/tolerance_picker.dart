// ignore: fcheck_one_class_per_file
import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/widgets/base_picker.dart';

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
    return Slider(
      value: currentValue.toDouble(),
      min: 1,
      max: AppLimits.percentMax.toDouble(),
      divisions: AppLimits.sliderDivisions,
      label: currentValue.toStringAsFixed(0),
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
  showDialog<dynamic>(
    context: context,
    builder: (final BuildContext _) {
      final AppLocalizations l10n = AppLocalizations.of(context)!;

      return AlertDialog(
        title: Text(l10n.colorTolerance),
        content: IntrinsicHeight(
          child: TolerancePicker(
            title: l10n.tolerance,
            value: value.toInt(),
            onChanged: (final int newValue) {
              onChanged(newValue);
            },
          ),
        ),
      );
    },
  );
}
