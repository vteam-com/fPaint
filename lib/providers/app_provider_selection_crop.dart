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
      cropStates[layer]!.finalImage = cropImage(cropStates[layer]!.croppedImage, effectiveBounds);
    }

    undoProvider.executeAction(
      name: 'Crop',
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
    return cropImage(maskedImage, bounds);
  }
}
