import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class MarchingAntsSelection extends StatefulWidget {
  const MarchingAntsSelection({super.key, required this.rect});
  final Rect rect;

  @override
  MarchingAntsSelectionState createState() => MarchingAntsSelectionState();
}

class MarchingAntsSelectionState extends State<MarchingAntsSelection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: MarchingAntsPainter(
            rect: widget.rect,
            phase: _controller.value * 10,
          ),
        );
      },
    );
  }
}

class MarchingAntsPainter extends CustomPainter {
  MarchingAntsPainter({required this.rect, required this.phase});

  final Rect rect;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    // First, draw a solid white rectangle border
    final Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, paint);

    // Now, draw the black dashes on top

    paint.color = Colors.black;
    paint.strokeCap = StrokeCap.square;

    final Path path = Path()..addRect(rect);
    final Path dashPath = Path();
    const double dashWidth = 4;
    const double dashSpace = 6;
    double distance = phase;

    for (ui.PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        final double nextDistance = distance + dashWidth;
        dashPath.addPath(
          pathMetric.extractPath(distance, nextDistance),
          Offset.zero,
        );
        distance = nextDistance + dashSpace;
      }
    }

    // Draw black dashes over the white border
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
