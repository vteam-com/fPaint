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
