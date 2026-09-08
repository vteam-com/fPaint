import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/brush_style.dart';
import 'package:fpaint/models/halftone_fill.dart';
import 'package:fpaint/models/text_object.dart';
export 'package:fpaint/models/brush_style.dart';

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

/// A freehand or two-point stroke painted with a brush.
///
/// Covers pencil, brush, eraser, line, circle and rectangle: every action whose
/// rendering is driven by [positions] plus a [brush].
class StrokeAction extends UserActionDrawing {
  StrokeAction({
    required super.action,
    required super.positions,
    required this.brush,
    this.fillColor,
    super.clipPath,
  });

  @override
  final MyBrush brush;

  @override
  final Color? fillColor;

  @override
  StrokeAction copyWith({
    List<ui.Offset>? positions,
    ui.Path? path,
    ui.Image? image,
    ui.Path? clipPath,
    TextObject? textObject,
  }) {
    return StrokeAction(
      action: action,
      positions: positions ?? this.positions,
      brush: brush,
      fillColor: fillColor,
      clipPath: clipPath ?? this.clipPath,
    );
  }
}

/// A closed region filled with a solid color, a gradient, or a halftone.
///
/// Produced by the paint bucket and by region fills; rendered from [path].
class RegionAction extends UserActionDrawing {
  RegionAction({
    required super.positions,
    required this.path,
    this.fillColor,
    this.gradient,
    this.halftoneFill,
    super.clipPath,
  }) : super(action: ActionType.region);

  @override
  final ui.Path path;

  @override
  final Color? fillColor;

  @override
  final Gradient? gradient;

  @override
  final HalftoneFill? halftoneFill;

  @override
  RegionAction copyWith({
    List<ui.Offset>? positions,
    ui.Path? path,
    ui.Image? image,
    ui.Path? clipPath,
    TextObject? textObject,
  }) {
    return RegionAction(
      positions: positions ?? this.positions,
      path: path ?? this.path,
      fillColor: fillColor,
      gradient: gradient,
      halftoneFill: halftoneFill,
      clipPath: clipPath ?? this.clipPath,
    );
  }
}

/// Erases the pixels inside a region.
class CutAction extends UserActionDrawing {
  CutAction({
    required this.path,
    List<ui.Offset>? positions,
    this.erasesEntireLayer = false,
    super.clipPath,
  }) : super(action: ActionType.cut, positions: positions ?? <ui.Offset>[]);

  @override
  final ui.Path path;

  @override
  final bool erasesEntireLayer;

  @override
  CutAction copyWith({
    List<ui.Offset>? positions,
    ui.Path? path,
    ui.Image? image,
    ui.Path? clipPath,
    TextObject? textObject,
  }) {
    return CutAction(
      path: path ?? this.path,
      positions: positions ?? this.positions,
      erasesEntireLayer: erasesEntireLayer,
      clipPath: clipPath ?? this.clipPath,
    );
  }
}

/// Stamps a raster image onto the layer.
///
/// Also carries the flattened result of a smudge/blur commit, which is why
/// [action] is configurable rather than fixed to [ActionType.image].
class ImageAction extends UserActionDrawing {
  ImageAction({
    required super.positions,
    required this.image,
    super.action = ActionType.image,
    this.brush,
    this.fillColor,
    super.clipPath,
  });

  @override
  final ui.Image image;

  @override
  final MyBrush? brush;

  @override
  final Color? fillColor;

  @override
  ImageAction copyWith({
    List<ui.Offset>? positions,
    ui.Path? path,
    ui.Image? image,
    ui.Path? clipPath,
    TextObject? textObject,
  }) {
    return ImageAction(
      action: action,
      positions: positions ?? this.positions,
      image: image ?? this.image,
      brush: brush,
      fillColor: fillColor,
      clipPath: clipPath ?? this.clipPath,
    );
  }
}

/// Draws a text object onto the layer.
class TextAction extends UserActionDrawing {
  TextAction({
    required super.positions,
    required this.textObject,
    super.clipPath,
  }) : super(action: ActionType.text);

  @override
  final TextObject textObject;

  @override
  TextAction copyWith({
    List<ui.Offset>? positions,
    ui.Path? path,
    ui.Image? image,
    ui.Path? clipPath,
    TextObject? textObject,
  }) {
    return TextAction(
      positions: positions ?? this.positions,
      textObject: textObject ?? this.textObject,
      clipPath: clipPath ?? this.clipPath,
    );
  }
}

/// An action that records intent but paints nothing itself.
///
/// The paint bucket commits its pixels as a [RegionAction]; the selector draws
/// through the selection overlay. Both still need a stack entry so undo and
/// tool bookkeeping stay in step.
class NonRenderingAction extends UserActionDrawing {
  NonRenderingAction({required super.action, List<ui.Offset>? positions, super.clipPath})
    : super(positions: positions ?? <ui.Offset>[]);

  @override
  NonRenderingAction copyWith({
    List<ui.Offset>? positions,
    ui.Path? path,
    ui.Image? image,
    ui.Path? clipPath,
    TextObject? textObject,
  }) {
    return NonRenderingAction(
      action: action,
      positions: positions ?? this.positions,
      clipPath: clipPath ?? this.clipPath,
    );
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
