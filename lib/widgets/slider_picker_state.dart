import 'package:flutter/widgets.dart';
import 'package:fpaint/widgets/base_picker.dart';
import 'package:fpaint/widgets/material_free.dart';

/// A [BasePickerState] for a numeric value edited with an [AppSlider] over
/// the picker's [BasePicker.min]..[BasePicker.max] range and
/// [BasePicker.divisions]. Subclasses only supply [formatValue].
///
/// [T] is `double` for continuous pickers or `int` for whole-number ones;
/// slider positions are truncated to whole numbers for `int` pickers.
abstract class SliderPickerState<T extends num> extends BasePickerState<T> {
  @override
  T clampValue(T value) => value.clamp(widget.min!, widget.max!) as T;

  @override
  Widget buildPickerWidget() {
    return AppSlider(
      value: currentValue.toDouble(),
      min: widget.min!.toDouble(),
      max: widget.max!.toDouble(),
      divisions: widget.divisions,
      onChanged: (double value) => updateValue(_fromSlider(value)),
    );
  }

  /// Converts a slider position back to [T]. Compares the reified type
  /// argument rather than testing the runtime value, because on the web a
  /// whole-valued `double` also reports `is int`.
  T _fromSlider(double value) => (T == int ? value.toInt() : value) as T;
}
