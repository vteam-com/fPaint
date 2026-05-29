part of 'app_provider_selection.dart';

/// Snapshot of the active effect preview state needed for rendering/commit.
class _SelectionEffectPreviewState {
  _SelectionEffectPreviewState({
    required this.effect,
    required this.sourceImage,
    required this.selectionPath,
    required this.bounds,
    required this.strength,
    required this.size,
  });

  final SelectionEffect effect;
  final ui.Image sourceImage;
  final Path selectionPath;
  final Rect bounds;
  final double strength;
  final double size;
}

/// Effect-preview operations split from the main selection file to keep the
/// primary selection workflow under the repo's LOC quality gate.
extension AppProviderSelectionEffects on AppProvider {
  /// Returns a stable snapshot of the current effect preview state.
  _SelectionEffectPreviewState? _currentEffectPreviewState() {
    if (!effectPreviewModel.isVisible ||
        effectPreviewModel.effect == null ||
        effectPreviewModel.sourceImage == null ||
        effectPreviewModel.erasePath == null ||
        effectPreviewModel.bounds == null) {
      return null;
    }

    return _SelectionEffectPreviewState(
      effect: effectPreviewModel.effect!,
      sourceImage: effectPreviewModel.sourceImage!,
      selectionPath: Path.from(effectPreviewModel.erasePath!),
      bounds: effectPreviewModel.bounds!,
      strength: effectPreviewModel.strength,
      size: effectPreviewModel.size,
    );
  }

  /// Updates one or both effect preview controls and re-renders the preview.
  Future<void> _updateEffectPreviewControls({
    final double? strength,
    final double? size,
  }) async {
    if (!effectPreviewModel.isVisible) {
      return;
    }

    if (strength != null) {
      effectPreviewModel.strength = strength;
    }
    if (size != null) {
      effectPreviewModel.size = size;
    }

    await _renderEffectPreview();
  }

  /// Re-applies the selection mask so effect output stays inside the region.
  Future<ui.Image> _maskEffectImageToSelection(
    final ui.Image image, {
    required final Path selectionPath,
    required final Rect bounds,
  }) async {
    final Path localSelectionPath = selectionPath.shift(
      Offset(-bounds.left, -bounds.top),
    );

    return renderCanvasImage(
      width: image.width,
      height: image.height,
      draw: (final ui.Canvas canvas) {
        canvas.save();
        canvas.clipPath(localSelectionPath, doAntiAlias: true);
        canvas.drawImage(image, Offset.zero, ui.Paint());
        canvas.restore();
      },
    );
  }

  /// Applies the active effect and re-masks it to the original selection.
  Future<ui.Image> _buildMaskedEffectImage(
    final _SelectionEffectPreviewState state,
  ) async {
    final ui.Image processedImage = await state.effect.apply(
      state.sourceImage,
      strength: state.strength,
      size: state.size,
    );

    return _maskEffectImageToSelection(
      processedImage,
      selectionPath: state.selectionPath,
      bounds: state.bounds,
    );
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
    await _updateEffectPreviewControls(strength: strength);
  }

  /// Updates the active preview size and re-renders the effect live.
  Future<void> updateEffectPreviewSize(final double size) async {
    await _updateEffectPreviewControls(size: size);
  }

  /// Commits the current effect preview as a single undoable action.
  Future<void> confirmEffectPreview() async {
    final _SelectionEffectPreviewState? state = _currentEffectPreviewState();
    if (state == null) {
      return;
    }

    final ui.Image maskedImage = await _buildMaskedEffectImage(state);

    effectPreviewModel.clear();

    replaceRegion(
      name: state.effect.name,
      erasePath: state.selectionPath,
      replacement: maskedImage,
      offset: Offset(state.bounds.left, state.bounds.top),
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
    final _SelectionEffectPreviewState? state = _currentEffectPreviewState();
    if (state == null) {
      return;
    }

    final int requestVersion = ++effectPreviewRenderVersion;
    final ui.Image previewImage = await _buildMaskedEffectImage(state);

    if (!effectPreviewModel.isVisible || requestVersion != effectPreviewRenderVersion) {
      return;
    }

    effectPreviewModel.previewImage = previewImage;
    update();
  }
}
