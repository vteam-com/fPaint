import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
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

/// What a committed [UserActionDrawing] is.
///
/// A record kind, not a tool: tools are `ToolKind`s, and several records
/// (pasted [image]s, [cut]s, [region]s) come from no tool at all.
enum ActionType {
  pencil,
  brush,
  smudge,
  blurBrush,
  line,
  circle,
  rectangle,
  region,
  fill,
  eraser,
  image,
  cut,
  text,
  ;

  /// Whether this records a pixel-brush (smudge/blur) patch.
  bool get isPixelBrush => this == ActionType.smudge || this == ActionType.blurBrush;

  @override
  String toString() {
    return name;
  }
}
