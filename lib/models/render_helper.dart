import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/brush_style.dart';
import 'package:fpaint/models/halftone_fill.dart';
import 'package:fpaint/models/text_object.dart';

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

  final double radius = (p1 - p2).distance / AppMath.pair;
  final Offset center = Offset(
    (p1.dx + p2.dx) / AppMath.pair,
    (p1.dy + p2.dy) / AppMath.pair,
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
  final HalftoneFill? halftoneFill,
) {
  final bool shouldRenderHalftone =
      halftoneFill != null &&
      halftoneFill.maxDotSizeFactor.clamp(AppMath.zero.toDouble(), AppVisual.full) > AppMath.zero;

  if (shouldRenderHalftone) {
    _renderHalftoneRegion(canvas, path, gradient, halftoneFill);
    return;
  }

  final Paint paint = Paint();
  if (gradient != null) {
    paint.shader = gradient.createShader(path.getBounds());
  } else {
    paint.color = fillColor!;
  }
  paint.style = PaintingStyle.fill;
  canvas.drawPath(path, paint);
}

/// Renders a two-color halftone fill clipped to [path].
void _renderHalftoneRegion(
  final Canvas canvas,
  final Path path,
  final Gradient? gradient,
  final HalftoneFill halftoneFill,
) {
  final Rect bounds = path.getBounds();
  if (bounds.isEmpty) {
    return;
  }

  final Paint backgroundPaint = Paint()
    ..color = halftoneFill.backgroundColor
    ..style = PaintingStyle.fill;
  canvas.drawPath(path, backgroundPaint);

  final Paint dotPaint = Paint()
    ..color = halftoneFill.dotColor
    ..style = PaintingStyle.fill;

  final double spacing = resolveHalftoneSpacing(bounds);
  final double halfSpacing = spacing * AppVisual.half;
  final double maxDotRadius =
      spacing *
      AppHalftone.maxDotRadiusFactor *
      halftoneFill.maxDotSizeFactor.clamp(AppMath.zero.toDouble(), AppVisual.full);

  if (maxDotRadius <= AppMath.zero) {
    return;
  }

  canvas.save();
  canvas.clipPath(path, doAntiAlias: true);

  int rowIndex = AppMath.zero;
  for (double y = bounds.top + halfSpacing; y < bounds.bottom; y += spacing) {
    final double rowOffset = rowIndex.isOdd ? halfSpacing : AppMath.zero.toDouble();
    for (double x = bounds.left + halfSpacing + rowOffset; x < bounds.right; x += spacing) {
      final Offset point = Offset(x, y);
      final double intensity = _halftoneIntensityAt(
        point: point,
        bounds: bounds,
        gradient: gradient,
      );
      if (intensity < AppHalftone.minDotIntensity) {
        continue;
      }

      canvas.drawCircle(point, maxDotRadius * intensity, dotPaint);
    }
    rowIndex += AppMath.one;
  }

  canvas.restore();
}

/// Resolves halftone spacing while capping total dot work for large regions.
double resolveHalftoneSpacing(final Rect bounds) {
  final double boundsArea = bounds.width * bounds.height;
  if (boundsArea <= AppMath.zero) {
    return AppHalftone.dotSpacing;
  }

  final double minimumSpacing = math.sqrt(boundsArea / AppHalftone.maxRenderDotCount);
  return math.max(AppHalftone.dotSpacing, minimumSpacing);
}

/// Samples the halftone intensity at [point] from the region's fill geometry.
double _halftoneIntensityAt({
  required final Offset point,
  required final Rect bounds,
  required final Gradient? gradient,
}) {
  if (gradient == null) {
    return AppVisual.full;
  }

  if (gradient case final LinearGradient linearGradient) {
    final Offset beginPoint = _alignmentToPoint(
      bounds,
      linearGradient.begin.resolve(TextDirection.ltr),
    );
    final Offset endPoint = _alignmentToPoint(
      bounds,
      linearGradient.end.resolve(TextDirection.ltr),
    );
    final Offset axis = endPoint - beginPoint;
    final double axisLengthSquared = (axis.dx * axis.dx) + (axis.dy * axis.dy);
    if (axisLengthSquared <= AppMath.zero) {
      return AppVisual.full;
    }

    final Offset delta = point - beginPoint;
    final double projection = ((delta.dx * axis.dx) + (delta.dy * axis.dy)) / axisLengthSquared;
    return projection.clamp(AppMath.zero.toDouble(), AppVisual.full);
  }

  if (gradient case final RadialGradient radialGradient) {
    final Offset centerPoint = _alignmentToPoint(
      bounds,
      radialGradient.center.resolve(TextDirection.ltr),
    );
    final double radius = radialGradient.radius.abs() * bounds.width;
    if (radius <= AppMath.zero) {
      return AppVisual.full;
    }

    return ((point - centerPoint).distance / radius).clamp(AppMath.zero.toDouble(), AppVisual.full);
  }

  return AppVisual.full;
}

