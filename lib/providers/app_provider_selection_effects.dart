part of 'app_provider.dart';

/// Snapshot of the active effect preview state needed for rendering/commit.
class _SelectionEffectPreviewState {
  _SelectionEffectPreviewState({
    required this.effect,
    required this.sourceImage,
    required this.pixelScale,
    required this.selectionPath,
    required this.bounds,
    required this.strength,
    required this.size,
    required this.coversEntireLayer,
  });

  final SelectionEffect effect;
  final ui.Image sourceImage;
  final double pixelScale;
  final Path selectionPath;
  final Rect bounds;
  final double strength;
  final double size;
  final bool coversEntireLayer;
}

/// Effect-preview operations split from the main selection file to keep the
/// primary selection workflow under the repo's LOC quality gate.
extension AppProviderSelectionEffects on AppProvider {
  /// Returns a stable snapshot of the current effect preview state.
  ///
  /// When [fullResolution] is false the snapshot targets the downscaled proxy,
  /// which is what live preview renders from.
  _SelectionEffectPreviewState? _currentEffectPreviewState({bool fullResolution = false}) {
    if (!effectPreviewModel.isVisible ||
        effectPreviewModel.effect == null ||
        effectPreviewModel.sourceImage == null ||
        effectPreviewModel.proxyImage == null ||
        effectPreviewModel.erasePath == null ||
        effectPreviewModel.bounds == null) {
      return null;
    }

    return _SelectionEffectPreviewState(
      effect: effectPreviewModel.effect!,
      sourceImage: fullResolution ? effectPreviewModel.sourceImage! : effectPreviewModel.proxyImage!,
      pixelScale: fullResolution ? AppEffects.defaultPixelScale : effectPreviewModel.proxyScale,
      selectionPath: Path.from(effectPreviewModel.erasePath!),
      bounds: effectPreviewModel.bounds!,
      strength: effectPreviewModel.strength,
      size: effectPreviewModel.size,
      coversEntireLayer: effectPreviewModel.coversEntireLayer,
    );
  }

