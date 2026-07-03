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
  ///
  /// Targets the active selection when one is visible; otherwise the effect
  /// applies to the whole active layer without creating a lingering
  /// select-all region.
  Future<void> startEffectPreview(
    final SelectionEffect effect, {
    final double strength = AppEffects.defaultIntensity,
    final double? size,
  }) async {
    if (isSelectedLayerLocked) {
      return;
    }

    final bool hasSelection = selectorModel.isVisible && selectorModel.path1 != null;

    final Path selectionPath;
    final Rect bounds;
    final ui.Image sourceImage;

    if (hasSelection) {
      final ui.Image? clippedImage = await createSelectionImage();
      if (clippedImage == null) {
        return;
      }
      sourceImage = clippedImage;
      selectionPath = Path.from(selectorModel.path1!);
      bounds = selectorModel.path1!.getBounds();
    } else {
      bounds = Offset.zero & layers.size;
      selectionPath = Path()..addRect(bounds);
      sourceImage = layers.selectedLayer.toImageForStorage(layers.size);
    }

    effectPreviewModel.start(
      selectedEffect: effect,
      selectionImage: sourceImage,
      selectionPath: selectionPath,
      selectionBounds: bounds,
      initialStrength: strength,
      initialSize: size ?? effect.defaultSize,
    );

    repaintToolOptions();

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
    repaintToolOptions();

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
    repaintToolOptions();
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

  /// Toggles the Adjust family between Apply and Paint modes. Entering Paint
  /// cancels an active Apply preview; leaving it disarms any armed effect.
  void setEffectPaintMode({required final bool enabled}) {
    effectBrushModel.paintMode = enabled;
    if (enabled) {
      if (effectPreviewModel.isVisible) {
        effectPreviewModel.clear();
        effectPreviewRenderVersion++;
      }
    } else {
      effectBrushModel.disarm();
    }
    repaintToolOptions();
    update();
  }

  /// Arms [effect] for painting onto the canvas, cancelling any Apply preview.
  void armEffectBrush(final SelectionEffect effect) {
    if (effectPreviewModel.isVisible) {
      effectPreviewModel.clear();
      effectPreviewRenderVersion++;
    }
    effectBrushModel.arm(effect);
    repaintToolOptions();
    update();
  }

  /// Disarms the paint effect (e.g. tapping the armed effect again).
  void disarmEffectBrush() {
    effectBrushModel.disarm();
    repaintToolOptions();
    update();
  }

  /// Updates the strength used by painted effect strokes.
  void setEffectBrushStrength(final double strength) {
    effectBrushModel.strength = strength;
    repaintToolOptions();
  }

  /// Commits one painted effect stroke: applies [effect] to the brushed region
  /// of the selected layer, masks it to the stroke band (and the active
  /// selection, if any), and overlays the result as one undoable action.
  ///
  /// Cost scales with the brushed region, not the whole canvas, so this avoids
  /// the full-canvas readback stall a layer-wide filter would incur.
  Future<void> commitEffectBrushStroke({
    required final SelectionEffect effect,
    required final double strength,
    required final double size,
    required final List<Offset> strokePoints,
    required final Rect strokeBounds,
    required final double brushSize,
    required final Path? clipPath,
  }) async {
    if (isSelectedLayerLocked || strokePoints.length < AppMath.pair) {
      return;
    }

    final double rawRadius = brushSize * AppInteraction.smudgeBrushRadiusFactor;
    final double radius = rawRadius > AppInteraction.smudgeMinimumRadius
        ? rawRadius
        : AppInteraction.smudgeMinimumRadius;

    final int canvasWidth = layers.size.width.toInt();
    final int canvasHeight = layers.size.height.toInt();
    final int left = (strokeBounds.left - radius).floor().clamp(AppMath.zero, canvasWidth);
    final int top = (strokeBounds.top - radius).floor().clamp(AppMath.zero, canvasHeight);
    final int right = (strokeBounds.right + radius).ceil().clamp(AppMath.zero, canvasWidth);
    final int bottom = (strokeBounds.bottom + radius).ceil().clamp(AppMath.zero, canvasHeight);
    final int width = right - left;
    final int height = bottom - top;
    if (width <= AppMath.zero || height <= AppMath.zero) {
      return;
    }

    final Rect regionRect = Rect.fromLTWH(left.toDouble(), top.toDouble(), width.toDouble(), height.toDouble());
    final ui.Image layerImage = await layers.captureLayerRegion(layers.selectedLayerIndex, regionRect);
    final ui.Image processed = await effect.apply(layerImage, strength: strength, size: size);
    layerImage.dispose();

    final Offset regionOrigin = Offset(left.toDouble(), top.toDouble());
    final Path bandPath = _effectBrushBandPath(strokePoints, regionOrigin, radius);

    // Clip the processed region to the brushed band (and the active selection):
    // clipPath on a fillable path is the same masking idiom the Apply flow uses.
    final ui.Image patch = await renderCanvasImage(
      width: width,
      height: height,
      draw: (final ui.Canvas canvas) {
        canvas.save();
        if (clipPath != null) {
          canvas.clipPath(clipPath.shift(-regionOrigin), doAntiAlias: true);
        }
        canvas.clipPath(bandPath, doAntiAlias: true);
        canvas.drawImage(processed, Offset.zero, ui.Paint());
        canvas.restore();
      },
    );
    processed.dispose();

    undoProvider.executeAction(
      name: effect.name,
      forward: () {
        layers.selectedLayer.addImage(imageToAdd: patch, offset: regionOrigin);
        update();
      },
      backward: () {
        layers.selectedLayer.undo();
        update();
      },
    );
    update();
  }

  /// Builds a fillable "capsule chain" path covering the brushed stroke, in
  /// region-local coordinates: a disc of [radius] at every point plus a
  /// [radius]-wide quad between consecutive points. Used to clip a painted
  /// effect to the stroke footprint (a stroked polyline is not a fill region).
  Path _effectBrushBandPath(
    final List<Offset> strokePoints,
    final Offset regionOrigin,
    final double radius,
  ) {
    final Path band = Path();
    for (final Offset point in strokePoints) {
      band.addOval(Rect.fromCircle(center: point - regionOrigin, radius: radius));
    }
    for (int i = AppMath.zero; i < strokePoints.length - AppMath.one; i++) {
      final Offset a = strokePoints[i] - regionOrigin;
      final Offset b = strokePoints[i + AppMath.one] - regionOrigin;
      final Offset delta = b - a;
      final double length = delta.distance;
      if (length <= AppMath.zero) {
        continue;
      }
      final Offset normal = Offset(-delta.dy, delta.dx) / length * radius;
      band.addPolygon(<Offset>[a + normal, b + normal, b - normal, a - normal], true);
    }
    return band;
  }
}
