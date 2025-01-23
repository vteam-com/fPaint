import 'dart:ui';

enum ShapeType {
  pencil,
  line,
  circle,
  rectangle,
}

class Shape {
  Shape({
    required this.start,
    required this.end,
    required this.type,
    required this.colorStroke,
    required this.colorFill,
  });
  final Offset start;
  Offset end;
  final ShapeType type;
  final Color colorStroke;
  final Color colorFill;
}
