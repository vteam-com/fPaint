import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class AnimatedMarchingAntsPath extends StatefulWidget {
  const AnimatedMarchingAntsPath({super.key, required this.path});
  final Path path;

  @override
  AnimatedMarchingAntsPathState createState() =>
      AnimatedMarchingAntsPathState();
}

class AnimatedMarchingAntsPathState extends State<AnimatedMarchingAntsPath>
    with SingleTickerProviderStateMixin {
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
      builder: (final BuildContext context, final Widget? child) {
        return CustomPaint(
          painter: MarchingAntsPainter(
            path: widget.path,
            phase: _controller.value * 10,
          ),
        );
      },
    );
  }
}

class MarchingAntsPainter extends CustomPainter {
  MarchingAntsPainter({required this.path, required this.phase});

  final Path path;
  final double phase;

  @override
  void paint(final Canvas canvas, final Size size) {
    // First, draw a solid white rectangle border
    final Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      // ..blendMode = BlendMode.difference
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, paint);

    // Now, draw the black dashes on top

    paint.color = Colors.black;
    paint.strokeCap = StrokeCap.round;

    final Path dashPath = Path();
    const double dashWidth = 4;
    const double dashSpace = 6;
    final double distance = phase;

    for (final ui.PathMetric pathMetric in path.computeMetrics()) {
      double segmentDistance = distance;
      while (segmentDistance < pathMetric.length) {
        final double nextDistance = segmentDistance + dashWidth;
        dashPath.addPath(
          pathMetric.extractPath(segmentDistance, nextDistance),
          Offset.zero,
        );
        segmentDistance = nextDistance + dashSpace;
      }
    }

    // Draw black dashes over the white border
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant final CustomPainter oldDelegate) {
    return true;
  }
}
