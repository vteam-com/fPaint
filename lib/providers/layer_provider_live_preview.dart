part of 'layer_provider.dart';

/// Live pixel-brush preview API for [LayerProvider].
///
/// During a smudge/blur stroke the layer bypasses the action stack and renders
/// from a pre-captured baseline plus an incrementally updated patch (see the
/// `_livePreview*` fields on [LayerProvider]). This avoids `clearCache()`,
/// action-stack manipulation, and a full action replay on every pointer-move.
extension LayerLivePreview on LayerProvider {
  /// Clears all live preview state, returning [renderLayer] to its normal path.
  void clearLivePixelBrushPreview() {
    _livePreviewPatchImage?.dispose();
    _livePreviewBaseline?.dispose();
    _livePreviewBaseline = null;
    _livePreviewPatchImage = null;
    _livePreviewPatchBounds = null;
  }
}

/// Action-stack history bounding for [LayerProvider].
extension LayerHistoryCollapse on LayerProvider {
  /// Drops actions hidden behind older whole-layer erases.
  ///
  /// Each whole-layer generation pins a full-canvas texture and is replayed on
  /// every cache rebuild, so keeping every one is unbounded in both memory and
  /// render cost. Returns the images that left the stack; the caller must run
  /// them through the reachability check before disposing.
  List<ui.Image> collapseFullyErasedActions() {
    final List<int> boundaries = <int>[];
    for (int index = 0; index < actionStack.length; index++) {
      if (actionStack[index].erasesEntireLayer) {
        boundaries.add(index);
      }
    }
    if (boundaries.length <= AppLimits.fullLayerImageGenerations) {
      return const <ui.Image>[];
    }

    final int collapseTo = boundaries[boundaries.length - AppLimits.fullLayerImageGenerations];
    final List<ui.Image> removed = <ui.Image>[];
    for (int index = 0; index < collapseTo; index++) {
      final ui.Image? image = actionStack[index].image;
      if (image != null) {
        removed.add(image);
      }
    }
    actionStack.removeRange(0, collapseTo);
    return removed;
  }
}
