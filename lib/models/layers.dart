// Imports
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/list_helper.dart';
import 'package:fpaint/models/app_model.dart';

// Exports
export 'package:fpaint/models/user_action.dart';

class PaintLayer {
  PaintLayer({required this.name});
  String name;
  List<UserAction> actionStack = [];
  List<UserAction> redoStack = [];
  bool isVisible = true;
  double opacity = 1;

  void addImage(ui.Image imageToAdd, ui.Offset offset) {
    actionStack.add(
      UserAction(
        type: Tools.image,
        start: offset,
        end: Offset(
          offset.dx + imageToAdd.width.toDouble(),
          offset.dy + imageToAdd.height.toDouble(),
        ),
        colorOutline: Colors.transparent,
        colorFill: Colors.transparent,
        brushSize: 0,
        image: imageToAdd,
      ),
    );
  }

  Future<ui.Image> toImage(Offset offset, Size size) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = Canvas(recorder);

    canvas.saveLayer(null, Paint());
    renderLayer(this, canvas, offset);

    final ui.Picture picture = recorder.endRecording();
    return await picture.toImage(size.width.toInt(), size.height.toInt());
  }
}

void renderLayer(PaintLayer layer, Canvas canvas, Offset offset) {
  for (final UserAction userAction in layer.actionStack) {
    final Paint paint = Paint();
    paint.color = userAction.colorFill;
    paint.strokeCap = StrokeCap.round;
    paint.strokeWidth = userAction.brushSize;

    switch (userAction.type) {
      // Draw
      case Tools.draw:
        paint.style = PaintingStyle.stroke;
        paint.color = userAction.colorOutline;
        canvas.drawLine(
          userAction.start.translate(offset.dx, offset.dy),
          userAction.end.translate(offset.dx, offset.dy),
          paint,
        );
        break;

      // Line
      case Tools.line:
        paint.style = PaintingStyle.stroke;
        paint.color = userAction.colorOutline;

        if (userAction.brushStyle == BrushStyle.dash) {
          final path = Path();

          final Offset s = userAction.start.translate(offset.dx, offset.dy);
          final Offset e = userAction.end.translate(offset.dx, offset.dy);

          path.moveTo(s.dx, s.dy);
          path.lineTo(e.dx, e.dy);

          final Path dashedPath = createDashedPath(
            path,
            dashWidth: userAction.brushSize * 3,
            dashGap: userAction.brushSize * 2,
          );
          canvas.drawPath(dashedPath, paint);
        } else {
          canvas.drawLine(
            userAction.start.translate(offset.dx, offset.dy),
            userAction.end.translate(offset.dx, offset.dy),
            paint,
          );
        }
        break;

      // Circle
      case Tools.circle:
        final radius = (userAction.start - userAction.end).distance / 2;
        final center = Offset(
          (userAction.start.dx + userAction.end.dx) / 2,
          (userAction.start.dy + userAction.end.dy) / 2,
        ).translate(offset.dx, offset.dy);

        // Fill
        canvas.drawCircle(center, radius, paint);

        // Border
        paint.style = PaintingStyle.stroke;
        paint.color = userAction.colorOutline;

        canvas.drawCircle(center, radius, paint);
        break;

      // Rectangle
      case Tools.rectangle:

        // Fill
        canvas.drawRect(
          Rect.fromPoints(
            userAction.start.translate(
              offset.dx,
              offset.dy,
            ),
            userAction.end.translate(
              offset.dx,
              offset.dy,
            ),
          ),
          paint,
        );

        // Border
        paint.style = PaintingStyle.stroke;
        paint.color = userAction.colorOutline;
        canvas.drawRect(
          Rect.fromPoints(
            userAction.start.translate(
              offset.dx,
              offset.dy,
            ),
            userAction.end.translate(
              offset.dx,
              offset.dy,
            ),
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
          userAction.start.translate(offset.dx, offset.dy),
          userAction.end.translate(offset.dx, offset.dy),
          paint,
        );
        break;

      case Tools.image:
        if (userAction.image != null) {
          canvas.drawImage(
            userAction.image!,
            userAction.start.translate(
              offset.dx,
              offset.dy,
            ),
            Paint(),
          );
        }
        break;
    }
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

class Layers {
  Layers(final Size size) {
    final PaintLayer firstLayer = PaintLayer(name: 'Background');

    firstLayer.actionStack.add(
      UserAction(
        start: Offset(0, 0),
        end: Offset(size.width, size.height),
        type: Tools.rectangle,
        colorFill: Colors.white,
        colorOutline: Colors.white,
        brushSize: 0,
      ),
    );

    _list.add(firstLayer);
  }
  final List<PaintLayer> _list = [];
  void clear() => _list.clear();
  int get length => _list.length;

  bool isIndexInRange(final int indexLayer) =>
      indexLayer >= 0 && indexLayer < _list.length;

  int getLayerIndex(final PaintLayer layer) {
    return _list.indexOf(layer);
  }

  PaintLayer get(final int index) {
    return _list[index];
  }

  PaintLayer? getByName(final String name) {
    return _list.findFirstMatch((layer) => layer.name == name);
  }

  void add(final PaintLayer layerToAdd) {
    _list.insert(0, layerToAdd);
  }

  void insert(final index, final PaintLayer layerToInsert) {
    if (isIndexInRange(index)) {
      _list.insert(index, layerToInsert);
    } else {
      _list.add(layerToInsert);
    }
  }

  void remove(final int index) {
    if (isIndexInRange(index)) {
      _list.removeAt(index);
    }
  }

  List<PaintLayer> get list => _list;
}
