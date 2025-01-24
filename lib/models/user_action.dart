import 'dart:ui' as ui;
import 'dart:ui';

import 'package:fpaint/brushes/brushes.dart';
export 'package:fpaint/brushes/brushes.dart';

enum Tools {
  draw,
  line,
  circle,
  rectangle,
  eraser,
  image;

  bool isSupported(ToolAttribute attribute) {
    return toolsSupportedAttributes[this]?.contains(attribute) ?? false;
  }
}

enum ToolAttribute {
  brushSize,
  brushStyle,
  colorOutline,
  colorFill,
}

const Map<Tools, Set<ToolAttribute>> toolsSupportedAttributes = {
  Tools.draw: {
    ToolAttribute.brushSize,
    ToolAttribute.brushStyle,
    ToolAttribute.colorOutline,
  },
  Tools.line: {
    ToolAttribute.colorOutline,
    ToolAttribute.brushSize,
    ToolAttribute.brushStyle,
  },
  Tools.circle: {
    ToolAttribute.brushSize,
    ToolAttribute.brushStyle,
    ToolAttribute.colorOutline,
    ToolAttribute.colorFill,
  },
  Tools.rectangle: {
    ToolAttribute.brushSize,
    ToolAttribute.brushStyle,
    ToolAttribute.colorOutline,
    ToolAttribute.colorFill,
  },
  Tools.eraser: {
    ToolAttribute.brushSize,
  },
};

class UserAction {
  UserAction({
    required this.type,
    required this.start,
    required this.end,
    required this.colorOutline,
    required this.colorFill,
    required this.brushSize,
    this.brushStyle = BrushStyle.solid,
    this.image,
  });
  final Tools type;
  final Offset start;
  Offset end;
  final double brushSize;
  final BrushStyle brushStyle;
  final Color colorOutline;
  final Color colorFill;
  final ui.Image? image;
}
