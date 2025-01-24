import 'package:flutter/material.dart';
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
    final double cellSize = _appModel.canvasSize.width /
        ((_appModel.canvasSize.width / 10.0).floor());
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        _appModel.offset.dx,
        _appModel.offset.dy,
        _appModel.canvasSize.width,
        _appModel.canvasSize.height,
      ),
    );
    for (double x = 0; x < _appModel.canvasSize.width; x += cellSize) {
      for (double y = 0; y < _appModel.canvasSize.height; y += cellSize) {
        if ((x ~/ cellSize + y ~/ cellSize) % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(
              x + _appModel.offset.dx,
              y + _appModel.offset.dy,
              cellSize,
              cellSize,
            ),
            Paint()..color = Colors.grey.shade400,
          );
        }
      }
    }
    canvas.restore();

    for (final PaintLayer layer in _appModel.layers.list.reversed) {
      if (layer.isVisible) {
        for (final Shape shape in layer.shapes) {
          final Paint paint = Paint();
          paint.color = shape.colorFill;
          paint.strokeCap = StrokeCap.round;
          paint.strokeWidth = shape.lineWeight;

          switch (shape.type) {
            // Draw
            case ShapeType.pencil:
              paint.style = PaintingStyle.stroke;
              paint.color = shape.colorStroke;
              canvas.drawLine(
                shape.start.translate(_appModel.offset.dx, _appModel.offset.dy),
                shape.end.translate(_appModel.offset.dx, _appModel.offset.dy),
                paint,
              );
              break;

            // Line
            case ShapeType.line:
              paint.style = PaintingStyle.stroke;
              paint.color = shape.colorStroke;
              canvas.drawLine(
                shape.start.translate(_appModel.offset.dx, _appModel.offset.dy),
                shape.end.translate(_appModel.offset.dx, _appModel.offset.dy),
                paint,
              );
              break;

            // Circle
            case ShapeType.circle:
              final radius = (shape.start - shape.end).distance / 2;
              final center = Offset(
                (shape.start.dx + shape.end.dx) / 2,
                (shape.start.dy + shape.end.dy) / 2,
              ).translate(_appModel.offset.dx, _appModel.offset.dy);

              // Fill
              canvas.drawCircle(center, radius, paint);

              // Border
              paint.style = PaintingStyle.stroke;
              paint.color = shape.colorStroke;

              canvas.drawCircle(center, radius, paint);
              break;

            // Rectangle
            case ShapeType.rectangle:

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
              paint.color = shape.colorStroke;
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
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(MyCanvasPainter oldDelegate) => true;
}
