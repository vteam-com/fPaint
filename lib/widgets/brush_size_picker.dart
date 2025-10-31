import 'package:flutter/material.dart';
import 'package:fpaint/widgets/base_picker.dart';

/// A widget that allows the user to pick a brush size using a slider.
class BrushSizePicker extends BasePicker<double> {
  /// Creates a [BrushSizePicker].
  BrushSizePicker({
    super.key,
    required super.title,
    required super.value,
    required super.onChanged,
    required final double min,
    required final double max,
  }) : super(min: min, max: max, divisions: (max * 10).toInt());

  @override
  BrushSizePickerState createState() => BrushSizePickerState();
}

/// The state for [BrushSizePicker].
class BrushSizePickerState extends BasePickerState<double> {
  @override
  double clampValue(final double value) {
    final double min = widget.min!;
    final double max = widget.max!;
    return value.clamp(min, max);
  }

  @override
  Widget buildPickerWidget() {
    return Slider(
      value: currentValue,
      min: widget.min!,
      max: widget.max!,
      divisions: widget.divisions,
      label: currentValue.toStringAsFixed(1),
      onChanged: updateValue,
    );
  }

  @override
  String formatValue(final double value) {
    return value.toStringAsFixed(1);
  }
}

/// Shows a dialog containing a [BrushSizePicker].
void showBrushSizePicker({
  required final BuildContext context,
  required final String title,
  required final double value,
  required final double min,
  required final double max,
  required final ValueChanged<double> onChanged,
}) {
  showDialog<dynamic>(
    context: context,
    builder: (final BuildContext context) {
      return AlertDialog(
        title: Text('Select $title'),
        content: IntrinsicHeight(
          child: BrushSizePicker(
            title: title,
            value: value,
            min: min,
            max: max,
            onChanged: (final double newValue) {
              onChanged(newValue);
            },
          ),
        ),
      );
    },
  );
}
