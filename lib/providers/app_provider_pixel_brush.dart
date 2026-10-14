part of 'app_provider.dart';

/// Pixel-brush (smudge/blur) and paint-mode effect stroke lifecycle: start,
/// extend, cancel, and the one-shot commit pipeline. State lives in
/// [PixelBrushStrokeSession] ([AppProvider.pixelBrushSession]); the gesture
/// widget only routes pointer events here — the same shape as
/// [commitEffectBrushStroke], which this extension calls for effect strokes.
extension AppProviderPixelBrush on AppProvider {
  /// Starts tracking a pixel-brush stroke from [position] with the given [mode].
  ///
  /// Lightweight: it captures only the undo restore-state, the clip path, and the
  /// first point, then publishes the gesture marquee. No source readback, worker,
  /// or live rasterization happens during the drag — the whole effect is rendered
  /// once in [commitPixelBrushGesture] on pointer-up. This keeps the drag O(1) at
  /// any canvas size.
  void startPixelBrushStroke(Offset position, PixelBrushMode mode) {
    // A prior stroke whose pointer-up was cancelled or arrived with a mismatched
    // pointer id never ran cancelPixelBrushStroke; reclaim its state first.
    if (pixelBrushSession.layerRestoreState != null) {
      pixelBrushSession.clearStroke();
    }
    pixelBrushSession.generation++;
    pixelBrushSession.mode = mode;
    pixelBrushSession.intensity = brushIntensity;
    pixelBrushSession.layerRestoreState = _captureSelectedLayerRestoreState();
    pixelBrushSession.clipPath = selectorModel.copyActiveClipPath();
    pixelBrushSession.patchBounds = null;
    extendPixelBrushStroke(position);
  }

  /// Starts a paint-mode effect stroke. Reuses the pixel-brush gesture capture
  /// (points, bounds, marquee); the armed Adjust effect is committed on
  /// pointer-up by [commitPixelBrushGesture].
  void startEffectBrushStroke(Offset position) {
    pixelBrushSession.clearStroke();
    pixelBrushSession.isEffectBrushStroke = true;
    pixelBrushSession.clipPath = selectorModel.copyActiveClipPath();
    extendPixelBrushStroke(position);
  }

  /// Extends the active gesture with [position] and redraws the swept-band
  /// marquee. No live rasterization: the smudge/blur is rendered once on
  /// pointer-up, so the drag stays responsive at any canvas size.
  void extendPixelBrushStroke(Offset position) {
    pixelBrushSession.appendPoint(position, brushSize);
    showPixelBrushGesture(
      points: pixelBrushSession.strokePoints,
      size: brushSize,
    );
  }

  /// Abandons the in-progress gesture, invalidating any in-flight commit render.
  void cancelPixelBrushStroke() {
    pixelBrushSession.clearStroke();
  }

  /// Commits the active gesture: the armed Adjust effect for an effect-brush
  /// stroke, otherwise the smudge/blur one-shot render.
  Future<void> commitPixelBrushGesture() async {
    if (pixelBrushSession.isEffectBrushStroke) {
      await _commitArmedEffectBrushStroke();
    } else {
      await _commitPixelBrushStroke();
    }
  }

  /// Commits the active paint-mode effect stroke through
  /// [commitEffectBrushStroke].
  Future<void> _commitArmedEffectBrushStroke() async {
    final ui.Rect? patchBounds = pixelBrushSession.patchBounds;
    final SelectionEffect? effect = effectBrushModel.effect;
    if (patchBounds == null || effect == null || pixelBrushSession.strokePoints.length < AppMath.one) {
      return;
    }
    await commitEffectBrushStroke(
      effect: effect,
      strength: effectBrushModel.strength,
      size: effectBrushModel.size,
      strokePoints: List<ui.Offset>.of(pixelBrushSession.strokePoints),
      strokeBounds: patchBounds,
      brushSize: brushSize,
      clipPath: pixelBrushSession.clipPath,
    );
  }

