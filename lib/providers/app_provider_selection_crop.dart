part of 'app_provider_selection.dart';

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
        originalActions: List<UserActionDrawing>.from(layer.actionStack),
        originalRedoActions: List<UserActionDrawing>.from(layer.redoStack),
        originalHasChanged: layer.hasChanged,
        originalBackgroundColor: layer.backgroundColor,
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

    // Textures the Crop record can resurrect: each layer's committed crop result
    // (re-added by forward on redo) plus the original action/redo images that
    // backward restores on undo. Listing them defers disposal until the record
    // leaves history (the reachability check prevents any use-after-free) instead
    // of stranding these full-canvas textures — the same protocol merge and the
    // pixel brush already use.
    final List<ui.Image> retainedImages = <ui.Image>[
      for (final LayerProvider layer in layers.list) ...<ui.Image>[
        cropStates[layer]!.finalImage,
        for (final UserActionDrawing action in cropStates[layer]!.originalActions)
          if (action.image != null) action.image!,
        for (final UserActionDrawing action in cropStates[layer]!.originalRedoActions)
          if (action.image != null) action.image!,
      ],
    ];

    undoProvider.executeAction(
      name: 'Crop',
      retainedImages: retainedImages,
      forward: () {
        layers.size = Size(effectiveBounds.width, effectiveBounds.height);

        for (final LayerProvider layer in layers.list) {
          layer.actionStack.clear();
          layer.redoStack.clear();
          layer.backgroundColor = null;
          layer.addImage(
            imageToAdd: cropStates[layer]!.finalImage,
            offset: Offset.zero,
          );
        }

        selectorModel.clear();
        repaintToolOptions();
        update();
      },
      backward: () {
        layers.size = originalSize;

        for (final LayerProvider layer in layers.list) {
          final LayerCropState state = cropStates[layer]!;
          layer.actionStack
            ..clear()
            ..addAll(state.originalActions);
          layer.redoStack
            ..clear()
            ..addAll(state.originalRedoActions);
          layer.hasChanged = state.originalHasChanged;
          layer.backgroundColor = state.originalBackgroundColor;
          layer.clearCache();
        }

        update();
      },
    );
  }

  /// Renders the selection [cropPath] as an opaque white mask sized to the canvas.
  Future<ui.Image> _renderSelectionMask(
    final ui.Path cropPath,
    final int width,
    final int height,
  ) {
    return renderCanvasImage(
      width: width,
      height: height,
      draw: (final ui.Canvas maskCanvas) {
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
    final LayerProvider layer, {
    required final ui.Path cropPath,
    required final Rect bounds,
    required final int width,
    required final int height,
  }) async {
    final ui.Image layerImage = layer.renderImageWH(width, height);

    final ui.Image maskedImage = await renderCanvasImage(
      width: width,
      height: height,
      draw: (final ui.Canvas canvas) {
        canvas.save();
        canvas.clipPath(cropPath);
        canvas.drawImage(layerImage, Offset.zero, ui.Paint());
        canvas.restore();
      },
    );
    // maskedImage is fully rasterized (awaited), so the full-canvas source raster
    // is no longer needed — release it instead of stranding a texture per layer.
    layerImage.dispose();

    final ui.Image cropped = cropImage(maskedImage, bounds);
    // cropImage's picture samples maskedImage; the engine ref-counts the texture
    // for the pending raster, so releasing this full-canvas intermediate now is
    // safe (same invariant the GPU brush relies on).
    maskedImage.dispose();
    return cropped;
  }
}
