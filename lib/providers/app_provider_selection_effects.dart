part of 'app_provider_selection.dart';

/// Effect-preview operations split from the main selection file to keep the
/// primary selection workflow under the repo's LOC quality gate.
extension AppProviderSelectionEffects on AppProvider {
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
    final Path erasePath = Path.from(effectPreviewModel.erasePath!);
    final Rect bounds = effectPreviewModel.bounds!;
    final double strength = effectPreviewModel.strength;
    final double size = effectPreviewModel.size;

    final ui.Image processedImage = await effect.apply(
      sourceImage,
      strength: strength,
      size: size,
    );

    effectPreviewModel.clear();

    replaceRegion(
      name: effect.name,
      erasePath: erasePath,
      replacement: processedImage,
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
    if (!effectPreviewModel.isVisible || effect == null || sourceImage == null) {
      return;
    }

    final int requestVersion = ++effectPreviewRenderVersion;
    final double strength = effectPreviewModel.strength;
    final double size = effectPreviewModel.size;
    final ui.Image previewImage = await effect.apply(
      sourceImage,
      strength: strength,
      size: size,
    );

    if (!effectPreviewModel.isVisible || requestVersion != effectPreviewRenderVersion) {
      return;
    }

    effectPreviewModel.previewImage = previewImage;
    update();
  }
}
