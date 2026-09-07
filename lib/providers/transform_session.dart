part of 'app_provider.dart';

/// Which flavor of floating session the active transform overlay belongs to,
/// in commit-precedence order. Resolved by [TransformSession.kind]; only
/// meaningful while a session is actually active (confirm/cancel guard on
/// [TransformModel.sourceImage] first).
enum TransformSessionKind {
  /// An "All layers" transform holding per-layer lifted content.
  crossLayer,

  /// A duplicate/paste session committing through the image-placement pipeline.
  preparedImage,

  /// A whole-layer modify session that replaces the source layer on commit.
  layerModify,

  /// A plain single-layer selection transform.
  selection,
}

/// Owns the state of a floating transform/placement session: the perspective
/// transform overlay, the prepared image placement (duplicate, paste, layer
/// modify), and the per-layer cross-layer lift.
///
/// Follows the [WandSelectionManager] pattern: one class holds the session's
/// models and answers "which kind of session is this", so confirm/cancel
/// dispatch is an exhaustive switch on [kind] instead of if-chains over three
/// separate fields scattered across the app-wide provider.
class TransformSession {
  /// The prepared image placement state used by duplicate, paste, and layer
  /// modify sessions.
  final ImagePlacementModel imagePlacementModel = ImagePlacementModel();

  /// The transform model for perspective/skew operations.
  final TransformModel transformModel = TransformModel();

  /// Per-layer lifted images while an "All layers" transform session is
  /// active; null otherwise.
  List<CrossLayerLiftEntry>? crossLayerLift;

  /// Whether layer replacement modify mode is active.
  bool get isLayerModifyMode =>
      imagePlacementModel.commitMode == ImagePlacementCommitMode.replaceLayer &&
      imagePlacementModel.layerRestoreState != null;

  /// Whether the active transform session lifted content from all layers.
  bool get isCrossLayerActive => crossLayerLift != null;

  /// Whether the transform entered through the prepared image placement
  /// pipeline (duplicate or paste).
  bool get _isPreparedImageSession =>
      transformModel.source == TransformSessionSource.duplicateSelection ||
      transformModel.source == TransformSessionSource.clipboardPaste;

  /// Resolves the active session kind, in commit-precedence order.
  TransformSessionKind get kind {
    if (isCrossLayerActive) {
      return TransformSessionKind.crossLayer;
    }
    if (_isPreparedImageSession) {
      return TransformSessionKind.preparedImage;
    }
    if (isLayerModifyMode) {
      return TransformSessionKind.layerModify;
    }
    return TransformSessionKind.selection;
  }

  /// Takes ownership of the lifted cross-layer entries, clearing the field.
  ///
  /// Returns null when no cross-layer session is active.
  List<CrossLayerLiftEntry>? takeCrossLayerLift() {
    final List<CrossLayerLiftEntry>? lift = crossLayerLift;
    crossLayerLift = null;
    return lift;
  }

  /// Releases the lifted per-layer textures when a cross-layer transform
  /// session ends without committing.
  void disposeCrossLayerLift() {
    final List<CrossLayerLiftEntry>? lift = takeCrossLayerLift();
    if (lift == null) {
      return;
    }
    for (final CrossLayerLiftEntry entry in lift) {
      entry.image.dispose();
    }
  }
}
