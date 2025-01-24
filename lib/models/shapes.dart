import 'dart:ui';

import 'package:fpaint/brushes/brushes.dart';
export 'package:fpaint/brushes/brushes.dart';

enum ShapeType {
  pencil,
  line,
  circle,
  rectangle,
  eraser;

  bool isSupported(ShapeAttribute attribute) {
    return toolsSupportedAttributes[this]?.contains(attribute) ?? false;
  }
}

enum ShapeAttribute {
  stroke,
  lineWeight,
  brush,
  fill,
}

const Map<ShapeType, Set<ShapeAttribute>> toolsSupportedAttributes = {
  ShapeType.pencil: {
    ShapeAttribute.stroke,
    ShapeAttribute.lineWeight,
    ShapeAttribute.brush,
  },
  ShapeType.line: {
    ShapeAttribute.stroke,
    ShapeAttribute.lineWeight,
    ShapeAttribute.brush,
  },
  ShapeType.circle: {
    ShapeAttribute.stroke,
    ShapeAttribute.fill,
    ShapeAttribute.lineWeight,
    ShapeAttribute.brush,
  },
  ShapeType.rectangle: {
    ShapeAttribute.stroke,
    ShapeAttribute.fill,
    ShapeAttribute.lineWeight,
    ShapeAttribute.brush,
  },
  ShapeType.eraser: {ShapeAttribute.lineWeight},
};

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
