import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/widgets/brush_style_picker.dart';
export 'package:fpaint/widgets/brush_style_picker.dart';

class UserAction {
  UserAction({
    required this.action,
    required this.positions,
    // optionals
    this.brush,
    this.fillColor,
    this.path,
    this.image,
  });

  final ActionType action;
  final List<Offset> positions;

  // optional used  based on the action type
  final MyBrush? brush;
  final Color? fillColor;
  final ui.Path? path;
  final ui.Image? image;

  @override
  String toString() {
    return '$action';
  }
}

enum ActionType {
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

  bool isSupported(ActionOptions attribute) {
    return toolsSupportedAttributes[this]?.contains(attribute) ?? false;
  }

  @override
  String toString() {
    return name;
  }
}

enum ActionOptions {
  strokeSize,
  brushStyle,
  colorOutline,
  colorFill,
  tolerance,
  topColors,
}

final Map<ActionType, Set<ActionOptions>> toolsSupportedAttributes = {
  ActionType.pencil: {
    ActionOptions.strokeSize,
    ActionOptions.colorOutline,
    ActionOptions.topColors,
  },
  ActionType.brush: {
    ActionOptions.strokeSize,
    ActionOptions.brushStyle,
    ActionOptions.colorOutline,
    ActionOptions.topColors,
  },
  ActionType.line: {
    ActionOptions.colorOutline,
    ActionOptions.strokeSize,
    ActionOptions.brushStyle,
    ActionOptions.topColors,
  },
  ActionType.circle: {
    ActionOptions.strokeSize,
    ActionOptions.brushStyle,
    ActionOptions.colorOutline,
    ActionOptions.colorFill,
    ActionOptions.topColors,
  },
  ActionType.rectangle: {
    ActionOptions.strokeSize,
    ActionOptions.brushStyle,
    ActionOptions.colorOutline,
    ActionOptions.colorFill,
    ActionOptions.topColors,
  },
  ActionType.fill: {
    ActionOptions.colorFill,
    ActionOptions.tolerance,
    ActionOptions.topColors,
  },
  ActionType.eraser: {
    ActionOptions.strokeSize,
  },
  ActionType.cut: {
    // nothing to support yet
  },
  ActionType.selector: {
    // nothing to support yet
  },
};