  /// Updates one or both effect preview controls and re-renders the preview.
  Future<void> _updateEffectPreviewControls({
    double? strength,
    double? size,
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
    ui.Image image, {
    required Path selectionPath,
    required Rect bounds,
    required double pixelScale,
  }) async {
    Path localSelectionPath = selectionPath.shift(
      Offset(-bounds.left, -bounds.top),
    );
    if (pixelScale != AppEffects.defaultPixelScale) {
      localSelectionPath = localSelectionPath.transform(
        (Matrix4.identity()..scaleByDouble(pixelScale, pixelScale, 1.0, 1.0)).storage,
      );
    }

    return renderCanvasImage(
      width: image.width,
      height: image.height,
      draw: (ui.Canvas canvas) {
        canvas.save();
        canvas.clipPath(localSelectionPath, doAntiAlias: true);
        canvas.drawImage(image, Offset.zero, ui.Paint());
        canvas.restore();
      },
    );
  }

  /// Applies the active effect and re-masks it to the original selection.
  Future<ui.Image> _buildMaskedEffectImage(
    _SelectionEffectPreviewState state,
  ) async {
    final ui.Image processedImage = await state.effect.apply(
      state.sourceImage,
      strength: state.strength,
      size: state.size,
      pixelScale: state.pixelScale,
    );

    // A whole-layer effect's mask is the full-canvas rect, so clipping to it is
    // a no-op that would cost another full-resolution texture and render pass.
    if (state.coversEntireLayer) {
      if (identical(processedImage, state.sourceImage)) {
        // Zero-strength no-op: hand back a copy so the caller can take
        // ownership without freeing the retained source.
        return renderCanvasImage(
          width: processedImage.width,
          height: processedImage.height,
          draw: (ui.Canvas canvas) => canvas.drawImage(processedImage, Offset.zero, ui.Paint()),
        );
      }
      return processedImage;
    }

    final ui.Image maskedImage = await _maskEffectImageToSelection(
      processedImage,
      selectionPath: state.selectionPath,
      bounds: state.bounds,
      pixelScale: state.pixelScale,
    );

    // A zero-strength effect returns its source unchanged; disposing that would
    // destroy the preview's retained source image.
    if (!identical(processedImage, state.sourceImage)) {
      processedImage.dispose();
    }

    return maskedImage;
  }

  /// Captures the effect source image, mask path, and bounds for the current
  /// target: the active selection when one is visible, otherwise the whole
  /// active layer (without leaving a lingering select-all region).
  ///
  /// Returns null when the source image could not be produced. Callers own the
  /// returned image and must dispose it.
  Future<({ui.Image image, Path path, Rect bounds, bool coversEntireLayer})?> _captureEffectTarget() async {
    final bool hasSelection = selectorModel.isVisible && selectorModel.path1 != null;

    if (hasSelection) {
      final ui.Image? clippedImage = await createSelectionImage();
      if (clippedImage == null) {
        return null;
      }
      return (
        image: clippedImage,
        path: Path.from(selectorModel.path1!),
        bounds: selectorModel.path1!.getBounds(),
        coversEntireLayer: false,
      );
    }

    final Rect bounds = Offset.zero & layers.size;
    return (
      image: layers.selectedLayer.toImageForStorage(layers.size),
      path: Path()..addRect(bounds),
      bounds: bounds,
      coversEntireLayer: true,
    );
  }

  /// Builds the downscaled image that live preview renders from.
  ///
  /// Returns [source] itself (scale 1.0) when it already fits the preview
  /// budget, so callers must not dispose the result independently.
  Future<({ui.Image image, double scale})> _buildEffectPreviewProxy(ui.Image source) async {
    final int longestSide = source.width > source.height ? source.width : source.height;
    if (longestSide <= AppLimits.effectPreviewMaxDimension) {
      return (image: source, scale: AppEffects.defaultPixelScale);
    }

    final double scale = AppLimits.effectPreviewMaxDimension / longestSide;
    final int proxyWidth = (source.width * scale).round().clamp(AppMath.one, source.width);
    final int proxyHeight = (source.height * scale).round().clamp(AppMath.one, source.height);

    final ui.Image proxy = await renderCanvasImage(
      width: proxyWidth,
      height: proxyHeight,
      draw: (ui.Canvas canvas) {
        canvas.drawImageRect(
          source,
          Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
          Rect.fromLTWH(0, 0, proxyWidth.toDouble(), proxyHeight.toDouble()),
          ui.Paint()..filterQuality = FilterQuality.medium,
        );
      },
    );
    return (image: proxy, scale: scale);
  }

  /// Starts live preview mode for the selected [effect], [strength], and [size].
  ///
  /// Targets the active selection when one is visible; otherwise the effect
  /// applies to the whole active layer. Used by the on-canvas overlay / bottom
  /// sheet flow (the Brush section applies effects by painting them, so it does
  /// not use this preview path).
  Future<void> startEffectPreview(
    SelectionEffect effect, {
    double strength = AppEffects.defaultIntensity,
    double? size,
  }) async {
    if (isSelectedLayerLocked) {
      return;
    }

    final ({ui.Image image, Path path, Rect bounds, bool coversEntireLayer})? target = await _captureEffectTarget();
    if (target == null) {
      return;
    }

    final ({ui.Image image, double scale}) proxy = await _buildEffectPreviewProxy(target.image);

    effectPreviewModel.start(
      selectedEffect: effect,
      selectionImage: target.image,
      selectionProxyImage: proxy.image,
      selectionProxyScale: proxy.scale,
      selectionCoversEntireLayer: target.coversEntireLayer,
      selectionPath: target.path,
      selectionBounds: target.bounds,
      initialStrength: strength,
      initialSize: size ?? effect.defaultSize,
    );

    repaintToolOptions();

    await _renderEffectPreview();
  }

  /// Updates the active preview intensity and re-renders the effect live.
  Future<void> updateEffectPreviewStrength(double strength) async {
    await _updateEffectPreviewControls(strength: strength);
  }

  /// Updates the active preview size and re-renders the effect live.
  Future<void> updateEffectPreviewSize(double size) async {
    await _updateEffectPreviewControls(size: size);
  }

  /// Commits the current effect preview as a single undoable action.
  Future<void> confirmEffectPreview() async {
    final _SelectionEffectPreviewState? state = _currentEffectPreviewState(fullResolution: true);
    if (state == null) {
      return;
    }

    final ui.Image maskedImage = await _buildMaskedEffectImage(state);
    final bool coversEntireLayer = effectPreviewModel.coversEntireLayer;

    effectPreviewModel.clear();
    repaintToolOptions();

    replaceRegion(
      name: state.effect.name,
      erasePath: state.selectionPath,
      replacement: maskedImage,
      offset: Offset(state.bounds.left, state.bounds.top),
      erasesEntireLayer: coversEntireLayer,
    );

    if (coversEntireLayer) {
      _collapseWholeLayerEffectHistory();
    }

    update();
  }

  /// Bounds the cost of repeated whole-layer effects.
  ///
  /// Every such effect pins a full-canvas texture in the action stack and is
  /// replayed on each cache rebuild, so only the current and previous
  /// generations are kept; undo history is trimmed to match what survives.
  void _collapseWholeLayerEffectHistory() {
    undoProvider.trimUndoHistoryWhere(
      predicate: (RecordAction action) =>
          SelectionEffect.values.any((SelectionEffect effect) => effect.name == action.name),
      maxKeep: AppLimits.fullLayerEffectUndoHistory,
    );

    final List<ui.Image> orphaned = layers.selectedLayer.collapseFullyErasedActions();
    layers.disposeCommittedImagesIfUnreferenced(orphaned);
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
      previewImage.dispose();
      return;
    }

    effectPreviewModel.previewImage?.dispose();
    effectPreviewModel.previewImage = previewImage;
    update();
  }

