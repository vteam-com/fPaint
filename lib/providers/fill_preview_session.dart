part of 'app_provider.dart';

/// Owns the live paint-bucket fill preview session: the fill configuration,
/// the held (never-baked) preview action, and the monotonic render version
/// that invalidates stale async region resolves.
///
/// Follows the [WandSelectionManager] pattern: the session is a plain state
/// owner; committing the held action into undo history stays on [AppProvider]
/// (see `commitFillPreview`), which is the layer that can record actions.
class FillPreviewSession {
  /// The fill model (solid/gradient mode, gradient handles, halftone config).
  final FillModel fillModel = FillModel();

  /// The **held** fill preview action — the region to fill plus its solid
  /// colour / gradient / halftone. It is drawn by a lightweight canvas overlay
  /// (`renderRegion`) and is **never** appended to the layer or the undo
  /// stack, so re-previewing while dragging costs O(region path), not a
  /// full-canvas re-composite. Committing records it as exactly one undoable
  /// action; cancelling drops it.
  UserActionDrawing? heldAction;

  /// Monotonic token that invalidates stale async fill-region resolves.
  int renderVersion = 0;

  /// Whether a live gradient-fill preview session is active. Only
  /// [FillModel.isVisible] gradient sessions set this; solid fills preview
  /// only during the pointer press and commit on release.
  bool get isGradientPreviewActive => fillModel.isVisible;

  /// Invalidates any in-flight region resolve and returns the held preview
  /// action (clearing it), or null when nothing has been previewed yet.
  UserActionDrawing? takeHeldAction() {
    renderVersion++;
    final UserActionDrawing? held = heldAction;
    heldAction = null;
    return held;
  }

  /// Invalidates any in-flight region resolve and drops the held preview.
  void clearHeldAction() {
    renderVersion++;
    heldAction = null;
  }
}
