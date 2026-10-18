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
  /// Whether an on-screen projection is currently available.
  bool get hasDisplayCache => _displayCache != null;

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
  double _targetDisplayScale(double requiredScale) {
    double scale = requiredScale.clamp(_displayScaleEpsilon, AppMath.one.toDouble());
    final int longestSide = max(size.width.toInt(), size.height.toInt());
    if (longestSide > AppMath.zero && longestSide * scale > _displayCacheMaxSide) {
      scale = _displayCacheMaxSide / longestSide;
    }
    return scale;
  }

  /// The paint that composites this layer's raw content onto the layers below
  /// it, carrying the layer opacity and blend mode.
  ///
  /// Every raster cache ([_cachedImage], the display projection, stroke
  /// baselines) holds raw content, so this is applied exactly once, when the
  /// layer is composited.
  Paint compositePaint() => Paint()
    ..color = AppColors.black.withAlpha((AppLimits.rgbChannelMax * opacity).toInt())
    ..blendMode = blendMode;

  /// The scale [_displayCache] was rendered at, or 0 when there is none.
  double get displayCacheScale => _displayCacheScale;

  /// Composites the display cache (stretched to the layer's canvas-space
  /// bounds, opacity/blend applied) onto [canvas]. Returns false, drawing
  /// nothing, when there is no cache.
  bool drawDisplayCache(Canvas canvas, {required FilterQuality filterQuality}) {
    final ui.Image? cache = _displayCache;
    if (cache == null) {
      return false;
    }
    canvas.drawImageRect(
      cache,
      Rect.fromLTWH(0, 0, cache.width.toDouble(), cache.height.toDouble()),
      Offset.zero & size,
      compositePaint()..filterQuality = filterQuality,
    );
    return true;
  }

  /// Whether the current display cache is sharp enough for [requiredScale].
  bool _displayCacheSufficientFor(double requiredScale) =>
      _displayCache != null && _displayCacheScale + _displayScaleEpsilon >= _targetDisplayScale(requiredScale);

  /// Whether this layer contains a text action.
  ///
  /// Text layers are excluded from the display-resolution projection: glyphs
  /// must be rasterized through the live paint pass (where the font glyph atlas
  /// is resident), not baked into a downscaled cache built off the main paint —
  /// otherwise the projection can render text as empty boxes. Text is cheap to
  /// re-render full-res, so bypassing the cache for it costs nothing meaningful.
  bool get _hasTextContent => actionStack.any((UserActionDrawing a) => a.action == ActionType.text);

  /// Draws the layer for on-screen display at [requiredScale].
  ///
  /// When a display-resolution cache exists it is drawn scaled immediately. If
  /// it is too soft for the current zoom, [requestRebuild] sharpens it in the
  /// background while the existing projection remains visible. Only a missing
  /// Draws this layer into an untransformed viewport canvas.
  void renderLayerForViewportDisplay(
    Canvas canvas,
    double requiredScale,
    void Function() requestRebuild, {
    required Rect viewportBounds,
    required ViewportTransform viewport,
    required Rect visibleCanvasBounds,
    required FilterQuality filterQuality,
  }) {
    // A finished stroke still folding into the projection keeps showing its
    // baseline + stroke, rather than replaying the whole history meanwhile.
    if (_strokeFold != null && _strokeBaselineDisplay != null) {
      canvas.saveLayer(viewportBounds, compositePaint());
      canvas.transform(viewport.matrix.storage);
      canvas.clipRect(visibleCanvasBounds, doAntiAlias: false);
      _renderStrokeBaselineAndTail(canvas);
      canvas.restore();
      return;
    }

    final bool cacheEligible =
        _livePreviewBaseline == null && !isUserDrawing && _strokeBaseline == null && !_hasTextContent;
    if (cacheEligible && _displayCache != null) {
      canvas.save();
      // Rotation enters here, at composite time. The cache itself stays in
      // unrotated canvas space, so a rotate gesture never invalidates it.
      canvas.transform(viewport.matrix.storage);
      canvas.clipRect(visibleCanvasBounds, doAntiAlias: false);
      drawDisplayCache(canvas, filterQuality: filterQuality);
      canvas.restore();
      if (!_displayCacheSufficientFor(requiredScale)) {
        requestRebuild();
      }
      return;
    }

    renderLayerInViewport(
      canvas,
      viewportBounds: viewportBounds,
      viewport: viewport,
      visibleCanvasBounds: visibleCanvasBounds,
    );
    if (cacheEligible) {
      requestRebuild();
    }
  }

  /// (Re)builds the display cache at the achievable scale for [requiredScale].
  /// Samples the full-res content once; cheap to draw thereafter. No-op if
  /// already sufficient or a build is already in flight.
  Future<bool> buildDisplayCache(double requiredScale) async {
    if (_displayCacheBuilding) {
      return false;
    }
    if (_displayCacheSufficientFor(requiredScale)) {
      return false;
    }
    final int canvasWidth = size.width.toInt();
    final int canvasHeight = size.height.toInt();
    if (canvasWidth <= AppMath.zero || canvasHeight <= AppMath.zero) {
      return false;
    }
    final double scale = _targetDisplayScale(requiredScale);
    final int targetWidth = max(AppMath.one, (canvasWidth * scale).round());
    final int targetHeight = max(AppMath.one, (canvasHeight * scale).round());

    _displayCacheBuilding = true;
    final int revision = _displayCacheRevision;
    final ui.Image built;
    try {
      built = await renderCanvasImage(
        width: targetWidth,
        height: targetHeight,
        draw: (ui.Canvas canvas) {
          canvas.scale(targetWidth / size.width, targetHeight / size.height);
          // Raw content: opacity/blend are applied when the cache is drawn.
          _renderLayerContents(canvas);
        },
      );
    } finally {
      _displayCacheBuilding = false;
    }
    // The content changed while rendering (e.g. a file load appended the
    // layer's image after the painter started building the empty layer).
    // Installing it would pin the stale pixels until the next edit, so drop it
    // and build again from the current content.
    if (revision != _displayCacheRevision) {
      built.dispose();
      return buildDisplayCache(requiredScale);
    }
    _displayCache?.dispose();
    _displayCache = built;
    _displayCacheScale = targetWidth / size.width;
    return true;
  }

  /// Incrementally folds a committed pixel-brush [patchImage] (full-res, covering
  /// [patchBounds]) into the display cache by drawing it scaled — the display-res
  /// analog of the committed cut+image actions. Cheap (all display-res). No-op
  /// when there is no cache yet; the painter will build a fresh one that already
  /// includes the newly-appended action.
  Future<void> updateDisplayCacheWithPatch({
    required ui.Image patchImage,
    required Rect patchBounds,
  }) async {
    final ui.Image? base = _displayCache;
    if (base == null) {
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
      draw: (ui.Canvas canvas) {
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
    // A build already in flight may predate this patch; make it start over.
    _displayCacheRevision++;
    base.dispose();
  }

  /// Drops the display-res projection (its content changed and must be rebuilt).
  void invalidateDisplayCache() {
    _displayCacheRevision++;
    _displayCache?.dispose();
    _displayCache = null;
    _displayCacheScale = 0.0;
    onDisplayInvalidated?.call();
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

  /// Ensures the per-layer full-res render cache is populated so compositing is
  /// fast.
  ///
  /// When `_cachedImage` is already set this is a no-op. Otherwise the layer is
  /// rendered once and the result cached, so subsequent [renderLayer] calls take
  /// the fast [Canvas.drawImage] path rather than replaying the full action stack.
  ///
  /// Past [AppLimits.fullResolutionCacheMaxPixels] nothing is primed, matching
  /// [updateThumbnail]: a large canvas deliberately keeps no full-res cache per
  /// layer, and priming every visible layer (composite capture, thumbnails,
  /// cross-layer lifts) held gigabytes and crashed iPad on memory.
  Future<void> ensureCachePrimed() async {
    if (_cachedImage != null || _exceedsFullResBudget) {
      return;
    }
    _cachedImage = await _renderFullResContents();
  }

  /// Whether the canvas is past [AppLimits.fullResolutionCacheMaxPixels], where
  /// no per-layer full-res cache is kept (see [updateThumbnail]).
  bool get _exceedsFullResBudget => size.width * size.height > AppLimits.fullResolutionCacheMaxPixels;

  /// Renders the layer's raw contents at full canvas resolution.
  Future<ui.Image> _renderFullResContents() {
    return renderCanvasImage(
      width: size.width.toInt(),
      height: size.height.toInt(),
      draw: _renderLayerContents,
    );
  }

  /// Installs [thumbnail] as the panel thumbnail and refreshes the palette.
  ///
  /// Disposes the previous thumbnail and assigns the replacement in one
  /// synchronous step, so no frame can observe a freed texture.
  void _installThumbnail(ui.Image thumbnail) {
    _cachedThumbnailImage?.dispose();
    _cachedThumbnailImage = thumbnail;
    _cacheTopColorsUsed();
  }

  /// The panel thumbnail's pixel size: the canvas scaled to
  /// [AppLayout.thumbnailMaxHeight], at least one pixel on each axis.
  ({int width, int height}) get _thumbnailPixelSize {
    final Size thumbnailSize = scaleSizeTo(size, maxHeight: AppLayout.thumbnailMaxHeight);
    return (
      width: max(AppMath.one, thumbnailSize.width.round()),
      height: max(AppMath.one, thumbnailSize.height.round()),
    );
  }

  /// Rebuilds the layer's raster cache and panel thumbnail.
  ///
  /// A full-resolution cache costs width*height*4 bytes and an equally large
  /// render target to build. Past [AppLimits.fullResolutionCacheMaxPixels] that
  /// allocation is what Impeller fails on ("could not create a complete
  /// framebuffer"), so large canvases render the thumbnail directly and let the
  /// display-resolution projection serve on-screen drawing instead.
  Future<void> updateThumbnail() async {
    final bool thumbnailWanted = isThumbnailVisible?.call() ?? true;

    if (_exceedsFullResBudget) {
      // The thumbnail is the only product here, so a hidden panel means there
      // is no work worth doing at all.
      if (!thumbnailWanted) {
        thumbnailNeedsRebuild = true;
        return;
      }
      final ui.Image thumbnail = await renderThumbnailDirect();
      _installThumbnail(thumbnail);
      thumbnailNeedsRebuild = false;
      onThumbnailChanged();
      return;
    }

    // The full-resolution raster also feeds renderLayer's fast path, so it is
    // still built when the panel is hidden; only the thumbnail is deferred.
    final ui.Image fullImage = await _renderFullResContents();
    // Dispose old textures before replacing; ui.Images are not GC-freed.
    _cachedImage?.dispose();
    _cachedImage = fullImage;

    if (thumbnailWanted) {
      final ui.Image thumbnail = await _renderThumbnailFromImage(fullImage);
      _installThumbnail(thumbnail);
      thumbnailNeedsRebuild = false;
    } else {
      thumbnailNeedsRebuild = true;
    }
    onThumbnailChanged();
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
  Future<ui.Image> _renderThumbnailFromImage(ui.Image source) {
    final ({int width, int height}) pixelSize = _thumbnailPixelSize;
    final int thumbnailWidth = pixelSize.width;
    final int thumbnailHeight = pixelSize.height;
    return renderCanvasImage(
      width: thumbnailWidth,
      height: thumbnailHeight,
      draw: (ui.Canvas canvas) {
        canvas.drawImageRect(
          source,
          Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
          Rect.fromLTWH(0, 0, thumbnailWidth.toDouble(), thumbnailHeight.toDouble()),
          // [source] is raw content; apply opacity/blend like the direct path.
          compositePaint()..filterQuality = FilterQuality.medium,
        );
      },
    );
  }

  /// Renders the layer-panel thumbnail straight into its final tiny target.
  /// Unlike [_renderThumbnailFromImage] this never materializes a
  /// full-resolution intermediate, so its cost is independent of canvas size.
  Future<ui.Image> renderThumbnailDirect() {
    final ({int width, int height}) pixelSize = _thumbnailPixelSize;
    final int thumbnailWidth = pixelSize.width;
    final int thumbnailHeight = pixelSize.height;
    return renderCanvasImage(
      width: thumbnailWidth,
      height: thumbnailHeight,
      draw: (ui.Canvas canvas) {
        canvas.scale(thumbnailWidth / size.width, thumbnailHeight / size.height);
        renderLayer(canvas, compositeBounds: Offset.zero & size);
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
      _installThumbnail(thumbnail);
      onThumbnailChanged();
      update();
    });
  }
}