/// Converts a gradient [alignment] into an absolute point inside [bounds].
Offset _alignmentToPoint(final Rect bounds, final Alignment alignment) {
  final double halfWidth = bounds.width * AppVisual.half;
  final double halfHeight = bounds.height * AppVisual.half;
  return Offset(
    bounds.left + ((alignment.x + AppVisual.full) * halfWidth),
    bounds.top + ((alignment.y + AppVisual.full) * halfHeight),
  );
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
  switch (brushStyle) {
    case BrushStyle.solid:
      canvas.drawPath(path, paint);
    case BrushStyle.dash:
      drawPathDash(
        path,
        canvas,
        paint,
        brushSize * AppStroke.dashWidthFactor,
        brushSize * AppStroke.dashGapFactor,
      );
    case BrushStyle.dotted:
      _drawPathDots(
        path,
        canvas,
        paint,
        brushSize,
      );
    case BrushStyle.dashDot:
      _drawPathDashDot(
        path,
        canvas,
        paint,
        brushSize,
        dotCount: 1,
      );
    case BrushStyle.slash:
      _drawPathSlashes(
        path,
        canvas,
        paint,
        brushSize,
      );
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

/// Draws circular dots along a [path].
///
/// Each dot is a filled circle with radius equal to half the stroke width.
void _drawPathDots(
  final Path path,
  final Canvas canvas,
  final Paint paint,
  final double brushSize,
) {
  final double radius = paint.strokeWidth / AppMath.pair;
  final double gap = brushSize * AppStroke.dashGapFactor;
  final Paint dotPaint = Paint()
    ..color = paint.color
    ..style = PaintingStyle.fill;

  for (final ui.PathMetric metric in path.computeMetrics()) {
    double distance = 0.0;
    while (distance < metric.length) {
      final ui.Tangent? tangent = metric.getTangentForOffset(distance);
      if (tangent != null) {
        canvas.drawCircle(tangent.position, radius, dotPaint);
      }
      distance += gap;
    }
  }
}

/// Draws a dash-dot pattern on [canvas].
///
/// Each cycle consists of one dash followed by [dotCount] dots,
/// separated by gaps proportional to [brushSize].
void _drawPathDashDot(
  final Path path,
  final Canvas canvas,
  final Paint paint,
  final double brushSize, {
  required final int dotCount,
}) {
  final double dashWidth = brushSize * AppStroke.dashWidthFactor;
  final double radius = paint.strokeWidth / AppMath.pair;
  final double gap = brushSize * AppStroke.dashGapFactor;
  final Paint dotPaint = Paint()
    ..color = paint.color
    ..style = PaintingStyle.fill;

  final Path dashPath = Path();
  for (final ui.PathMetric metric in path.computeMetrics()) {
    double distance = 0.0;
    while (distance < metric.length) {
      // Dash segment
      final double dashEnd = (distance + dashWidth).clamp(0.0, metric.length);
      dashPath.addPath(metric.extractPath(distance, dashEnd), Offset.zero);
      distance = dashEnd + gap;

      // Dot segments (circles)
      for (int i = 0; i < dotCount && distance < metric.length; i++) {
        final ui.Tangent? tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, radius, dotPaint);
        }
        distance += gap;
      }
    }
  }
  canvas.drawPath(dashPath, paint);
}

/// Draws forward-slash marks along a [path].
///
/// Each slash is a short line segment perpendicular-ish to the path direction,
/// spaced evenly along the path.
void _drawPathSlashes(
  final Path path,
  final Canvas canvas,
  final Paint paint,
  final double brushSize,
) {
  final double slashLength = paint.strokeWidth * AppStroke.dashWidthFactor;
  final double gap = brushSize * AppStroke.dashGapFactor;
  final double halfSlash = slashLength / AppMath.pair;

  for (final ui.PathMetric metric in path.computeMetrics()) {
    double distance = 0.0;
    while (distance < metric.length) {
      final ui.Tangent? tangent = metric.getTangentForOffset(distance);
      if (tangent != null) {
        final Offset center = tangent.position;
        // Draw a forward slash (/) — tilted line from bottom-left to top-right
        canvas.drawLine(
          Offset(center.dx - halfSlash, center.dy + halfSlash),
          Offset(center.dx + halfSlash, center.dy - halfSlash),
          paint,
        );
      }
      distance += gap;
    }
  }
}

/// Renders text on the canvas.
///
/// The [canvas] parameter is the canvas to draw on.
/// The [textObject] parameter is the text object to render.
void renderText(
  final Canvas canvas,
  final TextObject textObject,
) {
  if (textObject.text.isEmpty) {
    return; // Don't render empty or placeholder text
  }

  final ui.Paragraph paragraph = textObject.layoutParagraph();

  canvas.drawParagraph(paragraph, textObject.position);
}
