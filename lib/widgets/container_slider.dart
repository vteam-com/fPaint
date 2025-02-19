import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ContainerSlider extends StatefulWidget {
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
  final double minValue;
  final double maxValue;
  final double initialValue;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback onSlideStart;
  final VoidCallback onSlideEnd;
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

  void _adjustValue(final double delta) {
    setState(() {
      currentValue =
          (currentValue + delta).clamp(widget.minValue, widget.maxValue);
    });
    widget.onChanged(currentValue);
  }

  @override
  Widget build(final BuildContext context) {
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory<GestureRecognizer>>{
        _HorizontalDragRecognizer:
            GestureRecognizerFactoryWithHandlers<_HorizontalDragRecognizer>(
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

class _HorizontalDragRecognizer extends HorizontalDragGestureRecognizer {
  @override
  void rejectGesture(final int pointer) {
    // Accept gesture even if it's competing with other gestures.
    acceptGesture(pointer);
  }
}
