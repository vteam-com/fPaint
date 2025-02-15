import 'dart:ui';
import 'package:fpaint/widgets/brush_style_picker.dart';

void renderPencil(
  final Canvas canvas,
  final Offset p1,
  final Offset p2,
  final MyBrush brush,
) {
  final Paint paint = Paint();
  paint.color = brush.color;
  paint.strokeWidth = brush.size;
  paint.style = PaintingStyle.stroke;
  paint.strokeCap = StrokeCap.round;
  paint.blendMode = BlendMode.src;
  canvas.drawLine(
    p1,
    p2,
    paint,
  );
}

void renderPencilEraser(
  final Canvas canvas,
  final Offset p1,
  final Offset p2,
  final MyBrush brush,
) {
  final Paint paint = Paint();
  paint.strokeWidth = brush.size;
  paint.style = PaintingStyle.stroke;
  paint.strokeCap = StrokeCap.round;
  paint.blendMode = BlendMode.clear;
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
  final MyBrush brush,
  final Color fillColor,
) {
  // Draw the base rectangle
  final Paint paint = Paint();
  paint.color = fillColor;
  paint.strokeCap = StrokeCap.round;
  paint.strokeWidth = brush.size;
  paint.style = PaintingStyle.fill;
  final rect = Rect.fromPoints(p1, p2);
  canvas.drawRect(rect, paint);

  // Draw the path arround the rectangle
  paint.style = PaintingStyle.stroke;
  paint.color = brush.color;
  final path = Path()..addRect(rect);
  drawPathWithBrushStyle(
    canvas,
    paint,
    path,
    brush.style,
    brush.size,
  );
}

void renderCircle(
  final Canvas canvas,
  final Offset p1,
  final Offset p2,
  final MyBrush brush,
  final Color fillColor,
) {
  final Paint paint = Paint();
  paint.color = fillColor;
  paint.strokeCap = StrokeCap.round;
  paint.strokeWidth = brush.size;
  paint.style = PaintingStyle.fill;

  final double radius = (p1 - p2).distance / 2;
  final Offset center = Offset(
    (p1.dx + p2.dx) / 2,
    (p1.dy + p2.dy) / 2,
  );
  canvas.drawCircle(center, radius, paint);
  paint.style = PaintingStyle.stroke;
  paint.color = brush.color;
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
    brush.style,
    brush.size,
  );
}

void renderPath(
  final Canvas canvas,
  final List<Offset> positions,
  final MyBrush brush,
  final Color fillColor,
) {
  final Paint paint = Paint();
  paint.color = fillColor;
  paint.style = PaintingStyle.stroke;
  paint.strokeCap = StrokeCap.round;
  paint.strokeWidth = brush.size;

  final Path path = Path()
    ..moveTo(
      positions.first.dx,
      positions.first.dy,
    );
  for (final Offset position in positions) {
    path.lineTo(position.dx, position.dy);
  }
  paint.style = PaintingStyle.stroke;
  paint.color = brush.color;
  drawPathWithBrushStyle(canvas, paint, path, brush.style, brush.size);
}

void renderLine(
  final Canvas canvas,
  final Offset p1,
  final Offset p2,
  final MyBrush brush,
  final Color fillColor,
) {
  final Paint paint = Paint();
  paint.color = fillColor;
  paint.strokeCap = StrokeCap.round;
  paint.strokeWidth = brush.size;
  paint.style = PaintingStyle.stroke;

  final Path path = Path()
    ..moveTo(p1.dx, p1.dy)
    ..lineTo(p2.dx, p2.dy);
  paint.color = brush.color;
  drawPathWithBrushStyle(
    canvas,
    paint,
    path,
    brush.style,
    brush.size,
  );
}

void renderRegion(final Canvas canvas, Path path, Color fillColor) {
  final Paint paint = Paint();
  paint.color = fillColor;
  paint.style = PaintingStyle.fill;
  canvas.drawPath(path, paint);
}

void renderRegionErase(final Canvas canvas, Path path) {
  final Paint paint = Paint();
  paint.color = const Color(0x00000000);
  paint.blendMode = BlendMode.clear;
  paint.style = PaintingStyle.fill;
  canvas.drawPath(path, paint);
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
    drawPathDash(
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

void drawPathDash(
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
