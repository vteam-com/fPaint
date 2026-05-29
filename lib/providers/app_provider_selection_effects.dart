part of 'app_provider_selection.dart';

/// Effect-preview operations split from the main selection file to keep the
/// primary selection workflow under the repo's LOC quality gate.
extension AppProviderSelectionEffects on AppProvider {
  /// Re-applies the selection mask so effect output stays inside the region.
  Future<ui.Image> _maskEffectImageToSelection(
    final ui.Image image, {
    required final Path selectionPath,
    required final Rect bounds,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final Path localSelectionPath = selectionPath.shift(
      Offset(-bounds.left, -bounds.top),
    );

    canvas.save();
    canvas.clipPath(localSelectionPath, doAntiAlias: true);
    canvas.drawImage(image, Offset.zero, ui.Paint());
    canvas.restore();

    return recorder.endRecording().toImage(image.width, image.height);
  }

  /// Starts live preview mode for the selected [effect], [strength], and [size].
  Future<void> startEffectPreview(
    final SelectionEffect effect, {
    final double strength = AppEffects.defaultIntensity,
    final double? size,
  }) async {
    if (isSelectedLayerLocked) {
      return;
    }

    _ensureSelection();

    final ui.Image? clippedImage = await createSelectionImage();
    if (clippedImage == null) {
      return;
    }

    final Path selectionPath = Path.from(selectorModel.path1!);
    final Rect bounds = selectorModel.path1!.getBounds();

    effectPreviewModel.start(
      selectedEffect: effect,
      selectionImage: clippedImage,
      selectionPath: selectionPath,
      selectionBounds: bounds,
      initialStrength: strength,
      initialSize: size ?? effect.defaultSize,
    );

    await _renderEffectPreview();
  }

  /// Updates the active preview intensity and re-renders the effect live.
  Future<void> updateEffectPreviewStrength(final double strength) async {
    if (!effectPreviewModel.isVisible) {
      return;
    }

    effectPreviewModel.strength = strength;
    await _renderEffectPreview();
  }

  /// Updates the active preview size and re-renders the effect live.
  Future<void> updateEffectPreviewSize(final double size) async {
    if (!effectPreviewModel.isVisible) {
      return;
    }

    effectPreviewModel.size = size;
    await _renderEffectPreview();
  }

  /// Commits the current effect preview as a single undoable action.
  Future<void> confirmEffectPreview() async {
    if (!effectPreviewModel.isVisible ||
        effectPreviewModel.effect == null ||
        effectPreviewModel.sourceImage == null ||
        effectPreviewModel.erasePath == null ||
        effectPreviewModel.bounds == null) {
      return;
    }

    final SelectionEffect effect = effectPreviewModel.effect!;
    final ui.Image sourceImage = effectPreviewModel.sourceImage!;
    final Path selectionPath = Path.from(effectPreviewModel.erasePath!);
    final Rect bounds = effectPreviewModel.bounds!;
    final double strength = effectPreviewModel.strength;
    final double size = effectPreviewModel.size;

    final ui.Image processedImage = await effect.apply(
      sourceImage,
      strength: strength,
      size: size,
    );
    final ui.Image maskedImage = await _maskEffectImageToSelection(
      processedImage,
      selectionPath: selectionPath,
      bounds: bounds,
    );

    effectPreviewModel.clear();

    replaceRegion(
      name: effect.name,
      erasePath: selectionPath,
      replacement: maskedImage,
      offset: Offset(bounds.left, bounds.top),
    );

    update();
  }

  /// Cancels the active effect preview without committing changes.
  void cancelEffectPreview() {
    if (!effectPreviewModel.isVisible) {
      return;
    }

    effectPreviewModel.clear();
    effectPreviewRenderVersion++;
    update();
  }

  /// Renders the effect preview image and updates overlay listeners.
  Future<void> _renderEffectPreview() async {
    final SelectionEffect? effect = effectPreviewModel.effect;
    final ui.Image? sourceImage = effectPreviewModel.sourceImage;
    final Path? selectionPath = effectPreviewModel.erasePath;
    final Rect? bounds = effectPreviewModel.bounds;
    if (!effectPreviewModel.isVisible ||
        effect == null ||
        sourceImage == null ||
        selectionPath == null ||
        bounds == null) {
      return;
    }

    final int requestVersion = ++effectPreviewRenderVersion;
    final double strength = effectPreviewModel.strength;
    final double size = effectPreviewModel.size;
    final ui.Image processedPreviewImage = await effect.apply(
      sourceImage,
      strength: strength,
      size: size,
    );

    if (!effectPreviewModel.isVisible || requestVersion != effectPreviewRenderVersion) {
      return;
    }

    final ui.Image previewImage = await _maskEffectImageToSelection(
      processedPreviewImage,
      selectionPath: selectionPath,
      bounds: bounds,
    );

    if (!effectPreviewModel.isVisible || requestVersion != effectPreviewRenderVersion) {
      return;
    }

    effectPreviewModel.previewImage = previewImage;
    update();
  }
}
