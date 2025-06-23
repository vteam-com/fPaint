import 'package:flutter/material.dart';

/// A widget that allows the user to pick a tolerance value using a slider.
class TolerancePicker extends StatefulWidget {
  /// Creates a [TolerancePicker].
  const TolerancePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// The current tolerance value.
  final int value;

  /// A callback that is called when the tolerance value changes.
  final ValueChanged<int> onChanged;

  @override
  TolerancePickerState createState() => TolerancePickerState();
}

/// The state for [TolerancePicker].
class TolerancePickerState extends State<TolerancePicker> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(covariant final TolerancePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      setState(() {
        _value = widget.value;
      });
    }
  }

  @override
  Widget build(final BuildContext context) {
    return Column(
      children: <Widget>[
        Text('Tolerance: ${_value.toStringAsFixed(0)}'),
        Slider(
          value: _value.toDouble(),
          min: 1,
          max: 100,
          divisions: 100,
          label: _value.toStringAsFixed(0),
          onChanged: (final double value) {
            setState(() {
              _value = value.toInt();
            });
            widget.onChanged(_value);
          },
        ),
      ],
    );
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
