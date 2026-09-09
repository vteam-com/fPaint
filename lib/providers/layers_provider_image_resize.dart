part of 'layers_provider.dart';

/// Whole-image resampling: scales every layer's pixels to a new canvas size.
///
/// This is "Image Size" as opposed to [LayersProvider.canvasResize] ("Canvas
/// Size"), which only changes the bounds and slides the content. Kept as a
/// part-file extension, like [LayersProviderCanvasGeometry], so the stack owner
/// stays under fCheck's per-file LOC limit.
extension LayersProviderImageResize on LayersProvider {
  /// Resamples every layer to [newWidth] × [newHeight] as one undoable step.
  ///
  /// Each layer with drawn content is rasterized at the current size and redrawn
  /// scaled into a single image action (the same flatten crop performs), so the
  /// result is a faithful pixel resample regardless of which brushes, fills or
  /// text produced it. A layer that carries only a background fill keeps it — a
  /// fill is size-independent — and an empty layer is left alone rather than
  /// given a full-canvas transparent texture. Undo restores each layer's exact
  /// snapshot, so the vector action stacks come back intact.
  Future<void> resizeImage(int newWidth, int newHeight) async {
    if (newWidth <= 0 || newHeight <= 0) {
      return;
    }
    final Size oldSize = size;
    final Size newSize = Size(newWidth.toDouble(), newHeight.toDouble());
    if (oldSize == newSize) {
      return;
    }

    final Map<LayerProvider, LayerStateSnapshot> snapshots = <LayerProvider, LayerStateSnapshot>{};
    final Map<LayerProvider, ui.Image> scaledImages = <LayerProvider, ui.Image>{};
    for (final LayerProvider layer in _list) {
      // Capture before rendering so the snapshot reflects the untouched layer.
      snapshots[layer] = layer.captureSnapshot();
      if (layer.actionStack.isEmpty) {
        continue;
      }
      scaledImages[layer] = await _resampleLayer(layer, oldSize, newSize);
    }

    // Textures the record can resurrect: each scaled result (re-added by
    // forward on redo) plus the original action/redo images (restored on undo).
    // Listing them defers disposal until the record leaves history — the same
    // protocol crop, merge and the pixel brush use.
    final List<ui.Image> retainedImages = <ui.Image>[
      ...scaledImages.values,
      for (final LayerStateSnapshot snapshot in snapshots.values) ...<ui.Image>[
        for (final UserActionDrawing action in snapshot.actions)
          if (action.image != null) action.image!,
        for (final UserActionDrawing action in snapshot.redoActions)
          if (action.image != null) action.image!,
      ],
    ];

    await _undoProvider.executeActionAsync(
      name: 'Resize Image',
      retainedImages: retainedImages,
      forward: () {
        size = newSize;
        for (final LayerProvider layer in _list) {
          final ui.Image? scaled = scaledImages[layer];
          if (scaled == null) {
            continue;
          }
          layer.actionStack.clear();
          layer.redoStack.clear();
          // The fill was baked into the resampled raster.
          layer.backgroundColor = null;
          layer.addImage(imageToAdd: scaled);
        }
        update();
      },
      backward: () {
        size = oldSize;
        for (final LayerProvider layer in _list) {
          layer.restoreFromSnapshot(snapshots[layer]!);
        }
        update();
      },
    );
  }

  /// Rasterizes [layer] at [oldSize] and returns it resampled to [newSize].
  ///
  /// Shrinking samples through mipmaps ([ui.FilterQuality.medium]) so heavy
  /// reductions do not alias; enlarging uses cubic interpolation.
  Future<ui.Image> _resampleLayer(LayerProvider layer, Size oldSize, Size newSize) async {
    final ui.Image source = layer.renderImageWH(oldSize.width.toInt(), oldSize.height.toInt());
    final bool isShrinking = newSize.width < oldSize.width || newSize.height < oldSize.height;
    final ui.Paint paint = ui.Paint()..filterQuality = isShrinking ? ui.FilterQuality.medium : ui.FilterQuality.high;
    final ui.Image scaled = await renderCanvasImage(
      width: newSize.width.toInt(),
      height: newSize.height.toInt(),
      draw: (ui.Canvas canvas) => canvas.drawImageRect(
        source,
        Offset.zero & oldSize,
        Offset.zero & newSize,
        paint,
      ),
    );
    // The scaled raster is fully rasterized (awaited), so the full-size source
    // is no longer needed — release it instead of stranding a texture per layer.
    source.dispose();
    return scaled;
  }
}
