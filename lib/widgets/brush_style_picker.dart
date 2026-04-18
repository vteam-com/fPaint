import 'package:flutter/material.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/brush_style.dart';
import 'package:fpaint/widgets/base_picker.dart';

/// A widget that allows the user to pick a brush style from a dropdown menu.
class BrushStylePicker extends BasePicker<BrushStyle> {
  /// Creates a [BrushStylePicker].
  const BrushStylePicker({
    super.key,
    required super.title,
    required super.value,
    required super.onChanged,
  });

  @override
  BasePickerState<BrushStyle> createState() => _BrushStylePickerState();
}

/// The state for [BrushStylePicker].
class _BrushStylePickerState extends BasePickerState<BrushStyle> {
  @override
  BrushStyle clampValue(final BrushStyle value) {
    return value; // No clamping needed for enums
  }

  @override
  Widget buildPickerWidget() {
    return brushStyleDropDown(currentValue, updateValue);
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
  final List<DropdownMenuItem<int>> items = BrushStyle.values.map<DropdownMenuItem<int>>((final BrushStyle value) {
    return DropdownMenuItem<int>(
      value: value.index,
      child: Text(value.name),
    );
  }).toList();

  return DropdownButton<int>(
    value: value.index,
    items: items,
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
  final AppLocalizations l10n = context.l10n;
  showPickerDialog(
    context: context,
    title: l10n.brush,
    child: BrushStylePicker(
      title: l10n.brushStyle,
      value: brushStyle,
      onChanged: onChanged,
    ),
  );
}
