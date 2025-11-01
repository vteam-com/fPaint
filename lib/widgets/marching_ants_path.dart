import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A widget that displays an animated "marching ants" path.
///
/// The "marching ants" effect is a visual effect used to indicate a selection
/// or boundary, typically consisting of a dashed line that appears to be
/// moving or "marching" along the path.
class AnimatedMarchingAntsPath extends StatefulWidget {
  /// Creates an [AnimatedMarchingAntsPath].
  ///
  /// The [path] parameter specifies the path to draw.
  /// The [linePointStart] and [linePointEnd] parameters specify the start and end points of a line to draw.
  const AnimatedMarchingAntsPath({
    super.key,
    this.path,
    this.linePointStart,
    this.linePointEnd,
  });

  /// The end point of a line to draw.
  final Offset? linePointEnd;

  /// The start point of a line to draw.
  final Offset? linePointStart;

  /// The path to draw.
  final Path? path;

  @override
  AnimatedMarchingAntsPathState createState() => AnimatedMarchingAntsPathState();
}

/// The state for [AnimatedMarchingAntsPath].
class AnimatedMarchingAntsPathState extends State<AnimatedMarchingAntsPath> with SingleTickerProviderStateMixin {
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
            linePointStart: widget.linePointStart,
            linePointEnd: widget.linePointEnd,
            phase: _controller.value * 10,
          ),
        );
      },
    );
  }
}

/// A custom painter that draws a "marching ants" path.
class MarchingAntsPainter extends CustomPainter {
  /// Creates a [MarchingAntsPainter].
  ///
  /// The [path] parameter specifies the path to draw.
  /// The [phase] parameter specifies the animation phase.
  /// The [linePointStart] and [linePointEnd] parameters specify the start and end points of a line to draw.
  MarchingAntsPainter({
    required this.path,
    required this.phase,
    required this.linePointStart,
    required this.linePointEnd,
  });

  /// The path to draw.
  final Path? path;

  /// The start point of a line to draw.
  final Offset? linePointStart;

  /// The end point of a line to draw.
  final Offset? linePointEnd;

  /// The animation phase.
  final double phase;

  @override
  void paint(final Canvas canvas, final Size size) {
    // First, draw a solid white rectangle border
    final Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      // ..blendMode = BlendMode.difference
      ..style = PaintingStyle.stroke;

    if (path != null) {
      canvas.drawPath(path!, paint);

      // Now, draw the black dashes on top

      paint.color = Colors.black;
      paint.strokeCap = StrokeCap.round;

      final Path dashPath = Path();
      const double dashWidth = 4;
      const double dashSpace = 6;
      final double distance = phase;

      for (final ui.PathMetric pathMetric in path!.computeMetrics()) {
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

    if (linePointStart != null && linePointEnd != null) {
      paint.color = Colors.white;
      paint.strokeWidth = 2;
      canvas.drawLine(linePointStart!, linePointEnd!, paint);

      paint.color = Colors.black;
      paint.strokeWidth = 1;

      final double totalLength = (linePointEnd! - linePointStart!).distance;
      const double dashWidth = 4;
      const double dashSpace = 6;
      final double distance = phase;

      double segmentDistance = distance;
      while (segmentDistance < totalLength) {
        final double nextDistance = segmentDistance + dashWidth;
        final Offset start = Offset.lerp(
          linePointStart!,
          linePointEnd!,
          segmentDistance / totalLength,
        )!;
        final Offset end = Offset.lerp(
          linePointStart!,
          linePointEnd!,
          nextDistance / totalLength,
        )!;
        canvas.drawLine(start, end, paint);
        segmentDistance = nextDistance + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant final CustomPainter oldDelegate) {
    return true;
  }
}
