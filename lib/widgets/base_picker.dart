import 'package:flutter/material.dart';

/// A generic base picker widget that can handle different value types.
abstract class BasePicker<T> extends StatefulWidget {
  /// Creates a [BasePicker].
  const BasePicker({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.min,
    this.max,
    this.divisions,
  });

  /// The title of the picker.
  final String title;

  /// The current value of the picker.
  final T value;

  /// A callback that is called when the value of the picker changes.
  final ValueChanged<T> onChanged;

  /// The minimum value of the picker (optional).
  final T? min;

  /// The maximum value of the picker (optional).
  final T? max;

  /// The number of divisions for the slider (optional).
  final int? divisions;

  /// Creates the state for this picker.
  @override
  BasePickerState<T> createState();

  /// Whether this picker requires min/max bounds.
  bool get requiresBounds => true;
}

/// The base state for picker widgets.
abstract class BasePickerState<T> extends State<BasePicker<T>> {
  late T _value;

  /// Gets the current value.
  T get currentValue => _value;

  @override
  void initState() {
    super.initState();
    _value = clampValue(widget.value);
  }

  @override
  void didUpdateWidget(covariant final BasePicker<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value || oldWidget.min != widget.min || oldWidget.max != widget.max) {
      setState(() {
        _value = clampValue(widget.value);
      });
    }
  }

  /// Clamps the value to the min/max bounds if they are provided.
  T clampValue(final T value);

  /// Builds the picker UI.
  @override
  Widget build(final BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 20,
      children: <Widget>[
        Text('${widget.title}: ${formatValue(_value)}'),
        buildPickerWidget(),
      ],
    );
  }

  /// Builds the specific picker widget (slider, dropdown, etc.).
  Widget buildPickerWidget();

  /// Formats the value for display.
  String formatValue(final T value);

  /// Updates the value and notifies the parent.
  void updateValue(final T newValue) {
    final T clampedValue = clampValue(newValue);
    setState(() {
      _value = clampedValue;
    });
    widget.onChanged(clampedValue);
  }
}

/// Shows a dialog containing a picker widget.
Future<T?> showPickerDialog<T>({
  required final BuildContext context,
  required final String title,
  required final Widget content,
}) {
  return showDialog<T>(
    context: context,
    builder: (final BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: IntrinsicHeight(
          child: content,
        ),
      );
    },
  );
}
