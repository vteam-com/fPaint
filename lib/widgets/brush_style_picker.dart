import 'package:flutter/material.dart';

/// Defines the different styles for a brush.
enum BrushStyle {
  /// A solid brush style.
  solid,

  /// A dashed brush style.
  dash,
  // airbrush,
  // charcoal,
  // marker,
}

/// Represents a brush with a specific style, color, and size.
class MyBrush {
  MyBrush({
    this.style = BrushStyle.solid,
    this.color = Colors.black,
    this.size = 1,
  });

  /// The style of the brush.
  BrushStyle style;

  /// The color of the brush.
  Color color;

  /// The size of the brush.
  double size;
}

/// A widget that allows the user to pick a brush style from a dropdown menu.
class BrushStylePicker extends StatefulWidget {
  /// Creates a [BrushStylePicker].
  const BrushStylePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// The current brush style value.
  final BrushStyle value;

  /// A callback that is called when the brush style changes.
  final ValueChanged<BrushStyle> onChanged;

  @override
  BrushStylePickerState createState() => BrushStylePickerState();
}

/// The state for [BrushStylePicker].
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

/// Creates a dropdown button for selecting a brush style.
///
/// The [value] parameter is the currently selected brush style.
/// The [onChanged] parameter is a callback that is called when the selected brush style changes.
Widget brushStyleDropDown(
  final BrushStyle value,
  final void Function(BrushStyle) onChanged,
) {
  return DropdownButton<int>(
    value: value.index,
    items: BrushStyle.values.map<DropdownMenuItem<int>>((final BrushStyle value) {
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

/// Shows a dialog containing a [BrushStylePicker].
///
/// The [context] parameter is the [BuildContext] used to show the dialog.
/// The [brushStyle] parameter is the currently selected brush style.
/// The [onChanged] parameter is a callback that is called when the brush style changes.
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
