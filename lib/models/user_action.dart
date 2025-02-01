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

  @override
  String toString() {
    return name;
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
    required this.tool,
    required this.positions,
    required this.brushColor,
    required this.fillColor,
    required this.brushSize,
    this.brushStyle = BrushStyle.solid,
    this.image,
  });
  final Tools tool;
  final List<Offset> positions;
  final double brushSize;
  final BrushStyle brushStyle;
  final Color brushColor;
  final Color fillColor;
  final ui.Image? image;
  @override
  String toString() {
    return '$tool';
  }
}
