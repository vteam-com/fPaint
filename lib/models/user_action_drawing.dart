import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/widgets/brush_style_picker.dart';
import 'package:fpaint/widgets/svg_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
export 'package:fpaint/widgets/brush_style_picker.dart';

/// Represents a drawing action performed by the user.
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

  /// The type of action performed.
  final ActionType action;

  /// The list of positions where the action was performed.
  final List<Offset> positions;

  /// Optional brush used for the action.
  final MyBrush? brush;

  /// Optional fill color used for the action.
  final Color? fillColor;

  /// Optional gradient used for the action.
  final Gradient? gradient;

  /// Optional path used for the action.
  final ui.Path? path;

  /// Optional image used for the action.
  final ui.Image? image;

  /// Optional clip path used for the action.
  ui.Path? clipPath;

  @override
  String toString() {
    return '$action';
  }
}

/// Enum representing the different types of drawing actions.
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

  /// Checks if the action type supports the given attribute.
  bool isSupported(final ActionOptions attribute) {
    return toolsSupportedAttributes[this]?.contains(attribute) ?? false;
  }

  @override
  String toString() {
    return name;
  }
}

/// Returns an icon widget for the given action type.
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

/// Returns an icon widget with the given icon data and color.
Icon iconAndColor(final IconData tool, [final bool isSelected = false]) {
  final Color? color = isSelected ? Colors.blue : null;
  return Icon(tool, color: color);
}

/// Enum representing the different options for drawing actions.
enum ActionOptions {
  brushSize,
  brushStyle,
  brushColor,
  colorFill,
  tolerance,
  topColors,
  selectorOptions,
}

/// Map of action types to the set of action options they support.
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
