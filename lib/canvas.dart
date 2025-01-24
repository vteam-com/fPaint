import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fpaint/widgets/transparent_background.dart';

import 'models/app_model.dart';

class MyCanvas extends StatelessWidget {
  const MyCanvas({super.key, required this.appModel});
  final AppModel appModel;

  @override
  Widget build(final BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: MyCanvasPainter(appModel),
    );
  }
}

class MyCanvasPainter extends CustomPainter {
  MyCanvasPainter(this._appModel);
  final AppModel _appModel;

  @override
  void paint(final Canvas canvas, final Size size) {
    // Calculate offset to center the drawing
    _appModel.offset = Offset(
      (size.width - _appModel.canvasSize.width) / 2,
      (size.height - _appModel.canvasSize.height) / 2,
    );

    /// Render the transparent grid
    drawTransaparentBackgroundOffsetAndSize(
      canvas,
      _appModel.offset,
      _appModel.canvasSize,
    );

    for (final PaintLayer layer in _appModel.layers.list.reversed) {
      if (layer.isVisible) {
        for (final UserAction shape in layer.shapes) {
          final Paint paint = Paint();
          paint.color = shape.colorFill;
          paint.strokeCap = StrokeCap.round;
          paint.strokeWidth = shape.brushSize;

          switch (shape.type) {
            // Draw
            case Tools.draw:
              paint.style = PaintingStyle.stroke;
              paint.color = shape.colorOutline;
              canvas.drawLine(
                shape.start.translate(_appModel.offset.dx, _appModel.offset.dy),
                shape.end.translate(_appModel.offset.dx, _appModel.offset.dy),
                paint,
              );
              break;

            // Line
            case Tools.line:
              paint.style = PaintingStyle.stroke;
              paint.color = shape.colorOutline;

              if (shape.brushStyle == BrushStyle.dash) {
                final path = Path();

                final Offset s = shape.start
                    .translate(_appModel.offset.dx, _appModel.offset.dy);
                final Offset e = shape.end
                    .translate(_appModel.offset.dx, _appModel.offset.dy);

                path.moveTo(s.dx, s.dy);
                path.lineTo(e.dx, e.dy);

                final Path dashedPath = createDashedPath(
                  path,
                  dashWidth: shape.brushSize * 3,
                  dashGap: shape.brushSize * 2,
                );
                canvas.drawPath(dashedPath, paint);
              } else {
                canvas.drawLine(
                  shape.start
                      .translate(_appModel.offset.dx, _appModel.offset.dy),
                  shape.end.translate(_appModel.offset.dx, _appModel.offset.dy),
                  paint,
                );
              }
              break;

            // Circle
            case Tools.circle:
              final radius = (shape.start - shape.end).distance / 2;
              final center = Offset(
                (shape.start.dx + shape.end.dx) / 2,
                (shape.start.dy + shape.end.dy) / 2,
              ).translate(_appModel.offset.dx, _appModel.offset.dy);

              // Fill
              canvas.drawCircle(center, radius, paint);

              // Border
              paint.style = PaintingStyle.stroke;
              paint.color = shape.colorOutline;

              canvas.drawCircle(center, radius, paint);
              break;

            // Rectangle
            case Tools.rectangle:

              // Fill
              canvas.drawRect(
                Rect.fromPoints(
                  shape.start.translate(
                    _appModel.offset.dx,
                    _appModel.offset.dy,
                  ),
                  shape.end.translate(
                    _appModel.offset.dx,
                    _appModel.offset.dy,
                  ),
                ),
                paint,
              );

              // Border
              paint.style = PaintingStyle.stroke;
              paint.color = shape.colorOutline;
              canvas.drawRect(
                Rect.fromPoints(
                  shape.start.translate(
                    _appModel.offset.dx,
                    _appModel.offset.dy,
                  ),
                  shape.end.translate(
                    _appModel.offset.dx,
                    _appModel.offset.dy,
                  ),
                ),
                paint,
              );
              break;

            case Tools.eraser:
              paint.color = Colors.white;
              // paint.blendMode = BlendMode.clear;
              paint.strokeWidth = shape.brushSize;
              paint.style = PaintingStyle.stroke;
              canvas.drawLine(
                shape.start.translate(_appModel.offset.dx, _appModel.offset.dy),
                shape.end.translate(_appModel.offset.dx, _appModel.offset.dy),
                paint,
              );
              break;
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(MyCanvasPainter oldDelegate) => true;

  Path createDashedPath(
    Path source, {
    required double dashWidth,
    required double dashGap,
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
}
