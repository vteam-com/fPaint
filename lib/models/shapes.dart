import 'dart:ui';

import 'package:fpaint/brushes/brushes.dart';
export 'package:fpaint/brushes/brushes.dart';

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
    required this.lineWeight,
    this.brush = BrushStyle.solid,
  });
  final Offset start;
  Offset end;
  final ShapeType type;
  final Color colorStroke;
  final Color colorFill;
  final double lineWeight;
  final BrushStyle brush;
}
