import 'package:flutter/material.dart';

/// Draws a transparent background grid on the canvas.
/// The grid is composed of alternating grey and transparent squares,
/// with the size of each square determined by the canvas size and a fixed cell size.
/// The grid is clipped to the canvas bounds and is drawn using the provided Canvas object.
void drawTransaparentBackground(
  final Canvas canvas,
  final Offset offset,
  final Size size,
) {
  final double cellSize = size.width / ((size.width / 10.0).floor());
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
          Paint()..color = Colors.grey.shade400,
        );
      }
    }
  }
  canvas.restore();
}
