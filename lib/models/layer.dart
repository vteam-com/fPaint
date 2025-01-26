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
        positions: [
          offset,
          Offset(
            offset.dx + imageToAdd.width.toDouble(),
            offset.dy + imageToAdd.height.toDouble(),
          ),
        ],
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
        final path = Path();

        path.moveTo(
          userAction.positions.first.dx,
          userAction.positions.first.dy,
        );

        for (int i = 1; i < userAction.positions.length; i++) {
          path.lineTo(userAction.positions[i].dx, userAction.positions[i].dy);
        }
        paint.style = PaintingStyle.stroke;
        paint.color = userAction.brushColor;

        if (userAction.brushStyle == BrushStyle.dash) {
          double dashWidth = userAction.brushSize * 3;
          double dashGap = userAction.brushSize * 2;
          drawPath(path, canvas, paint, dashWidth, dashGap);
        } else {
          canvas.drawPath(path, paint);
        }
        break;

      // Line
      case Tools.line:
        renderLine(paint, userAction, canvas);
        break;

      // Circle
      case Tools.circle:
        final radius =
            (userAction.positions.first - userAction.positions.last).distance /
                2;
        final center = Offset(
          (userAction.positions.first.dx + userAction.positions.last.dx) / 2,
          (userAction.positions.first.dy + userAction.positions.last.dy) / 2,
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
        if (userAction.positions.length == 2) {
          // Fill
          canvas.drawRect(
            Rect.fromPoints(
              userAction.positions.first,
              userAction.positions.last,
            ),
            paint,
          );

          // Border
          paint.style = PaintingStyle.stroke;
          paint.color = userAction.brushColor;
          canvas.drawRect(
            Rect.fromPoints(
              userAction.positions.first,
              userAction.positions.last,
            ),
            paint,
          );
        }
        break;
      case Tools.eraser:
        paint.color = Colors.white;
        // paint.blendMode = BlendMode.clear;
        paint.strokeWidth = userAction.brushSize;
        paint.style = PaintingStyle.stroke;
        canvas.drawLine(
          userAction.positions.first,
          userAction.positions.last,
          paint,
        );
        break;

      case Tools.image:
        if (userAction.image != null) {
          canvas.drawImage(
            userAction.image!,
            userAction.positions.first,
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

    path.moveTo(userAction.positions.first.dx, userAction.positions.first.dy);
    path.lineTo(userAction.positions.last.dx, userAction.positions.last.dy);

    drawPath(
      path,
      canvas,
      paint,
      userAction.brushSize * 3,
      userAction.brushSize * 2,
    );
  } else {
    canvas.drawLine(
      userAction.positions.first,
      userAction.positions.last,
      paint,
    );
  }
}

void drawPath(Path path, ui.Canvas canvas, ui.Paint paint, dashWidth, dashGap) {
  final Path dashedPath = createDashedPath(
    path,
    dashWidth: dashWidth,
    dashGap: dashGap,
  );
  canvas.drawPath(dashedPath, paint);
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
