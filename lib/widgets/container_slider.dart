import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A custom slider widget that allows users to adjust a value by dragging horizontally within a container.
class ContainerSlider extends StatefulWidget {
  /// Creates a [ContainerSlider].
  ///
  /// The [minValue] and [maxValue] parameters define the range of the slider.
  /// The [initialValue] parameter sets the initial value of the slider.
  /// The [onChanged] parameter is a callback that is called when the value of the slider changes.
  /// The [onChangeEnd] parameter is a callback that is called when the user stops sliding.
  /// The [onSlideStart] parameter is a callback that is called when the user starts sliding.
  /// The [onSlideEnd] parameter is a callback that is called when the user stops sliding.
  /// The [child] parameter is the widget to display inside the slider.
  const ContainerSlider({
    super.key,
    this.minValue = 0.0,
    this.maxValue = 1.0,
    this.initialValue = 0.5,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onSlideStart,
    required this.onSlideEnd,
    required this.child,
  });

  /// The minimum value of the slider.
  final double minValue;

  /// The maximum value of the slider.
  final double maxValue;

  /// The initial value of the slider.
  final double initialValue;

  /// A callback that is called when the value of the slider changes.
  final ValueChanged<double> onChanged;

  /// A callback that is called when the user stops sliding.
  final ValueChanged<double> onChangeEnd;

  /// A callback that is called when the user starts sliding.
  final VoidCallback onSlideStart;

  /// A callback that is called when the user stops sliding.
  final VoidCallback onSlideEnd;

  /// The widget to display inside the slider.
  final Widget child;

  @override
  State<ContainerSlider> createState() => _ContainerSliderState();
}

class _ContainerSliderState extends State<ContainerSlider> {
  late double currentValue;
  double? initialTouchValue;

  @override
  void initState() {
    super.initState();
    currentValue = widget.initialValue.clamp(widget.minValue, widget.maxValue);
  }

  /// Adjusts the value of the slider by the given delta.
  void _adjustValue(final double delta) {
    setState(() {
      currentValue = (currentValue + delta).clamp(widget.minValue, widget.maxValue);
    });
    widget.onChanged(currentValue);
  }

  @override
  Widget build(final BuildContext context) {
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory<GestureRecognizer>>{
        _HorizontalDragRecognizer: GestureRecognizerFactoryWithHandlers<_HorizontalDragRecognizer>(
          () => _HorizontalDragRecognizer(),
          (final _HorizontalDragRecognizer instance) {
            instance
              ..onStart = (final _) {
                widget.onSlideStart(); // Pause reordering.
              }
              ..onUpdate = (final DragUpdateDetails details) {
                _adjustValue(
                  details.primaryDelta! * 0.01,
                ); // Adjust sensitivity.
              }
              ..onEnd = (final _) {
                widget.onSlideEnd(); // Resume reordering.
                widget.onChangeEnd(currentValue);
              };
          },
        ),
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(3.0),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            widget.child,
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(140),
                  borderRadius: BorderRadius.circular(2.0),
                ),
                child: Text(
                  '${(currentValue * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A custom horizontal drag gesture recognizer that accepts gestures even if they are competing with other gestures.
class _HorizontalDragRecognizer extends HorizontalDragGestureRecognizer {
  @override
  void rejectGesture(final int pointer) {
    // Accept gesture even if it's competing with other gestures.
    acceptGesture(pointer);
  }
}
