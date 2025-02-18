import 'package:flutter/material.dart';

class BrushSizePicker extends StatefulWidget {
  const BrushSizePicker({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String title;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  BrushSizePickerState createState() => BrushSizePickerState();
}

class BrushSizePickerState extends State<BrushSizePicker> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value.clamp(widget.min, widget.max);
  }

  @override
  void didUpdateWidget(covariant BrushSizePicker oldWidget) {
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
          onChanged: (double value) {
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
    builder: (BuildContext context) {
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
