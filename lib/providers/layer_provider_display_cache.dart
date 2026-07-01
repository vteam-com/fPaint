part of 'layer_provider.dart';

/// Display-resolution projection cache for [LayerProvider].
///
/// The on-screen canvas is shown far smaller than its native size (a 62 MP
/// canvas fits a viewport at ~15%). Sampling the full-res `_cachedImage` every
/// frame — and rebuilding it per edit — is the dominant cost on large canvases.
/// The `_displayCache` (a field on [LayerProvider]) is a downscaled copy of the
/// layer's committed content at roughly the on-screen resolution; the live
/// painter draws it (a small blit) instead of the full-res cache. Full
/// resolution is materialized only on demand (export/transform/sampling) via
/// [LayerProvider.renderLayer]/`renderImageWH`, which never touch this cache.
/// This is the Flutter analog of Krita's "Instant Preview" / Level-of-Detail
/// projection.
extension LayerDisplayCache on LayerProvider {
  /// Upper bound on the display cache's longest side (px), capping memory/GPU cost
  /// regardless of zoom (~viewport sized). Beyond this the on-screen image is a
  /// touch soft when zoomed in — the same tradeoff as Krita's Instant Preview.
  static const int _displayCacheMaxSide = 2560;

  /// Slack so a cache built for the current zoom isn't treated as stale by
  /// floating-point drift.
  static const double _displayScaleEpsilon = 0.02;

  /// The achievable display-cache scale for [requiredScale]: never upscales past
  /// native (1.0) and never exceeds the [_displayCacheMaxSide] budget. Both the
  /// sufficiency check and the builder use this so they agree — otherwise a
  /// requiredScale above the achievable cap (high DPR / zoomed in) would look
  /// perpetually "insufficient" and rebuild every frame forever.
  double _targetDisplayScale(final double requiredScale) {
    double scale = requiredScale.clamp(_displayScaleEpsilon, AppMath.one.toDouble());
    final int longestSide = max(size.width.toInt(), size.height.toInt());
    if (longestSide > AppMath.zero && longestSide * scale > _displayCacheMaxSide) {
      scale = _displayCacheMaxSide / longestSide;
    }
    return scale;
  }

  /// Whether the current display cache is sharp enough for [requiredScale].
  bool _displayCacheSufficientFor(final double requiredScale) =>
      _displayCache != null && _displayCacheScale + _displayScaleEpsilon >= _targetDisplayScale(requiredScale);

  /// Whether this layer contains a text action.
  ///
  /// Text layers are excluded from the display-resolution projection: glyphs
  /// must be rasterized through the live paint pass (where the font glyph atlas
  /// is resident), not baked into a downscaled cache built off the main paint —
  /// otherwise the projection can render text as empty boxes. Text is cheap to
  /// re-render full-res, so bypassing the cache for it costs nothing meaningful.
  bool get _hasTextContent => actionStack.any((final UserActionDrawing a) => a.action == ActionType.text);

  /// Draws the layer for on-screen display at [requiredScale].
  ///
  /// When a sufficient display-resolution cache exists it is drawn scaled (the
  /// cheap path); otherwise the layer is rendered full-res now and
  /// [requestRebuild] is invoked to (re)build the cache for later frames. The
  /// cache is bypassed while the layer is mid-stroke or cannot be incrementally
  /// composited, so live edits always paint from the authoritative content.
  ///
  /// Only default (opacity 1, srcOver) layers use the cache: baking a non-trivial
  /// opacity/blend into a standalone image and re-applying it at draw time would
  /// double it, so non-default layers render full-res (correct, and uncommon).
  void renderLayerForDisplay(
    final Canvas canvas,
    final double requiredScale,
    final void Function() requestRebuild,
  ) {
    final bool cacheEligible =
        _livePreviewBaseline == null &&
        !isUserDrawing &&
        _strokeBaseline == null &&
        supportsIncrementalPixelBrushCache &&
        !_hasTextContent;

    final ui.Image? cache = _displayCache;
    if (cacheEligible && cache != null && _displayCacheSufficientFor(requiredScale)) {
      final Paint paint = Paint()
        ..color = AppColors.black.withAlpha((AppLimits.rgbChannelMax * opacity).toInt())
        ..blendMode = blendMode
        ..filterQuality = FilterQuality.medium;
      canvas.drawImageRect(
        cache,
        Rect.fromLTWH(0, 0, cache.width.toDouble(), cache.height.toDouble()),
        Rect.fromLTWH(0, 0, size.width, size.height),
        paint,
      );
      return;
    }

    // No usable cache (missing, stale, or zoomed in past its resolution): draw
    // full-res now and schedule a (re)build for subsequent frames.
    renderLayer(canvas);
    if (cacheEligible) {
      requestRebuild();
    }
  }

