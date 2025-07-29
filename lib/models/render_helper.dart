import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/widgets/brush_style_picker.dart';

/// Renders a pencil stroke on the canvas.
///
/// The [canvas] parameter is the canvas to draw on.
/// The [p1] parameter is the starting point of the stroke.
/// The [p2] parameter is the ending point of the stroke.
/// The [brush] parameter is the brush to use for the stroke.
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

/// Renders a pencil eraser stroke on the canvas.
///
/// The [canvas] parameter is the canvas to draw on.
/// The [p1] parameter is the starting point of the stroke.
/// The [p2] parameter is the ending point of the stroke.
/// The [brush] parameter is the brush to use for the stroke.
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

/// Renders a rectangle on the canvas.
///
/// The [canvas] parameter is the canvas to draw on.
/// The [p1] parameter is the top-left point of the rectangle.
/// The [p2] parameter is the bottom-right point of the rectangle.
/// The [brush] parameter is the brush to use for the stroke.
/// The [fillColor] parameter is the fill color of the rectangle.
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
  final Rect rect = Rect.fromPoints(p1, p2);
  canvas.drawRect(rect, paint);

  // Draw the path arround the rectangle
  paint.style = PaintingStyle.stroke;
  paint.color = brush.color;
  final Path path = Path()..addRect(rect);
  drawPathWithBrushStyle(
    canvas,
    paint,
    path,
    brush.style,
    brush.size,
  );
}

/// Renders a circle on the canvas.
///
/// The [canvas] parameter is the canvas to draw on.
/// The [p1] parameter is one point on the circle.
/// The [p2] parameter is another point on the circle.
/// The [brush] parameter is the brush to use for the stroke.
/// The [fillColor] parameter is the fill color of the circle.
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
  final Path path = Path()
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

/// Renders a path on the canvas.
///
/// The [canvas] parameter is the canvas to draw on.
/// The [positions] parameter is the list of points that make up the path.
/// The [brush] parameter is the brush to use for the stroke.
/// The [fillColor] parameter is the fill color of the path.
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

/// Renders a line on the canvas.
///
/// The [canvas] parameter is the canvas to draw on.
/// The [p1] parameter is the starting point of the line.
/// The [p2] parameter is the ending point of the line.
/// The [brush] parameter is the brush to use for the stroke.
/// The [fillColor] parameter is the fill color of the line.
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

/// Renders a region on the canvas.
///
/// The [canvas] parameter is the canvas to draw on.
/// The [path] parameter is the path to render.
/// The [fillColor] parameter is the fill color of the region.
/// The [gradient] parameter is the gradient to use for the fill.
void renderRegion(
  final Canvas canvas,
  final Path path,
  final Color? fillColor,
  final Gradient? gradient,
) {
  final Paint paint = Paint();
  if (gradient != null) {
    paint.shader = gradient.createShader(path.getBounds());
  } else {
    paint.color = fillColor!;
  }
  paint.style = PaintingStyle.fill;
  canvas.drawPath(path, paint);
}

/// Renders a region erase on the canvas.
///
/// The [canvas] parameter is the canvas to draw on.
/// The [path] parameter is the path to render.
void renderRegionErase(final Canvas canvas, final Path path) {
  final Paint paint = Paint();
  paint.color = const Color(0x00000000);
  paint.blendMode = BlendMode.clear;
  paint.style = PaintingStyle.fill;
  canvas.drawPath(path, paint);
}

/// Renders an image on the canvas.
///
/// The [canvas] parameter is the canvas to draw on.
/// The [topLeftPosition] parameter is the top-left position of the image.
/// The [image] parameter is the image to render.
void renderImage(
  final Canvas canvas,
  final Offset topLeftPosition,
  final ui.Image image,
) {
  canvas.drawImage(image, topLeftPosition, Paint());
}

/// Renders a fill on the canvas.
///
/// The [canvas] parameter is the canvas to draw on.
/// The [position] parameter is the position of the fill.
/// The [fillColor] parameter is the fill color.
/// The [image] parameter is the image to use for the fill.
void renderFill(
  final Canvas canvas,
  final Offset position,
  final Color fillColor,
  final ui.Image image,
) {
  final Paint paint = Paint();
  paint.color = fillColor;
  renderImage(canvas, position, image);
}

/// Draws a path with a brush style.
///
/// The [canvas] parameter is the canvas to draw on.
/// The [paint] parameter is the paint to use for the stroke.
/// The [path] parameter is the path to draw.
/// The [brushStyle] parameter is the brush style to use.
/// The [brushSize] parameter is the brush size to use.
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

/// Draws a dashed path.
///
/// The [path] parameter is the path to draw.
/// The [canvas] parameter is the canvas to draw on.
/// The [paint] parameter is the paint to use for the stroke.
/// The [dashWidth] parameter is the width of the dashes.
/// The [dashGap] parameter is the gap between the dashes.
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

/// Creates a dashed path from a source path.
///
/// The [source] parameter is the path to create the dashed path from.
/// The [dashWidth] parameter is the width of the dashes.
/// The [dashGap] parameter is the gap between the dashes.
Path createDashedPath(
  final Path source, {
  required final double dashWidth,
  required final double dashGap,
}) {
  final Path dashedPath = Path();
  for (final ui.PathMetric pathMetric in source.computeMetrics()) {
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

/// Renders text on the canvas.
///
/// The [canvas] parameter is the canvas to draw on.
/// The [textObject] parameter is the text object to render.
void renderText(
  final Canvas canvas,
  final TextObject textObject,
) {
  if (textObject.text.isEmpty || textObject.text == 'Type here...') {
    return; // Don't render empty or placeholder text
  }

  final ui.ParagraphBuilder paragraphBuilder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textAlign: TextAlign.left,
            fontSize: textObject.size,
            height: 1.2, // Better line height for readability
          ),
        )
        ..pushStyle(
          ui.TextStyle(
            color: textObject.color,
            fontWeight: textObject.fontWeight,
            fontStyle: textObject.fontStyle,
            fontSize: textObject.size,
          ),
        )
        ..addText(textObject.text);

  final ui.Paragraph paragraph = paragraphBuilder.build();

  // Use a more reasonable max width for text layout
  final double maxWidth = textObject.text.length > 50 ? 800 : 1000;
  paragraph.layout(ui.ParagraphConstraints(width: maxWidth));

  canvas.drawParagraph(paragraph, textObject.position);
}
