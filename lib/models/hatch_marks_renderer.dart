import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/hatch_marks.dart';

/// Draws tapered **hatch marks** along [path]: one mark every
/// [HatchMarks.spacing] pixels, heading [HatchMarks.angleDegrees] from the local
/// stroke direction, with its thick end ([baseWidth], the brush size) on the
/// path and its tip [HatchMarks.length] pixels away.
///
/// Each mark is one filled polygon around a quadratic-bezier spine (bent by
/// the curve setting) whose half-width shrinks with the taper, filled with a
/// base-to-tip gradient from [color] to a faded copy, so a fully tapered mark
/// thins to a point *and* fades out — the pencil / comic feathering look.
/// Cost is one `drawPath` per mark and stays bounded to the stroke.
void drawPathHatchMarks(
  Canvas canvas,
  Path path,
  Color color,
  double baseWidth,
  HatchMarks marks,
) {
  final double spacing = marks.spacing.toDouble();
  for (final ui.PathMetric metric in path.computeMetrics()) {
    double distance = AppMath.zero.toDouble();
    while (distance <= metric.length) {
      final ui.Tangent? tangent = metric.getTangentForOffset(distance);
      if (tangent != null) {
        drawHatchMark(canvas, tangent.position, tangent.angle + marks.angleRadians, color, baseWidth, marks);
      }
      distance += spacing;
      if (metric.length == AppMath.zero) {
        break;
      }
    }
  }
}

/// Draws a single mark whose base is at [base], heading [heading] radians
/// (screen convention: y grows downward, so the angle is applied as
/// `(cos, -sin)` to match [ui.Tangent.angle]).
void drawHatchMark(
  Canvas canvas,
  Offset base,
  double heading,
  Color color,
  double baseWidth,
  HatchMarks marks,
) {
  final double length = marks.length.toDouble();
  final Offset direction = Offset(math.cos(heading), -math.sin(heading));
  final Offset normal = Offset(-direction.dy, direction.dx);
  final Offset tip = base + direction * length;
  final Offset control =
      base + direction * (length * AppVisual.half) + normal * (marks.curve * length * AppHatchMarks.curveControlFactor);

  final int samples = AppHatchMarks.outlineSamples;
  final List<Offset> left = <Offset>[];
  final List<Offset> right = <Offset>[];
  for (int i = AppMath.zero; i <= samples; i++) {
    final double t = i / samples;
    final Offset point = _quadraticPoint(base, control, tip, t);
    final Offset spineTangent = _quadraticTangent(base, control, tip, t);
    final double tangentLength = spineTangent.distance;
    final Offset spineNormal = tangentLength > AppMath.zero
        ? Offset(-spineTangent.dy, spineTangent.dx) / tangentLength
        : normal;
    final double halfWidth = baseWidth * AppVisual.half * (AppVisual.full - marks.taper * t);
    left.add(point + spineNormal * halfWidth);
    right.add(point - spineNormal * halfWidth);
  }

  final Path outline = Path()..moveTo(left.first.dx, left.first.dy);
  for (final Offset point in left.skip(AppMath.one)) {
    outline.lineTo(point.dx, point.dy);
  }
  for (final Offset point in right.reversed) {
    outline.lineTo(point.dx, point.dy);
  }
  outline.close();

  final Color tipColor = color.withValues(alpha: color.a * (AppVisual.full - marks.taper));
  final Paint paint = Paint()
    ..style = PaintingStyle.fill
    ..shader = ui.Gradient.linear(base, tip, <Color>[color, tipColor]);
  canvas.drawPath(outline, paint);
}

/// The distance a mark can paint from the stroke path: its full length plus
/// the base half-width (and curve overshoot is within that envelope).
double hatchMarksOutset(double baseWidth, HatchMarks marks) => marks.length + baseWidth * AppVisual.half;

Offset _quadraticPoint(Offset p0, Offset p1, Offset p2, double t) {
  final double u = AppVisual.full - t;
  return p0 * (u * u) + p1 * (AppMath.pair * u * t) + p2 * (t * t);
}

Offset _quadraticTangent(Offset p0, Offset p1, Offset p2, double t) {
  final double u = AppVisual.full - t;
  return (p1 - p0) * (AppMath.pair * u) + (p2 - p1) * (AppMath.pair * t);
}
