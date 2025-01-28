import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ContainerSlider extends StatefulWidget {
  const ContainerSlider({
    super.key,
    this.minValue = 0.0,
    this.maxValue = 100.0,
    this.initialValue = 50.0,
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

  void _adjustValue(double delta) {
    setState(() {
      currentValue =
          (currentValue + delta).clamp(widget.minValue, widget.maxValue);
    });
    widget.onChanged(currentValue);
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        _HorizontalDragRecognizer:
            GestureRecognizerFactoryWithHandlers<_HorizontalDragRecognizer>(
          () => _HorizontalDragRecognizer(),
          (instance) {
            instance
              ..onStart = (_) {
                widget.onSlideStart(); // Pause reordering.
              }
              ..onUpdate = (details) {
                _adjustValue(
                  details.primaryDelta! * 0.2,
                ); // Adjust sensitivity.
              }
              ..onEnd = (_) {
                widget.onSlideEnd(); // Resume reordering.
                widget.onChangeEnd(currentValue);
              };
          },
        ),
      },
      child: Container(
        padding: const EdgeInsets.all(1.0),
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(3.0),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
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
                  currentValue.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 14,
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
  void rejectGesture(int pointer) {
    // Accept gesture even if it's competing with other gestures.
    acceptGesture(pointer);
  }
}
