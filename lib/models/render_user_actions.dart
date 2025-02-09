import 'dart:ui';

import 'package:fpaint/models/user_action.dart';

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
