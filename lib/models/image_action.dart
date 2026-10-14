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

  /// Places [image] over [bounds] with the transparent brush/fill every
  /// stamped raster carries (pasted images, crop/resize results, pixel-brush
  /// patches). [bounds] supplies the top-left and bottom-right positions.
  factory ImageAction.placed({
    required ui.Image image,
    required ui.Rect bounds,
    ActionType action = ActionType.image,
  }) {
    return ImageAction(
      action: action,
      positions: <ui.Offset>[bounds.topLeft, bounds.bottomRight],
      brush: MyBrush(color: AppColors.transparent, size: AppMath.zero.toDouble()),
      fillColor: AppColors.transparent,
      image: image,
    );
  }

  /// [ImageAction.placed] with [image]'s own pixel size, top-left at [offset].
  factory ImageAction.placedAt({
    required ui.Image image,
    ui.Offset offset = ui.Offset.zero,
    ActionType action = ActionType.image,
  }) {
    return ImageAction.placed(
      image: image,
      bounds: offset & ui.Size(image.width.toDouble(), image.height.toDouble()),
      action: action,
    );
  }

  /// Covers the whole [canvasSize] with [image], carrying no brush or fill:
  /// the single action a layer is flattened into (merge, history compaction).
  factory ImageAction.flattened({
    required ui.Image image,
    required ui.Size canvasSize,
  }) {
    final ui.Rect bounds = ui.Offset.zero & canvasSize;
    return ImageAction(
      positions: <ui.Offset>[bounds.topLeft, bounds.bottomRight],
      image: image,
    );
  }

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
