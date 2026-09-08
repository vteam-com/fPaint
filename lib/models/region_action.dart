part of 'user_action_drawing.dart';

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
