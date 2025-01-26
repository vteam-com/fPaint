// Imports
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';

// Exports
export 'package:fpaint/models/user_action.dart';

class Layer {
  Layer({required this.name});
  String name;
  List<UserAction> actionStack = [];
  List<UserAction> redoStack = [];
  bool isVisible = true;
  double opacity = 1;

  void addImage(ui.Image imageToAdd, ui.Offset offset) {
    actionStack.add(
      UserAction(
        tool: Tools.image,
        positionStart: offset,
        positionEnd: Offset(
          offset.dx + imageToAdd.width.toDouble(),
          offset.dy + imageToAdd.height.toDouble(),
        ),
        brushColor: Colors.transparent,
        fillColor: Colors.transparent,
        brushSize: 0,
        image: imageToAdd,
      ),
    );
  }

  Future<ui.Image> toImage(Size size) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = Canvas(recorder);

    canvas.saveLayer(null, Paint());
    renderLayer(this, canvas);

    final ui.Picture picture = recorder.endRecording();
    return await picture.toImage(size.width.toInt(), size.height.toInt());
  }
}

void renderLayer(
  final Layer layer,
  final Canvas canvas,
) {
  for (final UserAction userAction in layer.actionStack) {
    final Paint paint = Paint();
    paint.color = userAction.fillColor;
    paint.strokeCap = StrokeCap.round;
    paint.strokeWidth = userAction.brushSize;

    switch (userAction.tool) {
      // Draw
      case Tools.draw:
        renderLine(paint, userAction, canvas);
        break;

      // Line
      case Tools.line:
        renderLine(paint, userAction, canvas);
        break;

      // Circle
      case Tools.circle:
        final radius =
            (userAction.positionStart - userAction.positionEnd).distance / 2;
        final center = Offset(
          (userAction.positionStart.dx + userAction.positionEnd.dx) / 2,
          (userAction.positionStart.dy + userAction.positionEnd.dy) / 2,
        );

        // Fill
        canvas.drawCircle(center, radius, paint);

        // Border
        paint.style = PaintingStyle.stroke;
        paint.color = userAction.brushColor;

        canvas.drawCircle(center, radius, paint);
        break;

      // Rectangle
      case Tools.rectangle:

        // Fill
        canvas.drawRect(
          Rect.fromPoints(userAction.positionStart, userAction.positionEnd),
          paint,
        );

        // Border
        paint.style = PaintingStyle.stroke;
        paint.color = userAction.brushColor;
        canvas.drawRect(
          Rect.fromPoints(
            userAction.positionStart,
            userAction.positionEnd,
          ),
          paint,
        );
        break;
      case Tools.eraser:
        paint.color = Colors.white;
        // paint.blendMode = BlendMode.clear;
        paint.strokeWidth = userAction.brushSize;
        paint.style = PaintingStyle.stroke;
        canvas.drawLine(
          userAction.positionStart,
          userAction.positionEnd,
          paint,
        );
        break;

      case Tools.image:
        if (userAction.image != null) {
          canvas.drawImage(
            userAction.image!,
            userAction.positionStart,
            Paint(),
          );
        }
        break;
    }
  }
}

void renderLine(ui.Paint paint, UserAction userAction, ui.Canvas canvas) {
  paint.style = PaintingStyle.stroke;
  paint.color = userAction.brushColor;

  if (userAction.brushStyle == BrushStyle.dash) {
    final path = Path();

    path.moveTo(userAction.positionStart.dx, userAction.positionStart.dy);
    path.lineTo(userAction.positionEnd.dx, userAction.positionEnd.dy);

    final Path dashedPath = createDashedPath(
      path,
      dashWidth: userAction.brushSize * 3,
      dashGap: userAction.brushSize * 2,
    );
    canvas.drawPath(dashedPath, paint);
  } else {
    canvas.drawLine(
      userAction.positionStart,
      userAction.positionEnd,
      paint,
    );
  }
}

Path createDashedPath(
  Path source, {
  required double dashWidth,
  required double dashGap,
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
