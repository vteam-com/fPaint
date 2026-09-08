part of 'user_action_drawing.dart';

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
