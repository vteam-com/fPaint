import 'package:flutter/material.dart';
import 'models/app_model.dart';

class MyCanvas extends StatelessWidget {
  const MyCanvas({super.key, required this.paintModel});
  final AppModel paintModel;

  @override
  Widget build(final BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: MyCanvasPainter(paintModel),
    );
  }
}

class MyCanvasPainter extends CustomPainter {
  MyCanvasPainter(this._paintModel);
  final AppModel _paintModel;

  @override
  void paint(final Canvas canvas, final Size size) {
    // Calculate offset to center the drawing
    _paintModel.offset = Offset(
      (size.width - _paintModel.canvasSize.width) / 2,
      (size.height - _paintModel.canvasSize.height) / 2,
    );

    // Draw white background
    final Paint backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(
      _paintModel.offset & _paintModel.canvasSize,
      backgroundPaint,
    );

    for (final PaintLayer layer in _paintModel.layers.list) {
      if (layer.isVisible) {
        for (final Shape shape in layer.shapes) {
          final Paint paint = Paint()
            ..color = shape.color
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 5.0;

          switch (shape.type) {
            case ShapeType.pencil:
              canvas.drawLine(
                shape.start
                    .translate(_paintModel.offset.dx, _paintModel.offset.dy),
                shape.end
                    .translate(_paintModel.offset.dx, _paintModel.offset.dy),
                paint,
              );
              break;
            case ShapeType.line:
              canvas.drawLine(
                shape.start
                    .translate(_paintModel.offset.dx, _paintModel.offset.dy),
                shape.end
                    .translate(_paintModel.offset.dx, _paintModel.offset.dy),
                paint,
              );
              break;
            case ShapeType.circle:
              final radius = (shape.start - shape.end).distance / 2;
              final center = Offset(
                (shape.start.dx + shape.end.dx) / 2,
                (shape.start.dy + shape.end.dy) / 2,
              ).translate(_paintModel.offset.dx, _paintModel.offset.dy);
              canvas.drawCircle(center, radius, paint);
              break;
            case ShapeType.rectangle:
              canvas.drawRect(
                Rect.fromPoints(
                  shape.start.translate(
                    _paintModel.offset.dx,
                    _paintModel.offset.dy,
                  ),
                  shape.end.translate(
                    _paintModel.offset.dx,
                    _paintModel.offset.dy,
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
