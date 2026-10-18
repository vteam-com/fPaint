part of 'layers_provider.dart';

/// Document-level helpers shared by the file readers and exporters.
///
/// Kept out of the stack-owning class so the import/export plumbing does not
/// grow [LayersProvider] itself.
extension LayersProviderDocument on LayersProvider {
  /// Selects [layer] when it is still part of the stack; no-op otherwise.
  ///
  /// Layered readers rebuild the stack through [LayersProvider.replaceAll],
  /// which resets the selection to the first layer, so they call this once the
  /// rebuild completes to restore the layer their file marked as selected.
  void selectLayerIfPresent(LayerProvider? layer) {
    if (layer == null) {
      return;
    }
    final int index = getLayerIndex(layer);
    if (index >= 0) {
      selectedLayerIndex = index;
    }
  }

  /// Captures the selected layer so an undo can restore it exactly (same-layer
  /// duplicate, layer modify, pixel-brush commits).
  ImagePlacementLayerRestoreState captureSelectedLayerRestoreState() {
    return ImagePlacementLayerRestoreState(
      layerIndex: selectedLayerIndex,
      layerState: selectedLayer.captureSnapshot(),
    );
  }

  /// Returns the flattened canvas for export, reusing [LayersProvider.cachedImage]
  /// when nothing changed since it was rendered.
  ///
  /// The returned image is always owned by the provider (a fresh render is
  /// stored back into [LayersProvider.cachedImage]), so callers must never
  /// dispose it.
  Future<ui.Image> captureCompositeForExport() {
    final ui.Image? cached = cachedImage;
    if (!hasChanged && cached != null) {
      return Future<ui.Image>.value(cached);
    }
    return capturePainterToImage();
  }
}