  /// Renders the whole smudge/blur stroke in one pass and commits it as an
  /// undoable image action.
  ///
  /// The GPU→CPU readback of the composite backdrop is a fixed multi-second
  /// stall on this renderer, so it is done **once per session, not per stroke**:
  /// the session caches the composite pixels, each stroke crops its region from
  /// that cache (a CPU copy, no readback), and after committing we blit the
  /// result region back into the cache so it stays current. The cache is
  /// re-read only when [_currentSmudgeSignature] shows the composite changed
  /// (another edit, layer switch, undo).
  ///
  /// The in-progress generation is re-checked across each await so a stroke
  /// started mid-render is dropped rather than corrupting layer state.
  Future<void> _commitPixelBrushStroke() async {
    final PixelBrushStrokeSession session = pixelBrushSession;
    final ImagePlacementLayerRestoreState? layerRestoreState = session.layerRestoreState;
    final ui.Rect? patchBounds = session.patchBounds;
    if (layerRestoreState == null || patchBounds == null || session.strokePoints.length < AppMath.one) {
      return;
    }

    final int generation = session.generation;
    final PixelBrushMode mode = session.mode;
    final double intensity = session.intensity;
    final double strokeBrushSize = brushSize;
    final ui.Path? clipPath = session.clipPath;
    final List<Offset> strokePoints = List<Offset>.of(session.strokePoints);
    final int selectedLayerIndex = layers.selectedLayerIndex;
    final ui.Size canvasSize = layers.size;

    final double radius = resolvePixelBrushRadius(strokeBrushSize);

    // Region to process: the footprint inflated by one radius (so every source
    // pixel a dab samples is inside it), integer-aligned and clamped.
    final ui.Rect? cropRect = inflateClampToCanvas(patchBounds, radius, canvasSize);
    if (cropRect == null) {
      return;
    }
    final int cropLeft = cropRect.left.toInt();
    final int cropTop = cropRect.top.toInt();
    final int cropRight = cropRect.right.toInt();
    final int cropBottom = cropRect.bottom.toInt();
    final int cropWidth = cropRight - cropLeft;
    final int cropHeight = cropBottom - cropTop;

    // Ensure the source cache covers this stroke's crop. The cache holds only a
    // region of the composite (not the whole 62 MP canvas), so a cold/invalidated
    // cache — or a stroke reaching outside the cached region — reads back just the
    // padded stroke region, not the full canvas.
    final List<int> signature = _currentSmudgeSignature();
    final bool cacheValid = session.isSourceCacheValidFor(
      signature: signature,
      cropLeft: cropLeft,
      cropTop: cropTop,
      cropRight: cropRight,
      cropBottom: cropBottom,
    );
    if (!cacheValid) {
      // The crop is non-empty, so its margin-inflated region is too.
      final ui.Rect regionRect =
          inflateClampToCanvas(
            cropRect,
            AppInteraction.smudgeSourceCacheMargin.roundToDouble(),
            canvasSize,
          ) ??
          cropRect;
      final int regionLeft = regionRect.left.toInt();
      final int regionTop = regionRect.top.toInt();
      final int regionWidth = regionRect.width.toInt();
      final int regionHeight = regionRect.height.toInt();

      // Sample only the SELECTED layer (colour + alpha), not the composite
      // through it. Smudge/blur then affect just this layer — preserving its
      // transparency and not pulling an opaque backdrop's colour into the smear
      // (which baked white over a white background and darkened a region when a
      // sparse layer sat over an opaque one). Standard "sample active layer".
      final ui.Image layerSource = await layers.captureLayerRegion(selectedLayerIndex, regionRect);
      if (generation != session.generation) {
        layerSource.dispose();
        return;
      }
      final Uint8List? layerBytes = await extractImagePixels(layerSource, format: ui.ImageByteFormat.rawStraightRgba);
      layerSource.dispose();
      if (layerBytes == null || generation != session.generation) {
        return;
      }
      session.storeSourceCache(
        bytes: layerBytes,
        regionLeft: regionLeft,
        regionTop: regionTop,
        regionWidth: regionWidth,
        regionHeight: regionHeight,
      );
    }
    final Uint8List sourceBytes = session.sourceBytes!;
    final int regionLeft = session.sourceRegionLeft;
    final int regionTop = session.sourceRegionTop;
    final int regionStride = session.sourceWidth;

    // Crop the stroke's region out of the cached region bytes (region-local
    // coordinates) and build the region-local clip mask if a selection is active.
    final Uint8List regionBytes = copyRgbaRect(
      pixels: sourceBytes,
      imageWidth: regionStride,
      left: cropLeft - regionLeft,
      top: cropTop - regionTop,
      width: cropWidth,
      height: cropHeight,
    );
    final Uint8List? clipMask = clipPath == null
        ? null
        : await createPixelBrushClipMask(
            width: cropWidth,
            height: cropHeight,
            clipPath: clipPath.shift(Offset(-cropLeft.toDouble(), -cropTop.toDouble())),
          );
    if (generation != session.generation) {
      return;
    }

    // Rasterize the whole stroke at full resolution, region-local (isolate).
    final List<Offset> localPoints = <Offset>[
      for (final Offset point in strokePoints) Offset(point.dx - cropLeft, point.dy - cropTop),
    ];
    final PixelBrushSegmentResult? result = await rasterizePixelBrushSegment(
      livePixels: regionBytes,
      imageWidth: cropWidth,
      imageHeight: cropHeight,
      segmentPoints: localPoints,
      brushSize: strokeBrushSize,
      intensity: intensity,
      mode: mode,
      clipMask: clipMask,
      preferSynchronous: false,
    );
    if (result == null || generation != session.generation) {
      return;
    }

    // Build the committed patch image at full resolution (stored in the undoable
    // action for export). A large footprint is downsampled before the CPU→GPU
    // upload and GPU-upscaled back — smudge/blur are soft enough that the loss is
    // invisible. The live display is served by the layer's display cache, updated
    // below; this full-res patch is only materialized for on-demand full-res use.
    final ui.Rect? footprintRect = inflateClampToCanvas(patchBounds, AppMath.zero.toDouble(), canvasSize);
    if (footprintRect == null) {
      return;
    }
    final int fpLeft = footprintRect.left.toInt();
    final int fpTop = footprintRect.top.toInt();
    final int fpWidth = footprintRect.width.toInt();
    final int fpHeight = footprintRect.height.toInt();
    final Uint8List footprintBytes = copyRgbaRect(
      pixels: result.pixels,
      imageWidth: cropWidth,
      left: fpLeft - cropLeft,
      top: fpTop - cropTop,
      width: fpWidth,
      height: fpHeight,
    );
    final int patchDownsample = (radius / AppInteraction.smudgeCommitDownsampleRadiusPerLevel).ceil().clamp(
      AppMath.one,
      AppInteraction.smudgeCommitMaxDownsample,
    );
    // The pipeline works in straight (un-premultiplied) RGBA — the format the
    // source was read back in and the format the CPU step math expects — but
    // [imageFromPixelsDecode] uploads as `ui.PixelFormat.rgba8888`, which is
    // defined as PREMULTIPLIED. Handing it straight bytes makes the engine
    // divide the colour by alpha a second time, blowing every partially
    // transparent pixel toward white (a 50% mid grey arrives as 50% white).
    // That is exactly the feathered rim of every dab, so the stroke came back
    // with a white edge. Convert at the GPU boundary, the last possible moment.
    final ui.Image patchImage;
    if (patchDownsample <= AppMath.one) {
      patchImage = await imageFromPixelsDecode(premultiplyRgbaInPlace(footprintBytes), fpWidth, fpHeight);
    } else {
      final int lowWidth = max(AppMath.one, fpWidth ~/ patchDownsample);
      final int lowHeight = max(AppMath.one, fpHeight ~/ patchDownsample);
      // Downsample in straight space (alpha-weighted internally), then
      // premultiply the small buffer for upload.
      final Uint8List lowBytes = downsampleRgbaBox(footprintBytes, fpWidth, fpHeight, lowWidth, lowHeight);
      final ui.Image lowImage = await imageFromPixelsDecode(
        premultiplyRgbaInPlace(lowBytes),
        lowWidth,
        lowHeight,
      );
      patchImage = await renderCanvasImage(
        width: fpWidth,
        height: fpHeight,
        draw: (ui.Canvas canvas) {
          canvas.drawImageRect(
            lowImage,
            ui.Rect.fromLTWH(0, 0, lowWidth.toDouble(), lowHeight.toDouble()),
            ui.Rect.fromLTWH(0, 0, fpWidth.toDouble(), fpHeight.toDouble()),
            ui.Paint()..filterQuality = ui.FilterQuality.medium,
          );
        },
      );
      lowImage.dispose();
    }
    if (generation != session.generation) {
      patchImage.dispose();
      return;
    }

    final ui.Rect committedBounds = footprintRect;

    // Fold the patch into the layer's display-resolution projection (a small,
    // display-res blit) so the commit shows immediately with NO full-canvas GPU
    // work — the fix for the multi-second commit stall. Full resolution is
    // rebuilt lazily on demand (export/sampling) by replaying the appended
    // action; the live canvas never needs it.
    final LayerProvider targetLayer = layers.get(layerRestoreState.layerIndex);
    await targetLayer.updateDisplayCacheWithPatch(
      patchImage: patchImage,
      patchBounds: committedBounds,
    );
    if (generation != session.generation) {
      patchImage.dispose();
      return;
    }

    _applyCommittedPixelBrushPatch(
      mode: mode,
      layerRestoreState: layerRestoreState,
      committedPatch: PixelBrushLayerPatch(
        bounds: committedBounds,
        image: patchImage,
      ),
    );

    // Keep the region cache current: the composite-through-selected now equals
    // the smudged region, so blit it back in (region-local coords, CPU, no
    // readback) and record the post-commit signature so the next nearby stroke
    // is a cache hit.
    session.blitIntoSourceCache(
      region: result.pixels,
      regionWidth: cropWidth,
      regionHeight: cropHeight,
      destLeft: cropLeft - regionLeft,
      destTop: cropTop - regionTop,
    );
    session.setSourceSignature(_currentSmudgeSignature());
  }

