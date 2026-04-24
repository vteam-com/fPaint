import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

/// A slider widget replacing Material [Slider].
///
/// Uses [GestureDetector] for drag interaction and [CustomPaint] for rendering.
class AppSlider extends StatelessWidget {
  const AppSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.activeColor,
    this.inactiveColor,
  });
  final Color? activeColor;
  final int? divisions;
  final Color? inactiveColor;
  final double max;
  final double min;
  final ValueChanged<double>? onChanged;
  final double value;
  @override
  Widget build(final BuildContext context) {
    return SizedBox(
      height: AppLayout.sliderHeight,
      child: LayoutBuilder(
        builder: (final BuildContext _, final BoxConstraints constraints) {
          final double trackWidth = constraints.maxWidth;
          final double fraction = (value - min) / (max - min);

          return GestureDetector(
            onPanStart: (final DragStartDetails details) => _handleDrag(details.localPosition.dx, trackWidth),
            onPanUpdate: (final DragUpdateDetails details) => _handleDrag(details.localPosition.dx, trackWidth),
            child: CustomPaint(
              size: Size(trackWidth, AppLayout.sliderHeight),
              painter: _SliderPainter(
                fraction: fraction,
                activeColor: activeColor ?? AppColors.secondary,
                inactiveColor: inactiveColor ?? AppColors.surfaceVariant,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Converts a horizontal drag offset [dx] within [trackWidth] into a clamped,
  /// optionally snapped value and notifies [onChanged].
  void _handleDrag(final double dx, final double trackWidth) {
    if (onChanged == null) {
      return;
    }
    double newFraction = dx / trackWidth;
    newFraction = newFraction.clamp(0.0, 1.0);

    double newValue = min + newFraction * (max - min);
    if (divisions != null && divisions! > 0) {
      final double step = (max - min) / divisions!;
      newValue = (newValue / step).roundToDouble() * step;
    }
    onChanged!(newValue.clamp(min, max));
  }
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.fraction,
    required this.activeColor,
    required this.inactiveColor,
  });

  static const double _trackHeight = 4.0;
  static const double _thumbRadius = 8.0;
  static const double _trackRadius = 2.0;

  final double fraction;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(final Canvas canvas, final Size size) {
    final double centerY = size.height / AppMath.pair;
    final double thumbX = fraction * size.width;

    // Inactive track.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, centerY - _trackHeight / AppMath.pair, size.width, _trackHeight),
        const Radius.circular(_trackRadius),
      ),
      Paint()..color = inactiveColor,
    );

    // Active track.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, centerY - _trackHeight / AppMath.pair, thumbX, _trackHeight),
        const Radius.circular(_trackRadius),
      ),
      Paint()..color = activeColor,
    );

    // Thumb.
    canvas.drawCircle(
      Offset(thumbX, centerY),
      _thumbRadius,
      Paint()..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(covariant final _SliderPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
