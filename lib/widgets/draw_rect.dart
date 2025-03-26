import 'dart:math';

import 'package:flutter/material.dart';

class DashedRectangle extends StatelessWidget {
  const DashedRectangle({
    super.key,
    required this.fillColor,
    this.width = 100.0,
    this.height = 100.0,
  });

  final Color fillColor;
  final double width;
  final double height;

  @override
  Widget build(final BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _DashedRectanglePainter(fillColor: fillColor),
    );
  }
}

class _DashedRectanglePainter extends CustomPainter {
  _DashedRectanglePainter({required this.fillColor});

  final Color fillColor;
  final double dashWidth = 2.0;
  final double dashSpace = 0.0;

  @override
  void paint(final Canvas canvas, final Size size) {
    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    // Draw the filled rectangle
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fillPaint);

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
