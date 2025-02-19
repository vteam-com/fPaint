import 'package:flutter/material.dart';

enum BrushStyle {
  solid,
  dash,
  // airbrush,
  // charcoal,
  // marker,
}

class MyBrush {
  MyBrush({
    this.style = BrushStyle.solid,
    this.color = Colors.black,
    this.size = 1,
  });
  BrushStyle style;
  Color color;
  double size;
}

class BrushStylePicker extends StatefulWidget {
  const BrushStylePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final BrushStyle value;
  final ValueChanged<BrushStyle> onChanged;

  @override
  BrushStylePickerState createState() => BrushStylePickerState();
}

class BrushStylePickerState extends State<BrushStylePicker> {
  late BrushStyle _value;
  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  Widget build(final BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 20,
      children: <Widget>[
        brushStyleDropDown(_value, (final BrushStyle selectedBrush) {
          setState(() {
            _value = selectedBrush;
            widget.onChanged(selectedBrush);
          });
        }),
      ],
    );
  }
}

Widget brushStyleDropDown(
  final BrushStyle value,
  final void Function(BrushStyle) onChanged,
) {
  return DropdownButton<int>(
    value: value.index,
    items:
        BrushStyle.values.map<DropdownMenuItem<int>>((final BrushStyle value) {
      return DropdownMenuItem<int>(
        value: value.index,
        child: Text(value.name),
      );
    }).toList(),
    onChanged: (final int? index) {
      onChanged(BrushStyle.values[index!]);
    },
  );
}

void showBrushStylePicker(
  final BuildContext context,
  final BrushStyle brushStyle,
  final void Function(BrushStyle) onChanged,
) {
  showDialog<dynamic>(
    context: context,
    builder: (final BuildContext context) {
      return AlertDialog(
        title: const Text('Brush'),
        content: IntrinsicHeight(
          child: BrushStylePicker(
            value: brushStyle,
            onChanged: onChanged,
          ),
        ),
      );
    },
  );
}