  /// (Re)builds the display cache at the achievable scale for [requiredScale].
  /// Samples the full-res content once; cheap to draw thereafter. No-op if
  /// already sufficient or a build is already in flight.
  Future<void> buildDisplayCache(final double requiredScale) async {
    if (_displayCacheBuilding || !supportsIncrementalPixelBrushCache) {
      return;
    }
    if (_displayCacheSufficientFor(requiredScale)) {
      return;
    }
    final int canvasWidth = size.width.toInt();
    final int canvasHeight = size.height.toInt();
    if (canvasWidth <= AppMath.zero || canvasHeight <= AppMath.zero) {
      return;
    }
    final double scale = _targetDisplayScale(requiredScale);
    final int targetWidth = max(AppMath.one, (canvasWidth * scale).round());
    final int targetHeight = max(AppMath.one, (canvasHeight * scale).round());

    _displayCacheBuilding = true;
    try {
      final ui.Image built = await renderCanvasImage(
        width: targetWidth,
        height: targetHeight,
        draw: (final ui.Canvas canvas) {
          canvas.scale(targetWidth / size.width, targetHeight / size.height);
          renderLayer(canvas);
        },
      );
      _displayCache?.dispose();
      _displayCache = built;
      _displayCacheScale = targetWidth / size.width;
    } finally {
      _displayCacheBuilding = false;
    }
  }

  /// Incrementally folds a committed pixel-brush [patchImage] (full-res, covering
  /// [patchBounds]) into the display cache by drawing it scaled — the display-res
  /// analog of the committed cut+image actions. Cheap (all display-res). No-op
  /// when there is no cache yet; the painter will build a fresh one that already
  /// includes the newly-appended action.
  Future<void> updateDisplayCacheWithPatch({
    required final ui.Image patchImage,
    required final Rect patchBounds,
  }) async {
    final ui.Image? base = _displayCache;
    if (base == null || !supportsIncrementalPixelBrushCache) {
      return;
    }
    final double scale = _displayCacheScale;
    // Snap the scaled region to whole display-cache pixels. The erase
    // ([renderRegionErase], anti-aliased `BlendMode.clear`) and the patch redraw
    // are both edge-anti-aliased; on a *fractional* rect the clear feathers a
    // hair wider than the redraw covers, leaving a ~1px transparent ring the
    // canvas backdrop shows through — a visible white rectangle around the
    // stroke. Integer edges land on pixel boundaries, so both ops cover exactly
    // the same pixels and the seam disappears.
    final Rect scaledBounds = Rect.fromLTRB(
      (patchBounds.left * scale).floorToDouble().clamp(AppMath.zero.toDouble(), base.width.toDouble()),
      (patchBounds.top * scale).floorToDouble().clamp(AppMath.zero.toDouble(), base.height.toDouble()),
      (patchBounds.right * scale).ceilToDouble().clamp(AppMath.zero.toDouble(), base.width.toDouble()),
      (patchBounds.bottom * scale).ceilToDouble().clamp(AppMath.zero.toDouble(), base.height.toDouble()),
    );
    final ui.Image next = await renderCanvasImage(
      width: base.width,
      height: base.height,
      draw: (final ui.Canvas canvas) {
        canvas.drawImage(base, Offset.zero, Paint());
        renderRegionErase(canvas, Path()..addRect(scaledBounds));
        canvas.drawImageRect(
          patchImage,
          Rect.fromLTWH(0, 0, patchImage.width.toDouble(), patchImage.height.toDouble()),
          scaledBounds,
          Paint()..filterQuality = FilterQuality.medium,
        );
      },
    );
    // Guard: the cache may have been invalidated/replaced while awaiting.
    if (!identical(_displayCache, base)) {
      next.dispose();
      return;
    }
    _displayCache = next;
    base.dispose();
  }

