part of 'user_action_drawing.dart';

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
