/// Wraps a [Widget] in a transparent paper-like container with a rounded border.
///
/// The [transparentPaperContainer] function takes a [Widget] and returns a new [Widget] that is wrapped in a transparent paper-like container with a rounded border. The container has a transparent background with a subtle grid pattern, and the child [Widget] is centered within the container.
///
/// The [radius] parameter can be used to adjust the border radius of the container.
///
/// Example usage:
///
/// transparentPaperContainer(
///   Text('Hello, World!'),
///   radius: 16.0,
/// )
///
library;

import 'package:flutter/material.dart';

Widget transparentPaperContainer(
  final Widget child, {
  final double radius = 8,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Padding(
      padding: const EdgeInsets.all(1.0),
      child: Stack(
        children: <Widget>[
          const TransparentPaper(patternSize: 4),
          Container(
            alignment: Alignment.center,
            child: child,
          ),
        ],
      ),
    ),
  );
}

class TransparentPaper extends StatelessWidget {
  const TransparentPaper({super.key, this.patternSize = 10});
  final int patternSize;

  @override
  Widget build(final BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: TransparentBackgroundPainter(patternSize),
    );
  }
}

class TransparentBackgroundPainter extends CustomPainter {
  TransparentBackgroundPainter([this.patternSize = 10]);
  final int patternSize;

  @override
  void paint(final Canvas canvas, final Size size) {
    if (size.isFinite) {
      drawTransaparentBackgroundOffsetAndSize(
        canvas: canvas,
        size: size,
        patternSize: patternSize,
      );
    }
  }

  @override
  bool shouldRepaint(final TransparentBackgroundPainter oldDelegate) => true;
}

/// Draws a transparent background grid on the canvas.
/// The grid is composed of alternating grey and transparent squares,
/// with the size of each square determined by the canvas size and a fixed cell size.
/// The grid is clipped to the canvas bounds and is drawn using the provided Canvas object.
void drawTransaparentBackgroundOffsetAndSize({
  required final Canvas canvas,
  required final Size size,
  final Offset offset = Offset.zero,
  final int patternSize = 10,
}) {
  final double cellSize = size.width / (size.width / patternSize);
  canvas.save();
  final Rect containerRect = Rect.fromLTWH(
    offset.dx,
    offset.dy,
    size.width,
    size.height,
  );

  canvas.clipRect(containerRect);
  final Paint paintBackground = Paint()..color = Colors.grey.shade300;
  canvas.drawRect(containerRect, paintBackground);

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
