import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fpaint/models/user_action.dart';

class Selector {
  bool isVisible = false;
  Path path = Path();
  bool isMoving = false;

  void addPosition(final Offset position) {
    isVisible = true;
    if (isMoving) {
      // debugPrint('Selector isMoving - addPosition ${path.getBounds().topLeft}');
      final r = Rect.fromPoints(path.getBounds().topLeft, position);
      path = Path();
      path.addRect(r);
    } else {
      // debugPrint('Selector start from $position');
      path = Path();
      path.addRect(Rect.fromPoints(position, position));
      isMoving = true;
    }
  }
}

void renderPencil(
  final Canvas canvas,
  final UserAction userAction,
) {
  final Paint paint = Paint();
  paint.color = userAction.brushColor;
  paint.strokeWidth = userAction.brushSize;
  paint.style = PaintingStyle.stroke;
  paint.strokeCap = StrokeCap.round;
  paint.blendMode = BlendMode.src;
  canvas.drawLine(
    userAction.positions.first,
    userAction.positions.last,
    paint,
  );
}

void renderRectangle(
  final Canvas canvas,
  final UserAction userAction,
) {
  final Paint paint = Paint();
  paint.color = userAction.fillColor;
  paint.strokeCap = StrokeCap.round;
  paint.strokeWidth = userAction.brushSize;
  paint.style = PaintingStyle.fill;

  if (userAction.positions.length == 2) {
    final rect = Rect.fromPoints(
      userAction.positions.first,
      userAction.positions.last,
    );
    canvas.drawRect(rect, paint);
    paint.style = PaintingStyle.stroke;
    paint.color = userAction.brushColor;
    final path = Path()..addRect(rect);
    applyBrushStyle(canvas, paint, path, userAction);
  }
}

void renderCircle(
  final Canvas canvas,
  final UserAction userAction,
) {
  final Paint paint = Paint();
  paint.color = userAction.fillColor;
  paint.strokeCap = StrokeCap.round;
  paint.strokeWidth = userAction.brushSize;
  paint.style = PaintingStyle.fill;

  final double radius =
      (userAction.positions.first - userAction.positions.last).distance / 2;
  final Offset center = Offset(
    (userAction.positions.first.dx + userAction.positions.last.dx) / 2,
    (userAction.positions.first.dy + userAction.positions.last.dy) / 2,
  );
  canvas.drawCircle(center, radius, paint);
  paint.style = PaintingStyle.stroke;
  paint.color = userAction.brushColor;
  final path = Path()
    ..addOval(
      Rect.fromCircle(
        center: center,
        radius: radius,
      ),
    );
  applyBrushStyle(canvas, paint, path, userAction);
}

void renderPath(
  final Canvas canvas,
  final UserAction userAction,
) {
  final Paint paint = Paint();
  paint.color = userAction.fillColor;
  paint.style = PaintingStyle.stroke;
  paint.strokeCap = StrokeCap.round;
  paint.strokeWidth = userAction.brushSize;

  final Path path = Path()
    ..moveTo(
      userAction.positions.first.dx,
      userAction.positions.first.dy,
    );
  for (final Offset position in userAction.positions) {
    path.lineTo(position.dx, position.dy);
  }
  paint.style = PaintingStyle.stroke;
  paint.color = userAction.brushColor;
  applyBrushStyle(canvas, paint, path, userAction);
}

void renderLine(
  final Canvas canvas,
  final UserAction userAction,
) {
  final Paint paint = Paint();
  paint.color = userAction.fillColor;
  paint.strokeCap = StrokeCap.round;
  paint.strokeWidth = userAction.brushSize;
  paint.style = PaintingStyle.stroke;

  final Path path = Path()
    ..moveTo(userAction.positions.first.dx, userAction.positions.first.dy)
    ..lineTo(userAction.positions.last.dx, userAction.positions.last.dy);
  paint.color = userAction.brushColor;
  applyBrushStyle(canvas, paint, path, userAction);
}

void renderEraser(
  final Canvas canvas,
  final UserAction userAction,
) {
  final Paint paint = Paint();
  paint.color = userAction.fillColor;
  paint.strokeCap = StrokeCap.round;
  paint.strokeWidth = userAction.brushSize;
  paint.style = PaintingStyle.stroke;

  paint.blendMode = BlendMode.clear;
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = userAction.brushSize;
  canvas.drawLine(
    userAction.positions.first,
    userAction.positions.last,
    paint,
  );
}

void renderImage(final Canvas canvas, final UserAction userAction) {
  final Paint paint = Paint();
  paint.color = userAction.fillColor;
  paint.strokeCap = StrokeCap.round;
  paint.strokeWidth = userAction.brushSize;
  paint.style = PaintingStyle.stroke;

  if (userAction.image != null) {
    canvas.drawImage(userAction.image!, userAction.positions.first, Paint());
  }
}

void renderSelector(
  final Canvas canvas,
  final Selector selector,
) {
  if (selector.isVisible) {
    final Paint paint = Paint();
    paint.color = Colors.transparent;
    paint.strokeCap = StrokeCap.square;
    paint.strokeWidth = 1;
    paint.style = PaintingStyle.fill;
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.blueGrey;

    drawPath(
      selector.path,
      canvas,
      paint,
      4,
      4,
    );
  }
}

void applyBrushStyle(
  final Canvas canvas,
  final Paint paint,
  final Path path,
  final UserAction userAction,
) {
  if (userAction.brushStyle == BrushStyle.dash) {
    drawPath(
      path,
      canvas,
      paint,
      userAction.brushSize * 3,
      userAction.brushSize * 2,
    );
  } else {
    canvas.drawPath(path, paint);
  }
}

void drawPath(
  final Path path,
  final Canvas canvas,
  final Paint paint,
  final double dashWidth,
  final double dashGap,
) {
  final Path dashedPath = createDashedPath(
    path,
    dashWidth: dashWidth,
    dashGap: dashGap,
  );
  canvas.drawPath(dashedPath, paint);
}

Path createDashedPath(
  final Path source, {
  required final double dashWidth,
  required final double dashGap,
}) {
  final Path dashedPath = Path();
  for (final PathMetric pathMetric in source.computeMetrics()) {
    double distance = 0.0;
    while (distance < pathMetric.length) {
      final double nextDashLength = distance + dashWidth;
      dashedPath.addPath(
        pathMetric.extractPath(
          distance,
          nextDashLength.clamp(0.0, pathMetric.length),
        ),
        Offset.zero,
      );
      distance = nextDashLength + dashGap;
    }
  }
  return dashedPath;
}
