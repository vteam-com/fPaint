import 'package:flutter/material.dart';

class TransparentPaper extends StatelessWidget {
  const TransparentPaper({super.key, this.patternSize = 10.0});
  final double patternSize;

  @override
  Widget build(final BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: TransparentBackgroundPainter(patternSize),
    );
  }
}

class TransparentBackgroundPainter extends CustomPainter {
  TransparentBackgroundPainter([this.patternSize = 10.0]);
  final double patternSize;

  @override
  void paint(final Canvas canvas, final Size size) {
    if (size.isFinite) {
      drawTransaparentBackgroundOffsetAndSize(
        canvas,
        const Offset(0, 0),
        size,
        patternSize,
      );
    }
  }

  @override
  bool shouldRepaint(TransparentBackgroundPainter oldDelegate) => true;
}

/// Draws a transparent background grid on the canvas using the provided left, top, width, and height parameters.
/// The grid is composed of alternating grey and transparent squares,
/// with the size of each square determined by the canvas size and a fixed cell size.
/// The grid is clipped to the canvas bounds and is drawn using the provided Canvas object.
void drawTransaparentBackgroundLTWH(
  final Canvas canvas,
  final double left,
  final double top,
  final double width,
  final double height, {
  patternSize = 10,
}) {
  drawTransaparentBackgroundOffsetAndSize(
    canvas,
    Offset(left, top),
    Size(width, height),
  );
}

/// Draws a transparent background grid on the canvas.
/// The grid is composed of alternating grey and transparent squares,
/// with the size of each square determined by the canvas size and a fixed cell size.
/// The grid is clipped to the canvas bounds and is drawn using the provided Canvas object.
void drawTransaparentBackgroundOffsetAndSize(
  final Canvas canvas,
  final Offset offset,
  final Size size, [
  patternSize = 10,
]) {
  final double cellSize = size.width / ((size.width / patternSize).floor());
  canvas.save();
  canvas.clipRect(
    Rect.fromLTWH(
      offset.dx,
      offset.dy,
      size.width,
      size.height,
    ),
  );
  for (double x = 0; x < size.width; x += cellSize) {
    for (double y = 0; y < size.height; y += cellSize) {
      if ((x ~/ cellSize + y ~/ cellSize) % 2 == 0) {
        canvas.drawRect(
          Rect.fromLTWH(
            x + offset.dx,
            y + offset.dy,
            cellSize,
            cellSize,
          ),
          Paint()..color = Colors.grey.shade600,
        );
      }
    }
  }
  canvas.restore();
}