  /// A cheap fingerprint of the composite-through-selected-layer state. Changes
  /// when anything that affects the smudge source changes (action counts, layer
  /// visibility/opacity/blend, selection, canvas size) — but NOT on `clearCache`,
  /// so it stays stable across a run of smudge strokes.
  List<int> _currentSmudgeSignature() {
    final int selected = layers.selectedLayerIndex.clamp(AppMath.zero, layers.length - AppMath.one);
    final List<int> signature = <int>[
      selected,
      layers.length,
      layers.size.width.toInt(),
      layers.size.height.toInt(),
    ];
    for (int index = layers.length - AppMath.one; index >= selected; index--) {
      final LayerProvider layer = layers.get(index);
      signature
        ..add(layer.isVisible ? AppMath.one : AppMath.zero)
        ..add((layer.opacity * AppLimits.rgbChannelMax).round())
        ..add(layer.blendMode.index)
        ..add(layer.actionStack.length)
        ..add(layer.redoStack.length);
    }
    return signature;
  }

  /// Commits [committedPatch] to the layer as an undoable pixel-brush action and
  /// trims the undo history.
  ///
  /// The committed patch has already been folded into the layer's
  /// display-resolution projection by the caller, so `forward` only appends the
  /// undoable action, drops the (now-stale) full-res cache — rebuilt lazily on
  /// demand — and refreshes the thumbnail cheaply. No full-canvas GPU work.
  void _applyCommittedPixelBrushPatch({
    required PixelBrushMode mode,
    required ImagePlacementLayerRestoreState layerRestoreState,
    required PixelBrushLayerPatch committedPatch,
  }) {
    // Textures this record can resurrect: the committed patch plus every image
    // its restore-state snapshots reintroduce on undo/redo. Listing them lets
    // the LayersProvider coordinator free them only once the record is dropped
    // (trim/compaction) and nothing else references them — fixing the per-stroke
    // full-canvas texture leak without risking a use-after-free.
    final List<ui.Image> retainedImages = <ui.Image>[
      committedPatch.image,
      ...layerRestoreState.layerState.images,
    ];

    undoProvider.executeAction(
      name: mode.name,
      retainedImages: retainedImages,
      forward: () {
        final LayerProvider targetLayer = layers.get(layerRestoreState.layerIndex);
        layers.selectedLayerIndex = layerRestoreState.layerIndex;
        targetLayer.clearLivePixelBrushPreview();
        // Append without clearing caches (that would schedule a full-canvas
        // thumbnail rebuild); the display projection already reflects this patch.
        applyPixelBrushPatchToLayer(
          restoreState: layerRestoreState,
          targetLayer: targetLayer,
          patch: committedPatch,
          mode: mode,
          retainCache: true,
        );
        // Full-res is now stale but the live display isn't served from it; drop
        // it so any on-demand full-res consumer replays the appended action.
        targetLayer.invalidateFullResCache();
        targetLayer.refreshThumbnailFromDisplayCache();
        compactPixelBrushLayerHistory(
          targetLayer: targetLayer,
          maxGestureCount: AppInteraction.pixelBrushMaxUndoGestures,
        );
        update();
      },
      backward: () {
        final LayerProvider targetLayer = layers.get(layerRestoreState.layerIndex);
        layers.selectedLayerIndex = layerRestoreState.layerIndex;
        targetLayer.restoreFromSnapshot(layerRestoreState.layerState);
        update();
      },
    );

    undoProvider.trimUndoHistoryWhere(
      predicate: (RecordAction action) {
        return action.name == PixelBrushMode.smudge.name || action.name == PixelBrushMode.blur.name;
      },
      maxKeep: AppInteraction.pixelBrushMaxUndoGestures,
    );
  }
}
