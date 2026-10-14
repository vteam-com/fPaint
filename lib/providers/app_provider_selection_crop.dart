part of 'app_provider.dart';

extension AppProviderSelectionCrop on AppProvider {
  /// Crops the canvas to the current selection bounds.
  Future<void> crop() async {
    cancelEffectPreview();
    final Path? selectionPath = selectorModel.path1;
    if (selectionPath == null) {
      return;
    }

    final int originalWidth = layers.width.toInt();
    final int originalHeight = layers.height.toInt();
    final ui.Path cropPath = Path.from(selectionPath);

    final ui.Image selectionMask = await _renderSelectionMask(cropPath, originalWidth, originalHeight);
    final Rect? maskBounds = await getNonTransparentBounds(selectionMask);
    // getNonTransparentBounds has read the mask back; it is not needed again.
    selectionMask.dispose();
    if (maskBounds == null || maskBounds.width <= 0 || maskBounds.height <= 0) {
      return;
    }

    final Rect canvasRect = Rect.fromLTWH(0, 0, layers.width, layers.height);
    final Rect bounds = maskBounds.intersect(canvasRect);
    if (bounds.width <= 0 || bounds.height <= 0) {
      return;
    }

    final Size originalSize = layers.size;

    final Map<LayerProvider, LayerCropState> cropStates = <LayerProvider, LayerCropState>{};
    Rect? finalContentBounds;

    for (final LayerProvider layer in layers.list) {
      // Capture the undo snapshot before rendering so the layer state is untouched.
      final LayerCropState state = LayerCropState(
        layerState: layer.captureSnapshot(),
        croppedImage: await _cropLayerToSelection(
          layer,
          cropPath: cropPath,
          bounds: bounds,
          width: originalWidth,
          height: originalHeight,
        ),
      );
      cropStates[layer] = state;

      final Rect? layerBounds = await getNonTransparentBounds(state.croppedImage);
      if (layerBounds != null && layerBounds.width > 0 && layerBounds.height > 0) {
        finalContentBounds = finalContentBounds == null ? layerBounds : finalContentBounds.expandToInclude(layerBounds);
      }
    }

    final Rect effectiveBounds = finalContentBounds == null
        ? Rect.fromLTWH(0, 0, bounds.width, bounds.height)
        : Rect.fromLTRB(
            finalContentBounds.left.floorToDouble(),
            finalContentBounds.top.floorToDouble(),
            finalContentBounds.right.ceilToDouble(),
            finalContentBounds.bottom.ceilToDouble(),
          );

    if (effectiveBounds.width <= 0 || effectiveBounds.height <= 0) {
      return;
    }

    for (final LayerProvider layer in layers.list) {
      final LayerCropState state = cropStates[layer]!;
      state.finalImage = cropImage(state.croppedImage, effectiveBounds);
      // finalImage is the trimmed crop; the selection-bounds intermediate that
      // produced it is superseded and otherwise leaks (one per layer per crop).
      state.croppedImage.dispose();
    }

    final LayerRasterReplacement replacement = LayerRasterReplacement(
      oldSize: originalSize,
      newSize: Size(effectiveBounds.width, effectiveBounds.height),
      snapshots: <LayerProvider, LayerStateSnapshot>{
        for (final LayerProvider layer in layers.list) layer: cropStates[layer]!.layerState,
      },
      images: <LayerProvider, ui.Image>{
        for (final LayerProvider layer in layers.list) layer: cropStates[layer]!.finalImage,
      },
    );

    // Listing the replacement's textures defers their disposal until the
    // record leaves history (the reachability check prevents any
    // use-after-free) — the same protocol merge and the pixel brush use.
    undoProvider.executeAction(
      name: 'Crop',
      retainedImages: replacement.retainedImages,
      forward: () {
        replacement.apply(layers);
        selectorModel.clear();
        updateWithToolOptions();
      },
      backward: () {
        replacement.revert(layers);
        update();
      },
    );
  }

  /// Renders the selection [cropPath] as an opaque white mask sized to the canvas.
  Future<ui.Image> _renderSelectionMask(
    ui.Path cropPath,
    int width,
    int height,
  ) {
    return renderCanvasImage(
      width: width,
      height: height,
      draw: (ui.Canvas maskCanvas) {
        maskCanvas.drawPath(
          cropPath,
          ui.Paint()
            ..color = const ui.Color.fromARGB(
              AppLimits.rgbChannelMax,
              AppLimits.rgbChannelMax,
              AppLimits.rgbChannelMax,
              AppLimits.rgbChannelMax,
            )
            ..style = ui.PaintingStyle.fill,
        );
      },
    );
  }

  /// Clips [layer] to [cropPath] and returns the result cropped to [bounds].
  Future<ui.Image> _cropLayerToSelection(
    LayerProvider layer, {
    required ui.Path cropPath,
    required Rect bounds,
    required int width,
    required int height,
  }) async {
    final ui.Image layerImage = layer.renderImageWH(width, height);
    try {
      return await clipImageToPath(layerImage, cropPath, bounds);
    } finally {
      // The clipped result is fully rasterized once awaited, so the
      // full-canvas source raster is no longer needed.
      layerImage.dispose();
    }
  }
}
