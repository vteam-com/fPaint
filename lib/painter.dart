import 'package:flutter/material.dart';
import 'models/paint_model.dart';

class Painter extends StatelessWidget {
  final PaintModel paintModel;

  const Painter({super.key, required this.paintModel});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: CanvasPainter(paintModel),
    );
  }
}

class CanvasPainter extends CustomPainter {
  final PaintModel _paintModel;

  CanvasPainter(this._paintModel);

  @override
  void paint(Canvas canvas, Size size) {
    for (final PaintLayer layer in _paintModel.layers) {
      if (layer.isVisible) {
        for (final Shape shape in layer.shapes) {
          final Paint paint = Paint()
            ..color = shape.color
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 5.0;

          switch (shape.type) {
            case ShapeType.pencil:
              canvas.drawLine(shape.start, shape.end, paint);
              break;
            case ShapeType.line:
              canvas.drawLine(shape.start, shape.end, paint);
              break;
            case ShapeType.circle:
              final radius = (shape.start - shape.end).distance / 2;
              final center = Offset((shape.start.dx + shape.end.dx) / 2,
                  (shape.start.dy + shape.end.dy) / 2);
              canvas.drawCircle(center, radius, paint);
              break;
            case ShapeType.rectangle:
              canvas.drawRect(Rect.fromPoints(shape.start, shape.end), paint);
              break;
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) => true;
}
