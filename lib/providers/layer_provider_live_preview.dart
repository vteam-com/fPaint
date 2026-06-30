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
    _livePreviewBaseline = renderImageWH(size.width.toInt(), size.height.toInt());
    _livePreviewPatchImage = null;
    _livePreviewPatchBounds = null;
  }

  /// The full-layer baseline image captured at the start of a pixel-brush
  /// stroke. Used to seed the GPU stroke without a readback.
  ui.Image? get livePreviewBaseline => _livePreviewBaseline;

  /// Updates the live patch image composited over the baseline during a stroke.
  void setLivePixelBrushPatch(final ui.Image? image, final ui.Rect? bounds) {
    // Free the previous preview-owned patch before replacing (avoids a per-segment leak).
    if (!identical(_livePreviewPatchImage, image)) {
      _livePreviewPatchImage?.dispose();
    }
    _livePreviewPatchImage = image;
    _livePreviewPatchBounds = bounds;
  }

  /// Replaces the full live-preview image (used by the GPU stroke, which keeps
  /// the whole accumulated result on the GPU). Clears any partial patch.
  ///
  /// IMPORTANT: this must NOT dispose the previous baseline. The GPU stroke owns
  /// the working-image chain: [GpuPixelBrushStroke.create] adopts the baseline as
  /// its first working image and every `dab()` disposes the prior working image
  /// before producing the next. So by the time this setter runs, the previous
  /// `_livePreviewBaseline` has already been freed by `dab()` — disposing it here
  /// would be a double-free. Ownership of [image] likewise stays with the stroke
  /// until commit (`detachImage`), so [clearLivePixelBrushPreview] also leaves the
  /// baseline alone.
  void setLivePixelBrushImage(final ui.Image image) {
    _livePreviewBaseline = image;
    _livePreviewPatchImage = null;
    _livePreviewPatchBounds = null;
  }

  /// Clears all live preview state, returning [renderLayer] to its normal path.
  void clearLivePixelBrushPreview() {
    // Free the preview-owned patch. The baseline is NOT disposed: the GPU path
    // hands it to the committed action's image, so the action stack owns it.
    _livePreviewPatchImage?.dispose();
    _livePreviewBaseline = null;
    _livePreviewPatchImage = null;
    _livePreviewPatchBounds = null;
  }
}
