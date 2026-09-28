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
    this.pressures,
    super.clipPath,
  });

  @override
  final MyBrush brush;

  @override
  final Color? fillColor;

  /// Normalized (0..1) stylus pressure for each point, parallel to
  /// [positions], or null when the stroke was not drawn with a pressure pen.
  ///
  /// Only Brush strokes record it; the renderer then varies the stroke width
  /// per segment. Mutable like [positions]: points are appended while the
  /// gesture is in flight.
  final List<double>? pressures;

  @override
  StrokeAction copyWith({
    List<ui.Offset>? positions,
    ui.Path? path,
    ui.Image? image,
    ui.Path? clipPath,
    TextObject? textObject,
  }) {
    // Geometric transforms move points one-for-one, so the pressure samples
    // stay aligned with the rebuilt positions.
    return StrokeAction(
      action: action,
      positions: positions ?? this.positions,
      brush: brush,
      fillColor: fillColor,
      pressures: pressures,
      clipPath: clipPath ?? this.clipPath,
    );
  }
}
