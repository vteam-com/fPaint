import 'package:flutter/material.dart';
import 'package:fpaint/widgets/base_picker.dart';

/// A widget that allows the user to pick a tolerance value using a slider.
class TolerancePicker extends BasePicker<int> {
  /// Creates a [TolerancePicker].
  const TolerancePicker({
    super.key,
    required super.value,
    required super.onChanged,
  }) : super(title: 'Tolerance', min: 1, max: 100, divisions: 100);

  @override
  TolerancePickerState createState() => TolerancePickerState();
}

/// The state for [TolerancePicker].
class TolerancePickerState extends BasePickerState<int> {
  @override
  int clampValue(final int value) {
    return value.clamp(1, 100);
  }

  @override
  Widget buildPickerWidget() {
    return Slider(
      value: currentValue.toDouble(),
      min: 1,
      max: 100,
      divisions: 100,
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
    builder: (final BuildContext context) {
      return AlertDialog(
        title: const Text('Color Tolerance'),
        content: IntrinsicHeight(
          child: TolerancePicker(
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
