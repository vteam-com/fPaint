part of 'layer_provider.dart';

/// Live pixel-brush preview API for [LayerProvider].
///
/// During a smudge/blur stroke the layer bypasses the action stack and renders
/// from a pre-captured baseline plus an incrementally updated patch (see the
/// `_livePreview*` fields on [LayerProvider]). This avoids `clearCache()`,
/// action-stack manipulation, and a full action replay on every pointer-move.
extension LayerLivePreview on LayerProvider {
  /// Captures the current layer rendering as the baseline for a pixel-brush stroke.
  ///
  /// Must be called once at the start of a stroke, before any points are
  /// appended. The captured image is composited with subsequent patch updates
  /// by [renderLayer] without touching the action stack or the cache.
  void beginLivePixelBrushPreview() {
    // Reclaim any baseline/patch left by a stroke whose cleanup was skipped
    // (cancelled/pointer-id-mismatched gesture); after a normal end both are
    // already released, so this only frees genuine orphans.
    if (!_livePreviewBaselineExternallyOwned) {
      _livePreviewBaseline?.dispose();
    }
    _livePreviewPatchImage?.dispose();
    _livePreviewBaseline = renderImageWH(size.width.toInt(), size.height.toInt());
    // Freshly rendered here: this layer owns it until a GPU stroke adopts it.
    _livePreviewBaselineExternallyOwned = false;
    _livePreviewPatchImage = null;
    _livePreviewPatchBounds = null;
  }

  /// Marks the current baseline as owned by the GPU stroke (which adopts it as
  /// its working image and later hands it to the committed action). After this,
  /// [clearLivePixelBrushPreview] leaves the baseline alone to avoid a double
  /// free / freeing a committed texture.
  void markLivePreviewBaselineExternallyOwned() {
    _livePreviewBaselineExternallyOwned = true;
  }

  /// The full-layer baseline image captured at the start of a pixel-brush
  /// stroke. Used to seed the GPU stroke without a readback.
  ui.Image? get livePreviewBaseline => _livePreviewBaseline;

  /// Updates the live patch image composited over the baseline during a stroke.
  ///
  /// [ownsImage] controls disposal: the CPU worker/sync path passes owned patches
  /// (default true) that this layer frees on replace/clear; the GPU stroke passes
  /// `false` because it retains and disposes its own patch, so the layer only
  /// references it.
  void setLivePixelBrushPatch(final ui.Image? image, final ui.Rect? bounds, {final bool ownsImage = true}) {
    // Free the previous layer-owned patch before replacing (avoids a per-segment
    // leak); never dispose an externally-owned (GPU-stroke) patch.
    if (!_livePreviewPatchExternallyOwned && !identical(_livePreviewPatchImage, image)) {
      _livePreviewPatchImage?.dispose();
    }
    _livePreviewPatchImage = image;
    _livePreviewPatchBounds = bounds;
    _livePreviewPatchExternallyOwned = !ownsImage;
  }

  /// Clears all live preview state, returning [renderLayer] to its normal path.
  void clearLivePixelBrushPreview() {
    // Dispose the patch/baseline only when this layer owns them (CPU worker/sync
    // path). On the GPU path the stroke owns them (freed by the stroke), or the
    // baseline became the committed action image — disposing here would
    // double-free or corrupt the commit.
    if (!_livePreviewPatchExternallyOwned) {
      _livePreviewPatchImage?.dispose();
    }
    if (!_livePreviewBaselineExternallyOwned) {
      _livePreviewBaseline?.dispose();
    }
    _livePreviewBaseline = null;
    _livePreviewBaselineExternallyOwned = false;
    _livePreviewPatchImage = null;
    _livePreviewPatchBounds = null;
    _livePreviewPatchExternallyOwned = false;
  }
}
