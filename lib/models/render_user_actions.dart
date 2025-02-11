import 'dart:ui';

import 'package:fpaint/widgets/brush_style_picker.dart';

void renderPencil(
  final Canvas canvas,
  final Offset p1,
  final Offset p2,
  final Color brushColor,
  final double brushSize,
) {
  final Paint paint = Paint();
  paint.color = brushColor;
  paint.strokeWidth = brushSize;
  paint.style = PaintingStyle.stroke;
  paint.strokeCap = StrokeCap.round;
  paint.blendMode = BlendMode.src;
  canvas.drawLine(
    p1,
    p2,
    paint,
  );
}

void renderRectangle(
  final Canvas canvas,
  final Offset p1,
  final Offset p2,
  final Color brushColor,
  final double brushSize,
  final BrushStyle brushStyle,
  final Color fillColor,
) {
  // Draw the base rectangle
  final Paint paint = Paint();
  paint.color = fillColor;
  paint.strokeCap = StrokeCap.round;
  paint.strokeWidth = brushSize;
  paint.style = PaintingStyle.fill;
  final rect = Rect.fromPoints(p1, p2);
  canvas.drawRect(rect, paint);

  // Draw the path arround the rectangle
  paint.style = PaintingStyle.stroke;
  paint.color = brushColor;
  final path = Path()..addRect(rect);
  drawPathWithBrushStyle(
    canvas,
    paint,
    path,
    brushStyle,
    brushSize,
  );
}

void renderCircle(
  final Canvas canvas,
  final Offset p1,
  final Offset p2,
  final Color fillColor,
  final double brushSize,
  final Color brushColor,
  final BrushStyle brushStyle,
) {
  final Paint paint = Paint();
  paint.color = fillColor;
  paint.strokeCap = StrokeCap.round;
  paint.strokeWidth = brushSize;
  paint.style = PaintingStyle.fill;

  final double radius = (p1 - p2).distance / 2;
  final Offset center = Offset(
    (p1.dx + p2.dx) / 2,
    (p1.dy + p2.dy) / 2,
  );
  canvas.drawCircle(center, radius, paint);
  paint.style = PaintingStyle.stroke;
  paint.color = brushColor;
  final path = Path()
    ..addOval(
      Rect.fromCircle(
        center: center,
        radius: radius,
      ),
    );
  drawPathWithBrushStyle(
    canvas,
    paint,
    path,
    brushStyle,
    brushSize,
  );
}

void renderPath(
  final Canvas canvas,
  final List<Offset> positions,
  final Color brushColor,
  final double brushSize,
  final BrushStyle brushStyle,
  final Color fillColor,
) {
  final Paint paint = Paint();
  paint.color = fillColor;
  paint.style = PaintingStyle.stroke;
  paint.strokeCap = StrokeCap.round;
  paint.strokeWidth = brushSize;

  final Path path = Path()
    ..moveTo(
      positions.first.dx,
      positions.first.dy,
    );
  for (final Offset position in positions) {
    path.lineTo(position.dx, position.dy);
  }
  paint.style = PaintingStyle.stroke;
  paint.color = brushColor;
  drawPathWithBrushStyle(canvas, paint, path, brushStyle, brushSize);
}

void renderLine(
  final Canvas canvas,
  final Offset p1,
  final Offset p2,
  final Color brushColor,
  final double brushSize,
  final BrushStyle brushStyle,
  final Color fillColor,
) {
  final Paint paint = Paint();
  paint.color = fillColor;
  paint.strokeCap = StrokeCap.round;
  paint.strokeWidth = brushSize;
  paint.style = PaintingStyle.stroke;

  final Path path = Path()
    ..moveTo(p1.dx, p1.dy)
    ..lineTo(p2.dx, p2.dy);
  paint.color = brushColor;
  drawPathWithBrushStyle(
    canvas,
    paint,
    path,
    brushStyle,
    brushSize,
  );
}

void renderEraser(
  final Canvas canvas,
  final Offset p1,
  final Offset p2,
  final double brushSize,
) {
  final Paint paint = Paint();

  paint.blendMode = BlendMode.clear;
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = brushSize;
  paint.strokeCap = StrokeCap.round;

  canvas.drawLine(p1, p2, paint);
}

void renderImage(
  final Canvas canvas,
  final Offset topLeftPosition,
  final Image image,
) {
  canvas.drawImage(image, topLeftPosition, Paint());
}

void renderFill(
  final Canvas canvas,
  final Offset position,
  final Color fillColor,
  final Image image,
) {
  final Paint paint = Paint();
  paint.color = fillColor;
  // paint.strokeCap = StrokeCap.round;
  // paint.strokeWidth = brushSize;
  // paint.style = PaintingStyle.stroke;
  renderImage(canvas, position, image);
}

void drawPathWithBrushStyle(
  final Canvas canvas,
  final Paint paint,
  final Path path,
  final BrushStyle brushStyle,
  final double brushSize,
) {
  if (brushStyle == BrushStyle.dash) {
    drawPath(
      path,
      canvas,
      paint,
      brushSize * 3,
      brushSize * 2,
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
