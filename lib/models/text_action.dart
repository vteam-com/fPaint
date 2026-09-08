part of 'user_action_drawing.dart';

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
