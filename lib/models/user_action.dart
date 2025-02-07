import 'dart:ui' as ui;
import 'dart:ui';

import 'package:fpaint/widgets/brush_style_picker.dart';
export 'package:fpaint/widgets/brush_style_picker.dart';

enum Tools {
  pencil,
  brush,
  line,
  circle,
  rectangle,
  fill,
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
  strokeSize,
  brushStyle,
  colorOutline,
  colorFill,
  tolerance,
}

final Map<Tools, Set<ToolAttribute>> toolsSupportedAttributes = {
  Tools.pencil: {
    ToolAttribute.strokeSize,
    ToolAttribute.colorOutline,
  },
  Tools.brush: {
    ToolAttribute.strokeSize,
    ToolAttribute.brushStyle,
    ToolAttribute.colorOutline,
  },
  Tools.line: {
    ToolAttribute.colorOutline,
    ToolAttribute.strokeSize,
    ToolAttribute.brushStyle,
  },
  Tools.circle: {
    ToolAttribute.strokeSize,
    ToolAttribute.brushStyle,
    ToolAttribute.colorOutline,
    ToolAttribute.colorFill,
  },
  Tools.rectangle: {
    ToolAttribute.strokeSize,
    ToolAttribute.brushStyle,
    ToolAttribute.colorOutline,
    ToolAttribute.colorFill,
  },
  Tools.fill: {
    ToolAttribute.colorFill,
    ToolAttribute.tolerance,
  },
  Tools.eraser: {
    ToolAttribute.strokeSize,
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
