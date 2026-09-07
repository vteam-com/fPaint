part of 'layer_provider.dart';

/// Snapshot capture/restore of a [LayerProvider]'s undoable content state.
///
/// Extracted into a `part of` extension to keep [LayerProvider] under fCheck's
/// per-class LOC limit (same rationale as [LayerTransform]). This is the single
/// authority for which fields a layer restore covers; undo flows must not
/// hand-roll their own field lists (the copies drift — a cancel path once
/// restored stacks but not blend mode/opacity).
extension LayerSnapshot on LayerProvider {
  /// Captures every field [restoreFromSnapshot] puts back.
  LayerStateSnapshot captureSnapshot() {
    return LayerStateSnapshot(
      actions: List<UserActionDrawing>.from(actionStack),
      redoActions: List<UserActionDrawing>.from(redoStack),
      hasChanged: hasChanged,
      backgroundColor: backgroundColor,
      blendMode: blendMode,
      opacity: opacity,
    );
  }

  /// Restores the layer to [snapshot] and drops the stale render cache.
  void restoreFromSnapshot(LayerStateSnapshot snapshot) {
    actionStack
      ..clear()
      ..addAll(snapshot.actions);
    redoStack
      ..clear()
      ..addAll(snapshot.redoActions);
    backgroundColor = snapshot.backgroundColor;
    blendMode = snapshot.blendMode;
    opacity = snapshot.opacity;
    hasChanged = snapshot.hasChanged;
    clearCache();
  }
}
