part of 'user_action_drawing.dart';

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
