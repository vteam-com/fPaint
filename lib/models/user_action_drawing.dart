import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/brush_style.dart';
import 'package:fpaint/models/halftone_fill.dart';
import 'package:fpaint/models/hatch_pattern.dart';
import 'package:fpaint/models/text_object.dart';
export 'package:fpaint/models/brush_style.dart';

part 'cut_action.dart';
part 'image_action.dart';
part 'non_rendering_action.dart';
part 'region_action.dart';
part 'stroke_action.dart';
part 'text_action.dart';

/// A single committed drawing operation on a layer.
///
/// Sealed so every consumer switches exhaustively over the concrete variants
/// instead of force-unwrapping optional fields that only some actions carry.
/// Each subtype declares exactly the data its rendering needs, which is what
/// makes the payload accessors below non-nullable (Liskov substitution).
sealed class UserActionDrawing {
  UserActionDrawing({required this.action, required this.positions, this.clipPath});

  /// The type of action performed.
  final ActionType action;

  /// The list of positions where the action was performed.
  ///
  /// Mutable: freehand strokes append points while the gesture is in flight.
  final List<ui.Offset> positions;

  /// Optional clip path restricting where the action paints.
  ui.Path? clipPath;

  /// Whether this action erases the whole layer, making every earlier action
  /// invisible. Marks a collapse point for the action stack.
  bool get erasesEntireLayer => false;

  /// The brush this action paints with, or null when it does not use one.
  MyBrush? get brush => null;

  /// The solid color this action fills with, or null when it has none.
  Color? get fillColor => null;

  /// The gradient this action fills with, or null when it has none.
  Gradient? get gradient => null;

  /// The halftone treatment applied to a region fill, or null when unused.
  HalftoneFill? get halftoneFill => null;

  /// The hatch pattern a region fill is drawn with, or null for a flat fill.
  HatchPattern? get hatchPattern => null;

  /// The geometry this action fills or erases, or null when it has none.
  ui.Path? get path => null;

  /// The image this action stamps, or null when it has none.
  ui.Image? get image => null;

  /// The text this action draws, or null when it has none.
  TextObject? get textObject => null;

  /// Returns a copy of this action with the supplied payload replaced,
  /// preserving the concrete variant.
  ///
  /// Used by whole-layer geometric transforms (rotate/flip), which rebuild each
  /// action's geometry without knowing its kind. Arguments that do not apply to
  /// a given variant are ignored by that variant.
  UserActionDrawing copyWith({
    List<ui.Offset>? positions,
    ui.Path? path,
    ui.Image? image,
    ui.Path? clipPath,
    TextObject? textObject,
  });

  @override
  String toString() {
    return '$action';
  }
}

/// Enum representing the different types of drawing actions.
enum ActionType {
  pencil(AppIcon.create),
  brush(AppIcon.brush),
  smudge(AppIcon.smudge),
  blurBrush(AppIcon.waterDrop),
  line(AppIcon.lineAxis),
  circle(AppIcon.circle),
  rectangle(AppIcon.cropSquare),
  region(AppIcon.canvasCrop),
  fill(AppIcon.formatColorFill),
  eraser(AppIcon.eraser),
  image(AppIcon.image),
  cut(AppIcon.cropFree),
  text(AppIcon.fontDownload),
  selector(AppIcon.selector),
  ;

  const ActionType(this.icon);

  /// The [AppIcon] representing this action type.
  final AppIcon icon;

  /// Checks if the action type supports the given attribute.
  bool isSupported(ActionOptions attribute) {
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
  brushIntensity,
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
  ActionType.smudge: <ActionOptions>{
    ActionOptions.brushSize,
    ActionOptions.brushIntensity,
  },
  ActionType.blurBrush: <ActionOptions>{
    ActionOptions.brushSize,
    ActionOptions.brushIntensity,
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
