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
                userAction.start
                    .translate(_appModel.offset.dx, _appModel.offset.dy),
                userAction.end
                    .translate(_appModel.offset.dx, _appModel.offset.dy),
                paint,
              );
              break;

            // Line
            case Tools.line:
              paint.style = PaintingStyle.stroke;
              paint.color = userAction.colorOutline;

              if (userAction.brushStyle == BrushStyle.dash) {
                final path = Path();

                final Offset s = userAction.start
                    .translate(_appModel.offset.dx, _appModel.offset.dy);
                final Offset e = userAction.end
                    .translate(_appModel.offset.dx, _appModel.offset.dy);

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
                  userAction.start
                      .translate(_appModel.offset.dx, _appModel.offset.dy),
                  userAction.end
                      .translate(_appModel.offset.dx, _appModel.offset.dy),
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
              ).translate(_appModel.offset.dx, _appModel.offset.dy);

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
                    _appModel.offset.dx,
                    _appModel.offset.dy,
                  ),
                  userAction.end.translate(
                    _appModel.offset.dx,
                    _appModel.offset.dy,
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
                    _appModel.offset.dx,
                    _appModel.offset.dy,
                  ),
                  userAction.end.translate(
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
              paint.strokeWidth = userAction.brushSize;
              paint.style = PaintingStyle.stroke;
              canvas.drawLine(
                userAction.start
                    .translate(_appModel.offset.dx, _appModel.offset.dy),
                userAction.end
                    .translate(_appModel.offset.dx, _appModel.offset.dy),
                paint,
              );
              break;

            case Tools.image:
              if (userAction.image != null) {
                final Offset offset = userAction.start.translate(
                  _appModel.offset.dx,
                  _appModel.offset.dy,
                );

                canvas.drawImage(
                  userAction.image!,
                  offset,
                  Paint(),
                );
              }
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
