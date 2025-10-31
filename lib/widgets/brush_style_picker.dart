import 'package:flutter/material.dart';
import 'package:fpaint/widgets/base_picker.dart';

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
class BrushStylePicker extends BasePicker<BrushStyle> {
  /// Creates a [BrushStylePicker].
  const BrushStylePicker({
    super.key,
    required super.value,
    required super.onChanged,
  }) : super(title: 'Brush Style');

  @override
  BrushStylePickerState createState() => BrushStylePickerState();
}

/// The state for [BrushStylePicker].
class BrushStylePickerState extends BasePickerState<BrushStyle> {
  @override
  BrushStyle clampValue(final BrushStyle value) {
    return value; // No clamping needed for enums
  }

  @override
  Widget buildPickerWidget() {
    return DropdownButton<int>(
      value: currentValue.index,
      items: BrushStyle.values.map<DropdownMenuItem<int>>((final BrushStyle value) {
        return DropdownMenuItem<int>(
          value: value.index,
          child: Text(value.name),
        );
      }).toList(),
      onChanged: (final int? index) {
        if (index != null) {
          updateValue(BrushStyle.values[index]);
        }
      },
    );
  }

  @override
  String formatValue(final BrushStyle value) {
    return value.name;
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
      if (index != null) {
        onChanged(BrushStyle.values[index]);
      }
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
