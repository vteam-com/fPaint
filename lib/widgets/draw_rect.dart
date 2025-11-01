import 'dart:math';

import 'package:flutter/material.dart';

/// A widget that draws a rectangle with dashed borders and a specified fill color.
class DashedRectangle extends StatelessWidget {
  /// Creates a [DashedRectangle].
  ///
  /// The [fillColor] parameter specifies the color to fill the rectangle with.
  /// The [width] and [height] parameters specify the width and height of the rectangle, respectively.
  const DashedRectangle({
    super.key,
    required this.fillColor,
    this.width = 100.0,
    this.height = 100.0,
  });

  /// The color to fill the rectangle with.
  final Color fillColor;

  /// The height of the rectangle.
  final double height;

  /// The width of the rectangle.
  final double width;

  @override
  Widget build(final BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _DashedRectanglePainter(fillColor: fillColor),
    );
  }
}

/// A custom painter that draws a rectangle with dashed borders and a specified fill color.
class _DashedRectanglePainter extends CustomPainter {
  /// Creates a [_DashedRectanglePainter].
  ///
  /// The [fillColor] parameter specifies the color to fill the rectangle with.
  _DashedRectanglePainter({required this.fillColor});

  /// The color to fill the rectangle with.
  final Color fillColor;

  /// The width of each dash.
  final double dashWidth = 2.0;

  /// The space between each dash.
  final double dashSpace = 0.0;

  @override
  void paint(final Canvas canvas, final Size size) {
    // Create a paint object for filling the rectangle
    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    // Draw the filled rectangle
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fillPaint);

    // Create paint objects for the black and white dashed borders
    final Paint blackPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final Paint whitePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw dashed borders
    _drawDashedLine(
      canvas,
      const Offset(0, 0),
      Offset(size.width, 0),
      blackPaint,
      whitePaint,
    ); // Top
    _drawDashedLine(
      canvas,
      Offset(0, size.height),
      Offset(size.width, size.height),
      blackPaint,
      whitePaint,
    ); // Bottom
    _drawDashedLine(
      canvas,
      const Offset(0, 0),
      Offset(0, size.height),
      blackPaint,
      whitePaint,
    ); // Left
    _drawDashedLine(
      canvas,
      Offset(size.width, 0),
      Offset(size.width, size.height),
      blackPaint,
      whitePaint,
    ); // Right
  }

  /// Draws a dashed line on the canvas.
  ///
  /// The [canvas] parameter is the canvas to draw on.
  /// The [start] parameter is the starting point of the line.
  /// The [end] parameter is the ending point of the line.
  /// The [blackPaint] parameter is the paint object to use for the black dashes.
  /// The [whitePaint] parameter is the paint object to use for the white dashes.
  void _drawDashedLine(
    final Canvas canvas,
    final Offset start,
    final Offset end,
    final Paint blackPaint,
    final Paint whitePaint,
  ) {
    final double dx = end.dx - start.dx;
    final double dy = end.dy - start.dy;
    final double distance = sqrt(dx * dx + dy * dy);
    final double dashLength = dashWidth + dashSpace;
    double progress = 0;

    bool isBlack = true;
    while (progress < distance) {
      final double nextDashEnd = progress + dashWidth;
      final double x1 = start.dx + (dx * progress / distance);
      final double y1 = start.dy + (dy * progress / distance);
      final double x2 = start.dx + (dx * nextDashEnd / distance);
      final double y2 = start.dy + (dy * nextDashEnd / distance);

      if (nextDashEnd <= distance) {
        canvas.drawLine(
          Offset(x1, y1),
          Offset(x2, y2),
          isBlack ? blackPaint : whitePaint,
        );
      } else {
        canvas.drawLine(Offset(x1, y1), end, isBlack ? blackPaint : whitePaint);
      }

      progress += dashLength;
      isBlack = !isBlack; // Alternate colors
    }
  }

  @override
  bool shouldRepaint(covariant final CustomPainter oldDelegate) => false;
}
