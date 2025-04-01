import 'package:flutter/material.dart';

/// A widget that allows the user to pick a brush size using a slider.
class BrushSizePicker extends StatefulWidget {
  /// Creates a [BrushSizePicker].
  const BrushSizePicker({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  /// The title of the picker.
  final String title;

  /// The current value of the picker.
  final double value;

  /// The minimum value of the picker.
  final double min;

  /// The maximum value of the picker.
  final double max;

  /// A callback that is called when the value of the picker changes.
  final ValueChanged<double> onChanged;

  @override
  BrushSizePickerState createState() => BrushSizePickerState();
}

/// The state for [BrushSizePicker].
class BrushSizePickerState extends State<BrushSizePicker> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value.clamp(widget.min, widget.max);
  }

  @override
  void didUpdateWidget(covariant final BrushSizePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.min != widget.min ||
        oldWidget.max != widget.max) {
      setState(() {
        _value = widget.value.clamp(widget.min, widget.max);
      });
    }
  }

  @override
  Widget build(final BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 20,
      children: <Widget>[
        Text('${widget.title}: ${_value.toStringAsFixed(1)}'),
        Slider(
          value: _value,
          min: widget.min,
          max: widget.max,
          divisions: (widget.max * 10).toInt(),
          label: _value.toStringAsFixed(1),
          onChanged: (final double value) {
            setState(() {
              _value = value;
            });
            widget.onChanged(_value);
          },
        ),
      ],
    );
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
