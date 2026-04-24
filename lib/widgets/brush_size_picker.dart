import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/widgets/base_picker.dart';
import 'package:fpaint/widgets/material_free/material_free.dart';

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
  }) : super(min: min, max: max, divisions: (max * AppMath.baseTen).toInt());

  @override
  BasePickerState<double> createState() => _BrushSizePickerState();
}

/// The state for [BrushSizePicker].
class _BrushSizePickerState extends BasePickerState<double> {
  @override
  double clampValue(final double value) {
    final double min = widget.min!;
    final double max = widget.max!;
    return value.clamp(min, max);
  }

  @override
  Widget buildPickerWidget() {
    return AppSlider(
      value: currentValue,
      min: widget.min!,
      max: widget.max!,
      divisions: widget.divisions,
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
  final AppLocalizations l10n = context.l10n;
  showPickerDialog(
    context: context,
    title: l10n.selectValue(title),
    child: BrushSizePicker(
      title: title,
      value: value,
      min: min,
      max: max,
      onChanged: (final double newValue) {
        onChanged(newValue);
      },
    ),
  );
}
