import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

/// A loading indicator replacing Material [CircularProgressIndicator].
class AppProgressIndicator extends StatefulWidget {
  const AppProgressIndicator({super.key});

  @override
  State<AppProgressIndicator> createState() => _AppProgressIndicatorState();
}

class _AppProgressIndicatorState extends State<AppProgressIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (final BuildContext _, final Widget? _) {
        return CustomPaint(
          size: const Size(AppLayout.loaderRadius, AppLayout.loaderRadius),
          painter: _SpinnerPainter(
            progress: _controller.value,
            color: AppColors.primary,
            strokeWidth: AppLayout.loaderStrokeWidth,
          ),
        );
      },
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  static const double _startAngle = -1.5708; // -pi/2
  static const double _sweepAngle = 4.7124; // 3*pi/4 * 2

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(final Canvas canvas, final Size size) {
    final double radius = size.shortestSide / AppMath.pair;
    final Offset center = Offset(size.width / AppMath.pair, size.height / AppMath.pair);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / AppMath.pair),
      _startAngle + progress * AppMath.degreesPerFullTurn * AppMath.pi / AppMath.degreesPerHalfTurn,
      _sweepAngle,
      false,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant final _SpinnerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
