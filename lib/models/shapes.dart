import 'dart:ui';

enum ShapeType {
  pencil,
  line,
  circle,
  rectangle,
}

class Shape {
  Shape(
    this.start,
    this.end,
    this.type,
    this.color,
  );
  Offset start;
  Offset end;
  final ShapeType type;
  final Color color;
}
