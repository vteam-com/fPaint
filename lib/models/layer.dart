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
  bool isSelected = false;
  bool isVisible = true;
  double opacity = 1;

  void addImage(ui.Image imageToAdd, [ui.Offset offset = Offset.zero]) {
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
    renderLayer(canvas);

    final ui.Picture picture = recorder.endRecording();
    return await picture.toImage(size.width.toInt(), size.height.toInt());
  }

  void renderLayer(final Canvas canvas) {
    for (final UserAction userAction in actionStack) {
      final Paint paint = Paint()
        ..color = userAction.fillColor
        ..strokeCap = StrokeCap.round
        ..strokeWidth = userAction.brushSize;

      switch (userAction.tool) {
        case Tools.draw:
          renderPath(canvas, paint, userAction);
          break;
        case Tools.line:
          renderLine(canvas, paint, userAction);
          break;
        case Tools.circle:
          renderCircle(canvas, paint, userAction);
          break;
        case Tools.rectangle:
          renderRectangle(canvas, paint, userAction);
          break;
        case Tools.eraser:
          renderEraser(canvas, paint, userAction);
          break;
        case Tools.image:
          renderImage(canvas, userAction);
          break;
      }
    }
  }

  void renderPath(Canvas canvas, Paint paint, UserAction userAction) {
    final path = Path()
      ..moveTo(userAction.positions.first.dx, userAction.positions.first.dy);
    for (final ui.Offset position in userAction.positions) {
      path.lineTo(position.dx, position.dy);
    }
    paint.style = PaintingStyle.stroke;
    paint.color = userAction.brushColor;
    applyBrushStyle(canvas, paint, path, userAction);
  }

  void renderLine(Canvas canvas, Paint paint, UserAction userAction) {
    final path = Path()
      ..moveTo(userAction.positions.first.dx, userAction.positions.first.dy)
      ..lineTo(userAction.positions.last.dx, userAction.positions.last.dy);
    paint.style = PaintingStyle.stroke;
    paint.color = userAction.brushColor;
    applyBrushStyle(canvas, paint, path, userAction);
  }

  void renderCircle(Canvas canvas, Paint paint, UserAction userAction) {
    final radius =
        (userAction.positions.first - userAction.positions.last).distance / 2;
    final center = Offset(
      (userAction.positions.first.dx + userAction.positions.last.dx) / 2,
      (userAction.positions.first.dy + userAction.positions.last.dy) / 2,
    );
    canvas.drawCircle(center, radius, paint);
    paint.style = PaintingStyle.stroke;
    paint.color = userAction.brushColor;
    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    applyBrushStyle(canvas, paint, path, userAction);
  }

  void renderRectangle(Canvas canvas, Paint paint, UserAction userAction) {
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

  void renderEraser(Canvas canvas, Paint paint, UserAction userAction) {
    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    canvas.drawLine(
      userAction.positions.first,
      userAction.positions.last,
      paint,
    );
  }

  void renderImage(Canvas canvas, UserAction userAction) {
    if (userAction.image != null) {
      canvas.drawImage(userAction.image!, userAction.positions.first, Paint());
    }
  }

  void applyBrushStyle(
    Canvas canvas,
    Paint paint,
    Path path,
    UserAction userAction,
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
    Path path,
    ui.Canvas canvas,
    ui.Paint paint,
    double dashWidth,
    double dashGap,
  ) {
    final Path dashedPath =
        createDashedPath(path, dashWidth: dashWidth, dashGap: dashGap);
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
}
