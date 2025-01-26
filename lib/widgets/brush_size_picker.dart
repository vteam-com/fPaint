import 'package:flutter/material.dart';

class BrushSizePicker extends StatefulWidget {
  const BrushSizePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final double value;
  final ValueChanged<double> onChanged;

  @override
  BrushSizePickerState createState() => BrushSizePickerState();
}

class BrushSizePickerState extends State<BrushSizePicker> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(covariant BrushSizePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      setState(() {
        _value = widget.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Brush Size: ${_value.toStringAsFixed(1)}'),
        Slider(
          value: _value,
          min: 0.1,
          max: 100.0,
          divisions: 1000,
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

void showBrushSizePicker(
  final BuildContext context,
  final double value,
  final ValueChanged<double> onChanged,
) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Select Brush Size'),
        content: IntrinsicHeight(
          child: BrushSizePicker(
            value: value,
            onChanged: (final double newValue) {
              onChanged(newValue);
            },
          ),
        ),
      );
    },
  );
}
