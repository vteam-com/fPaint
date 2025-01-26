import 'dart:ui' as ui;
import 'dart:ui';

import 'package:fpaint/widgets/brush_style_picker.dart';
export 'package:fpaint/widgets/brush_style_picker.dart';

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
    required this.brushColor,
    required this.fillColor,
    required this.brushSize,
    this.brushStyle = BrushStyle.solid,
    this.image,
  });
  final Tools type;
  final Offset start;
  Offset end;
  final double brushSize;
  final BrushStyle brushStyle;
  final Color brushColor;
  final Color fillColor;
  final ui.Image? image;
}
