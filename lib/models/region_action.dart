part of 'user_action_drawing.dart';

/// A closed region filled with a solid color, a gradient, a halftone, or a
/// hatch pattern.
///
/// Produced by the paint bucket and by region fills; rendered from [path].
class RegionAction extends UserActionDrawing {
  RegionAction({
    required super.positions,
    required this.path,
    this.fillColor,
    this.gradient,
    this.halftoneFill,
    this.hatchPattern,
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
  final HatchPattern? hatchPattern;

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
      hatchPattern: hatchPattern,
      clipPath: clipPath ?? this.clipPath,
    );
  }
}
