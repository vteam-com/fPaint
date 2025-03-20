import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/widgets/brush_style_picker.dart';
import 'package:fpaint/widgets/svg_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
export 'package:fpaint/widgets/brush_style_picker.dart';

class UserActionDrawing {
  UserActionDrawing({
    required this.action,
    required this.positions,
    // optionals
    this.brush,
    this.fillColor,
    this.gradient,
    this.path,
    this.image,
    this.clipPath,
  });

  final ActionType action;
  final List<Offset> positions;

  // optional used  based on the action type
  final MyBrush? brush;
  final Color? fillColor;
  final Gradient? gradient;
  final ui.Path? path;
  final ui.Image? image;
  ui.Path? clipPath;

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
  region,
  fill,
  eraser,
  image,
  cut,
  selector;

  bool isSupported(final ActionOptions attribute) {
    return toolsSupportedAttributes[this]?.contains(attribute) ?? false;
  }

  @override
  String toString() {
    return name;
  }
}

Widget iconFromaActionType(
  final ActionType type,
  final bool isSelected,
) {
  switch (type) {
    case ActionType.pencil:
      return iconAndColor(Icons.create, isSelected);
    case ActionType.brush:
      return iconAndColor(Icons.brush, isSelected);
    case ActionType.line:
      return iconAndColor(Icons.line_axis, isSelected);
    case ActionType.circle:
      return iconAndColor(Icons.circle_outlined, isSelected);
    case ActionType.rectangle:
      return iconAndColor(Icons.crop_square, isSelected);
    case ActionType.region:
      return iconAndColor(Icons.crop, isSelected);
    case ActionType.fill:
      return iconAndColor(Icons.format_color_fill, isSelected);
    case ActionType.eraser:
      return iconFromSvgAsset(
        'assets/icons/eraser.svg',
        isSelected ? Colors.blue : Colors.white,
      );
    case ActionType.image:
      return iconAndColor(Icons.image, isSelected);
    case ActionType.cut:
      return iconAndColor(Icons.crop_free, isSelected);
    case ActionType.selector:
      return iconAndColor(Symbols.select, isSelected);
  }
}

Icon iconAndColor(final IconData tool, [final bool isSelected = false]) {
  final Color? color = isSelected ? Colors.blue : null;
  return Icon(tool, color: color);
}

enum ActionOptions {
  brushSize,
  brushStyle,
  brushColor,
  colorFill,
  tolerance,
  topColors,
  selectorOptions,
}

final Map<ActionType, Set<ActionOptions>> toolsSupportedAttributes =
    <ActionType, Set<ActionOptions>>{
  ActionType.pencil: <ActionOptions>{
    ActionOptions.brushSize,
    ActionOptions.brushColor,
    ActionOptions.topColors,
  },
  ActionType.brush: <ActionOptions>{
    ActionOptions.brushSize,
    ActionOptions.brushStyle,
    ActionOptions.brushColor,
    ActionOptions.topColors,
  },
  ActionType.line: <ActionOptions>{
    ActionOptions.brushColor,
    ActionOptions.brushSize,
    ActionOptions.brushStyle,
    ActionOptions.topColors,
  },
  ActionType.circle: <ActionOptions>{
    ActionOptions.brushSize,
    ActionOptions.brushStyle,
    ActionOptions.brushColor,
    ActionOptions.colorFill,
    ActionOptions.topColors,
  },
  ActionType.rectangle: <ActionOptions>{
    ActionOptions.brushSize,
    ActionOptions.brushStyle,
    ActionOptions.brushColor,
    ActionOptions.colorFill,
    ActionOptions.topColors,
  },
  ActionType.fill: <ActionOptions>{
    ActionOptions.colorFill,
    ActionOptions.tolerance,
    ActionOptions.topColors,
  },
  ActionType.eraser: <ActionOptions>{
    ActionOptions.brushSize,
  },
  ActionType.cut: <ActionOptions>{
    // nothing to support yet
  },
  ActionType.selector: <ActionOptions>{
    ActionOptions.selectorOptions,
  },
};