  /// Drops the display-res projection (its content changed and must be rebuilt).
  void invalidateDisplayCache() {
    _displayCache?.dispose();
    _displayCache = null;
    _displayCacheScale = 0.0;
  }

  /// Drops the full-res render cache without scheduling a thumbnail rebuild.
  ///
  /// Used by the pixel-brush commit: the committed action is appended to the
  /// stack (so on-demand full-res consumers replay it correctly), the live
  /// display is served by the display cache, and the full-res cache is rebuilt
  /// lazily only when something actually needs full resolution.
  void invalidateFullResCache() {
    _cachedImage?.dispose();
    _cachedImage = null;
  }

  /// Whether this layer can use the display-resolution projection cache.
  ///
  /// The display cache stores *raw* layer content (opacity/blend applied when
  /// it's drawn). That only equals a full render when the layer's group composite
  /// is an identity — otherwise a non-trivial opacity/blend would be applied
  /// twice. Non-default layers therefore render full-res for display (correct,
  /// and uncommon).
  bool get supportsIncrementalPixelBrushCache => opacity == AppMath.one.toDouble() && blendMode == ui.BlendMode.srcOver;

  /// Ensures the per-layer full-res render cache is populated so compositing is
  /// fast.
  ///
  /// When `_cachedImage` is already set this is a no-op. Otherwise the layer is
  /// rendered once and the result cached, so subsequent [renderLayer] calls take
  /// the fast [Canvas.drawImage] path rather than replaying the full action stack.
  Future<void> ensureCachePrimed() async {
    if (_cachedImage != null) {
      return;
    }
    _cachedImage = await renderCanvasImage(
      width: size.width.toInt(),
      height: size.height.toInt(),
      draw: renderLayer,
    );
  }

  /// Builds the layer-panel thumbnail (~[AppLayout.thumbnailMaxHeight] px tall)
  /// by downscaling [source] directly into a tiny render target with a cheap
  /// bilinear filter.
  ///
  /// The old path rendered the full canvas and then ran a `FilterQuality.high`
  /// resize of the multi-megapixel image — both multi-hundred-ms on large
  /// canvases, and a whole burst of them (one per layer) would saturate the
  /// raster thread and stall unrelated GPU work (e.g. a smudge commit's texture
  /// upload). A medium-quality downscale into a 64 px target is perceptually
  /// identical at thumbnail size and an order of magnitude cheaper.
  Future<ui.Image> _renderThumbnailFromImage(final ui.Image source) {
    final Size thumbnailSize = scaleSizeTo(size, maxHeight: AppLayout.thumbnailMaxHeight);
    final int thumbnailWidth = max(AppMath.one, thumbnailSize.width.round());
    final int thumbnailHeight = max(AppMath.one, thumbnailSize.height.round());
    return renderCanvasImage(
      width: thumbnailWidth,
      height: thumbnailHeight,
      draw: (final ui.Canvas canvas) {
        canvas.drawImageRect(
          source,
          Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
          Rect.fromLTWH(0, 0, thumbnailWidth.toDouble(), thumbnailHeight.toDouble()),
          Paint()..filterQuality = FilterQuality.medium,
        );
      },
    );
  }

  /// Refreshes the layers-panel thumbnail from the display-resolution cache
  /// (cheap — it's already tiny), debounced and off the commit hot path.
  ///
  /// Disposes the previous thumbnail only once the replacement is ready (see
  /// [clearCache] for why an eager dispose triggers the "non-genuine Image"
  /// flood). No-op until a display cache exists.
  void refreshThumbnailFromDisplayCache() {
    _debounceTimer.run(() async {
      final ui.Image? source = _displayCache;
      if (source == null) {
        return;
      }
      final ui.Image thumbnail = await _renderThumbnailFromImage(source);
      _cachedThumbnailImage?.dispose();
      _cachedThumbnailImage = thumbnail;
      _cacheTopColorsUsed();
      onThumbnailChanged();
      update();
    });
  }
}
