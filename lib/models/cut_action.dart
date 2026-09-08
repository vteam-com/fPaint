part of 'user_action_drawing.dart';

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
