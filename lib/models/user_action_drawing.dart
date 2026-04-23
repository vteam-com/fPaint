import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/brush_style.dart';
import 'package:fpaint/models/text_object.dart';
export 'package:fpaint/models/brush_style.dart';

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
    this.textObject,
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
  ui.Path? path;

  /// Optional image used for the action.
  final ui.Image? image;

  /// Optional clip path used for the action.
  ui.Path? clipPath;

  /// Optional text for the action.
  final TextObject? textObject;

  @override
  String toString() {
    return '$action';
  }
}

/// Enum representing the different types of drawing actions.
enum ActionType {
  pencil(AppIcon.create),
  brush(AppIcon.brush),
  line(AppIcon.lineAxis),
  circle(AppIcon.circle),
  rectangle(AppIcon.cropSquare),
  region(AppIcon.canvasCrop),
  fill(AppIcon.formatColorFill),
  eraser(AppIcon.eraser),
  image(AppIcon.image),
  cut(AppIcon.cropFree),
  text(AppIcon.fontDownload),
  selector(AppIcon.selectorReplace),
  ;

  const ActionType(this.icon);

  /// The [AppIcon] representing this action type.
  final AppIcon icon;

  /// Checks if the action type supports the given attribute.
  bool isSupported(final ActionOptions attribute) {
    return toolsSupportedAttributes[this]?.contains(attribute) ?? false;
  }

  @override
  String toString() {
    return name;
  }
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
final Map<ActionType, Set<ActionOptions>> toolsSupportedAttributes = <ActionType, Set<ActionOptions>>{
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
  ActionType.text: <ActionOptions>{
    ActionOptions.brushColor,
    ActionOptions.brushSize,
    ActionOptions.topColors,
  },
};
