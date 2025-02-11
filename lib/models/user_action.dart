import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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
  image,
  cut,
  selector;

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
  topColors,
}

final Map<Tools, Set<ToolAttribute>> toolsSupportedAttributes = {
  Tools.pencil: {
    ToolAttribute.strokeSize,
    ToolAttribute.colorOutline,
    ToolAttribute.topColors,
  },
  Tools.brush: {
    ToolAttribute.strokeSize,
    ToolAttribute.brushStyle,
    ToolAttribute.colorOutline,
    ToolAttribute.topColors,
  },
  Tools.line: {
    ToolAttribute.colorOutline,
    ToolAttribute.strokeSize,
    ToolAttribute.brushStyle,
    ToolAttribute.topColors,
  },
  Tools.circle: {
    ToolAttribute.strokeSize,
    ToolAttribute.brushStyle,
    ToolAttribute.colorOutline,
    ToolAttribute.colorFill,
    ToolAttribute.topColors,
  },
  Tools.rectangle: {
    ToolAttribute.strokeSize,
    ToolAttribute.brushStyle,
    ToolAttribute.colorOutline,
    ToolAttribute.colorFill,
    ToolAttribute.topColors,
  },
  Tools.fill: {
    ToolAttribute.colorFill,
    ToolAttribute.tolerance,
    ToolAttribute.topColors,
  },
  Tools.eraser: {
    ToolAttribute.strokeSize,
  },
  Tools.selector: {
    // nothing to support yet
  },
};

class UserAction {
  UserAction({
    required this.tool,
    required this.positions,
    // optionals
    this.brush,
    this.fillColor,
    this.image,
  });

  final Tools tool;
  final List<Offset> positions;

  // optional used  based on the action type
  final MyBrush? brush;
  final Color? fillColor;
  final ui.Image? image;

  @override
  String toString() {
    return '$tool';
  }
}