  /// Arms [effect] for painting onto the canvas, cancelling any Apply preview.
  void armEffectBrush(SelectionEffect effect) {
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
  void setEffectBrushStrength(double strength) {
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
    required SelectionEffect effect,
    required double strength,
    required double size,
    required List<Offset> strokePoints,
    required Rect strokeBounds,
    required double brushSize,
    required Path? clipPath,
  }) async {
    if (isSelectedLayerLocked || strokePoints.isEmpty) {
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
    if (identical(processed, layerImage)) {
      // The effect is a no-op at this strength (e.g. a bipolar effect at its
      // centre): apply() returned the source image untouched, so there is
      // nothing to paint. Dispose the single image and bail — disposing it and
      // then drawing it would crash with "non-genuine Image".
      layerImage.dispose();
      return;
    }
    layerImage.dispose();

    final Offset regionOrigin = Offset(left.toDouble(), top.toDouble());
    final Path bandPath = _effectBrushBandPath(strokePoints, regionOrigin, radius);

    // Clip the processed region to the brushed band (and the active selection):
    // clipPath on a fillable path is the same masking idiom the Apply flow uses.
    final ui.Image patch = await renderCanvasImage(
      width: width,
      height: height,
      draw: (ui.Canvas canvas) {
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
  ///
  /// Winding matters: the path is filled with the default non-zero rule, so
  /// every sub-shape must wind the SAME direction or overlaps cancel to a hole.
  /// [Path.addOval] always winds clockwise; the bridging quads must be emitted
  /// in the matching order or the lens where each quad overlaps its end discs
  /// cancels out — carving a gap ring at every joint and breaking a fast /
  /// small-brush stroke (whose sampled points are spaced apart) into a string
  /// of separated beads. So the quad below winds `a-n → b-n → b+n → a+n` to
  /// match the ovals, NOT the geometrically-natural `a+n → b+n → b-n → a-n`.
  Path _effectBrushBandPath(
    List<Offset> strokePoints,
    Offset regionOrigin,
    double radius,
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
      band.addPolygon(<Offset>[a - normal, b - normal, b + normal, a + normal], true);
    }
    return band;
  }
}
