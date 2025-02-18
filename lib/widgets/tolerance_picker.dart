import 'package:flutter/material.dart';

class TolerancePicker extends StatefulWidget {
  const TolerancePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final int value;
  final ValueChanged<int> onChanged;

  @override
  TolerancePickerState createState() => TolerancePickerState();
}

class TolerancePickerState extends State<TolerancePicker> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(covariant TolerancePicker oldWidget) {
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
          onChanged: (double value) {
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

void showTolerancePicker(
  final BuildContext context,
  final int value,
  final ValueChanged<int> onChanged,
) {
  showDialog<dynamic>(
    context: context,
    builder: (BuildContext context) {
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
