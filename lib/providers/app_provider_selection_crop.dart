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

    final ui.PictureRecorder maskRecorder = ui.PictureRecorder();
    final ui.Canvas maskCanvas = ui.Canvas(maskRecorder);
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
    final ui.Image selectionMask = await maskRecorder.endRecording().toImage(
      originalWidth,
      originalHeight,
    );

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

    final Map<LayerProvider, List<UserActionDrawing>> originalActions = <LayerProvider, List<UserActionDrawing>>{};
    final Map<LayerProvider, List<UserActionDrawing>> originalRedoActions = <LayerProvider, List<UserActionDrawing>>{};
    final Map<LayerProvider, bool> originalHasChanged = <LayerProvider, bool>{};
    final Map<LayerProvider, Color?> originalBackgroundColors = <LayerProvider, Color?>{};
    final Map<LayerProvider, ui.Image> croppedImages = <LayerProvider, ui.Image>{};

    Rect? finalContentBounds;

    for (final LayerProvider layer in layers.list) {
      originalActions[layer] = List<UserActionDrawing>.from(layer.actionStack);
      originalRedoActions[layer] = List<UserActionDrawing>.from(layer.redoStack);
      originalHasChanged[layer] = layer.hasChanged;
      originalBackgroundColors[layer] = layer.backgroundColor;

      final ui.Image layerImage = layer.renderImageWH(originalWidth, originalHeight);

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      canvas.save();
      canvas.clipPath(cropPath);
      canvas.drawImage(layerImage, Offset.zero, ui.Paint());
      canvas.restore();

      final ui.Image maskedImage = await recorder.endRecording().toImage(originalWidth, originalHeight);
      final ui.Image layerCrop = cropImage(maskedImage, bounds);
      croppedImages[layer] = layerCrop;

      final Rect? layerBounds = await getNonTransparentBounds(layerCrop);
      if (layerBounds != null && layerBounds.width > 0 && layerBounds.height > 0) {
        if (finalContentBounds == null) {
          finalContentBounds = layerBounds;
        } else {
          finalContentBounds = finalContentBounds.expandToInclude(layerBounds);
        }
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

    final Map<LayerProvider, ui.Image> finalImages = <LayerProvider, ui.Image>{};
    for (final LayerProvider layer in layers.list) {
      finalImages[layer] = cropImage(croppedImages[layer]!, effectiveBounds);
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
            imageToAdd: finalImages[layer]!,
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
          layer.actionStack
            ..clear()
            ..addAll(originalActions[layer]!);
          layer.redoStack
            ..clear()
            ..addAll(originalRedoActions[layer]!);
          layer.hasChanged = originalHasChanged[layer]!;
          layer.backgroundColor = originalBackgroundColors[layer];
          layer.clearCache();
        }

        update();
      },
    );
  }
}
