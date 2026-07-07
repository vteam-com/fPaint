part of 'canvas_gesture_handler.dart';

/// Pixel-brush (smudge/blur) stroke lifecycle for [_CanvasGestureHandlerState]:
/// point sampling, live preview kicks, commit, and layer-state restore.
extension _CanvasGestureHandlerPixelBrushMethods on _CanvasGestureHandlerState {
  /// Appends a sampled pointer position to the active pixel-brush stroke.
  void _appendPixelBrushPoint(
    final Offset position,
    final double brushSize,
  ) {
    final double spacing = resolvePixelBrushStepSpacing(brushSize);
    if (_pixelBrushStrokePoints.isNotEmpty && (_pixelBrushStrokePoints.last - position).distance < spacing) {
      return;
    }
    _pixelBrushStrokePoints.add(position);

    final double radius = max(
      AppInteraction.smudgeMinimumRadius,
      brushSize * AppInteraction.smudgeBrushRadiusFactor,
    );
    final double padding = (radius.ceil() + AppInteraction.smudgeBoundsPadding).toDouble();
    final ui.Rect pointBounds = ui.Rect.fromLTRB(
      position.dx - padding,
      position.dy - padding,
      position.dx + padding + AppMath.one.toDouble(),
      position.dy + padding + AppMath.one.toDouble(),
    );
    _pixelBrushStrokePatchBounds = _pixelBrushStrokePatchBounds == null
        ? pointBounds
        : _pixelBrushStrokePatchBounds!.expandToInclude(pointBounds);
  }

  /// Clears the in-progress pixel-brush stroke state.
  void _clearPixelBrushStroke() {
    // Bump the generation so any in-flight one-shot commit render is dropped
    // instead of applying to a layer that has moved on.
    _pixelBrushStrokeGeneration++;
    _pixelBrushStrokePoints.clear();
    _pixelBrushLayerRestoreState = null;
    _pixelBrushClipPath = null;
    _pixelBrushStrokePatchBounds = null;
    _effectBrushStroke = false;
  }

  /// Renders the whole smudge/blur stroke in one pass and commits it as an
  /// undoable image action.
  ///
  /// The GPU→CPU readback of the composite backdrop is a fixed multi-second
  /// stall on this renderer, so it is done **once per session, not per stroke**:
  /// [_smudgeSourceBytes] caches the composite pixels, each stroke crops its
  /// region from that cache (a CPU copy, no readback), and after committing we
  /// blit the result region back into the cache so it stays current. The cache is
  /// re-read only when [_currentSmudgeSignature] shows the composite changed
  /// (another edit, layer switch, undo).
  ///
  /// The in-progress generation is re-checked across each await so a stroke
  /// started mid-render is dropped rather than corrupting layer state.
  Future<void> _commitPixelBrushStroke(final AppProvider appProvider) async {
    final ImagePlacementLayerRestoreState? layerRestoreState = _pixelBrushLayerRestoreState;
    final ui.Rect? patchBounds = _pixelBrushStrokePatchBounds;
    if (layerRestoreState == null || patchBounds == null || _pixelBrushStrokePoints.length < AppMath.one) {
      return;
    }

    final int generation = _pixelBrushStrokeGeneration;
    final PixelBrushMode mode = _pixelBrushMode;
    final double intensity = _pixelBrushIntensity;
    final double brushSize = appProvider.brushSize;
    final ui.Path? clipPath = _pixelBrushClipPath;
    final List<Offset> strokePoints = List<Offset>.of(_pixelBrushStrokePoints);
    final int selectedLayerIndex = appProvider.layers.selectedLayerIndex;
    final int canvasWidth = appProvider.layers.size.width.toInt();
    final int canvasHeight = appProvider.layers.size.height.toInt();

    final double radius = max(
      AppInteraction.smudgeMinimumRadius,
      brushSize * AppInteraction.smudgeBrushRadiusFactor,
    );

    // Region to process: the footprint inflated by one radius (so every source
    // pixel a dab samples is inside it), integer-aligned and clamped.
    final int cropLeft = max(AppMath.zero, (patchBounds.left - radius).floor());
    final int cropTop = max(AppMath.zero, (patchBounds.top - radius).floor());
    final int cropRight = min(canvasWidth, (patchBounds.right + radius).ceil());
    final int cropBottom = min(canvasHeight, (patchBounds.bottom + radius).ceil());
    final int cropWidth = cropRight - cropLeft;
    final int cropHeight = cropBottom - cropTop;
    if (cropWidth <= AppMath.zero || cropHeight <= AppMath.zero) {
      return;
    }

    // Ensure the source cache covers this stroke's crop. The cache holds only a
    // region of the composite (not the whole 62 MP canvas), so a cold/invalidated
    // cache — or a stroke reaching outside the cached region — reads back just the
    // padded stroke region, not the full canvas.
    final List<int> signature = _currentSmudgeSignature(appProvider);
    final bool cacheValid =
        _smudgeSourceBytes != null &&
        _intListEquals(_smudgeSourceSignature, signature) &&
        cropLeft >= _smudgeSourceRegionLeft &&
        cropTop >= _smudgeSourceRegionTop &&
        cropRight <= _smudgeSourceRegionLeft + _smudgeSourceWidth &&
        cropBottom <= _smudgeSourceRegionTop + _smudgeSourceHeight;
    if (!cacheValid) {
      final int margin = AppInteraction.smudgeSourceCacheMargin.round();
      final int regionLeft = max(AppMath.zero, cropLeft - margin);
      final int regionTop = max(AppMath.zero, cropTop - margin);
      final int regionRight = min(canvasWidth, cropRight + margin);
      final int regionBottom = min(canvasHeight, cropBottom + margin);
      final int regionWidth = regionRight - regionLeft;
      final int regionHeight = regionBottom - regionTop;
      final ui.Rect regionRect = ui.Rect.fromLTWH(
        regionLeft.toDouble(),
        regionTop.toDouble(),
        regionWidth.toDouble(),
        regionHeight.toDouble(),
      );

      // Sample only the SELECTED layer (colour + alpha), not the composite
      // through it. Smudge/blur then affect just this layer — preserving its
      // transparency and not pulling an opaque backdrop's colour into the smear
      // (which baked white over a white background and darkened a region when a
      // sparse layer sat over an opaque one). Standard "sample active layer".
      final ui.Image layerSource = await appProvider.layers.captureLayerRegion(selectedLayerIndex, regionRect);
      if (!mounted || generation != _pixelBrushStrokeGeneration) {
        layerSource.dispose();
        return;
      }
      final Uint8List? layerBytes = await extractImagePixels(layerSource, format: ui.ImageByteFormat.rawStraightRgba);
      layerSource.dispose();
      if (layerBytes == null || !mounted || generation != _pixelBrushStrokeGeneration) {
        return;
      }
      _smudgeSourceBytes = layerBytes;
      _smudgeSourceRegionLeft = regionLeft;
      _smudgeSourceRegionTop = regionTop;
      _smudgeSourceWidth = regionWidth;
      _smudgeSourceHeight = regionHeight;
    }
    final Uint8List sourceBytes = _smudgeSourceBytes!;
    final int regionLeft = _smudgeSourceRegionLeft;
    final int regionTop = _smudgeSourceRegionTop;
    final int regionStride = _smudgeSourceWidth;

    // Crop the stroke's region out of the cached region bytes (region-local
    // coordinates) and build the region-local clip mask if a selection is active.
    final Uint8List regionBytes = copyPixelBrushRect(
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
    if (!mounted || generation != _pixelBrushStrokeGeneration) {
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
      brushSize: brushSize,
      intensity: intensity,
      mode: mode,
      clipMask: clipMask,
      preferSynchronous: false,
    );
    if (result == null || !mounted || generation != _pixelBrushStrokeGeneration) {
      return;
    }

    // Build the committed patch image at full resolution (stored in the undoable
    // action for export). A large footprint is downsampled before the CPU→GPU
    // upload and GPU-upscaled back — smudge/blur are soft enough that the loss is
    // invisible. The live display is served by the layer's display cache, updated
    // below; this full-res patch is only materialized for on-demand full-res use.
    final int fpLeft = max(AppMath.zero, patchBounds.left.floor());
    final int fpTop = max(AppMath.zero, patchBounds.top.floor());
    final int fpRight = min(canvasWidth, patchBounds.right.ceil());
    final int fpBottom = min(canvasHeight, patchBounds.bottom.ceil());
    final int fpWidth = fpRight - fpLeft;
    final int fpHeight = fpBottom - fpTop;
    if (fpWidth <= AppMath.zero || fpHeight <= AppMath.zero) {
      return;
    }
    final Uint8List footprintBytes = copyPixelBrushRect(
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
    final ui.Image patchImage;
    if (patchDownsample <= AppMath.one) {
      patchImage = await imageFromPixelsDecode(footprintBytes, fpWidth, fpHeight);
    } else {
      final int lowWidth = max(AppMath.one, fpWidth ~/ patchDownsample);
      final int lowHeight = max(AppMath.one, fpHeight ~/ patchDownsample);
      final Uint8List lowBytes = downsampleRgbaBox(footprintBytes, fpWidth, fpHeight, lowWidth, lowHeight);
      final ui.Image lowImage = await imageFromPixelsDecode(lowBytes, lowWidth, lowHeight);
      patchImage = await renderCanvasImage(
        width: fpWidth,
        height: fpHeight,
        draw: (final ui.Canvas canvas) {
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
    if (!mounted || generation != _pixelBrushStrokeGeneration) {
      patchImage.dispose();
      return;
    }

    final ui.Rect committedBounds = ui.Rect.fromLTRB(
      fpLeft.toDouble(),
      fpTop.toDouble(),
      fpRight.toDouble(),
      fpBottom.toDouble(),
    );

    // Fold the patch into the layer's display-resolution projection (a small,
    // display-res blit) so the commit shows immediately with NO full-canvas GPU
    // work — the fix for the multi-second commit stall. Full resolution is
    // rebuilt lazily on demand (export/sampling) by replaying the appended
    // action; the live canvas never needs it.
    final LayerProvider targetLayer = appProvider.layers.get(layerRestoreState.layerIndex);
    await targetLayer.updateDisplayCacheWithPatch(
      patchImage: patchImage,
      patchBounds: committedBounds,
    );
    if (!mounted || generation != _pixelBrushStrokeGeneration) {
      patchImage.dispose();
      return;
    }

    _applyCommittedPixelBrushPatch(
      appProvider: appProvider,
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
    _blitRegionIntoSmudgeCache(
      region: result.pixels,
      regionWidth: cropWidth,
      regionHeight: cropHeight,
      destLeft: cropLeft - regionLeft,
      destTop: cropTop - regionTop,
    );
    _smudgeSourceSignature = _currentSmudgeSignature(appProvider);
  }

  /// A cheap fingerprint of the composite-through-selected-layer state. Changes
  /// when anything that affects the smudge source changes (action counts, layer
  /// visibility/opacity/blend, selection, canvas size) — but NOT on `clearCache`,
  /// so it stays stable across a run of smudge strokes.
  List<int> _currentSmudgeSignature(final AppProvider appProvider) {
    final LayersProvider layers = appProvider.layers;
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

  /// Blits a patch's pixels back into the cached source region [_smudgeSourceBytes]
  /// (destination in region-local coordinates, stride [_smudgeSourceWidth]).
  void _blitRegionIntoSmudgeCache({
    required final Uint8List region,
    required final int regionWidth,
    required final int regionHeight,
    required final int destLeft,
    required final int destTop,
  }) {
    final Uint8List? dest = _smudgeSourceBytes;
    if (dest == null) {
      return;
    }
    final int rowBytes = regionWidth * AppMath.bytesPerPixel;
    for (int row = AppMath.zero; row < regionHeight; row++) {
      final int destOffset = (((destTop + row) * _smudgeSourceWidth) + destLeft) * AppMath.bytesPerPixel;
      dest.setRange(destOffset, destOffset + rowBytes, region, row * rowBytes);
    }
  }

  /// Frees the smudge source region cache (on tool change / teardown).
  void _clearSmudgeSourceCache() {
    _smudgeSourceBytes = null;
    _smudgeSourceRegionLeft = 0;
    _smudgeSourceRegionTop = 0;
    _smudgeSourceWidth = 0;
    _smudgeSourceHeight = 0;
    _smudgeSourceSignature = null;
  }

  /// Element-wise equality for two nullable int lists (cache signatures).
  bool _intListEquals(final List<int>? a, final List<int>? b) {
    if (a == null || b == null || a.length != b.length) {
      return false;
    }
    for (int i = AppMath.zero; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  /// Commits [committedPatch] to the layer as an undoable pixel-brush action and
  /// trims the undo history. Shared by the GPU and CPU commit paths.
  ///
  /// The committed patch has already been folded into the layer's
  /// display-resolution projection by the caller, so `forward` only appends the
  /// undoable action, drops the (now-stale) full-res cache — rebuilt lazily on
  /// demand — and refreshes the thumbnail cheaply. No full-canvas GPU work.
  void _applyCommittedPixelBrushPatch({
    required final AppProvider appProvider,
    required final ImagePlacementLayerRestoreState layerRestoreState,
    required final PixelBrushLayerPatch committedPatch,
  }) {
    // Textures this record can resurrect: the committed patch plus every image
    // its restore-state snapshots reintroduce on undo/redo. Listing them lets
    // the LayersProvider coordinator free them only once the record is dropped
    // (trim/compaction) and nothing else references them — fixing the per-stroke
    // full-canvas texture leak without risking a use-after-free.
    final List<ui.Image> retainedImages = <ui.Image>[
      committedPatch.image,
      for (final UserActionDrawing action in layerRestoreState.originalActions)
        if (action.image != null) action.image!,
      for (final UserActionDrawing action in layerRestoreState.originalRedoActions)
        if (action.image != null) action.image!,
    ];

    appProvider.undoProvider.executeAction(
      name: _pixelBrushMode.name,
      retainedImages: retainedImages,
      forward: () {
        final LayerProvider targetLayer = appProvider.layers.get(layerRestoreState.layerIndex);
        appProvider.layers.selectedLayerIndex = layerRestoreState.layerIndex;
        targetLayer.clearLivePixelBrushPreview();
        // Append without clearing caches (that would schedule a full-canvas
        // thumbnail rebuild); the display projection already reflects this patch.
        applyPixelBrushPatchToLayer(
          restoreState: layerRestoreState,
          targetLayer: targetLayer,
          patch: committedPatch,
          mode: _pixelBrushMode,
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
        appProvider.update();
      },
      backward: () {
        _restorePixelBrushLayerState(
          appProvider: appProvider,
          restoreState: layerRestoreState,
        );
        appProvider.update();
      },
    );

    appProvider.undoProvider.trimUndoHistoryWhere(
      predicate: (final RecordAction action) {
        return action.name == PixelBrushMode.smudge.name || action.name == PixelBrushMode.blur.name;
      },
      maxKeep: AppInteraction.pixelBrushMaxUndoGestures,
    );
  }

  /// Restores the selected layer state captured before the current pixel-brush stroke.
  void _restorePixelBrushLayerState({
    required final AppProvider appProvider,
    required final ImagePlacementLayerRestoreState restoreState,
  }) {
    final LayerProvider targetLayer = appProvider.layers.get(restoreState.layerIndex);
    appProvider.layers.selectedLayerIndex = restoreState.layerIndex;
    targetLayer.actionStack
      ..clear()
      ..addAll(restoreState.originalActions);
    targetLayer.redoStack
      ..clear()
      ..addAll(restoreState.originalRedoActions);
    targetLayer.backgroundColor = restoreState.originalBackgroundColor;
    targetLayer.blendMode = restoreState.originalBlendMode;
    targetLayer.opacity = restoreState.originalOpacity;
    targetLayer.hasChanged = restoreState.originalHasChanged;
    targetLayer.clearCache();
  }

  /// Starts tracking a pixel-brush stroke from [position] with the given [mode].
  ///
  /// Lightweight: it captures only the undo restore-state, the clip path, and the
  /// first point, then publishes the gesture marquee. No source readback, worker,
  /// or live rasterization happens during the drag — the whole effect is rendered
  /// once in [_commitPixelBrushStroke] on pointer-up. This keeps the drag O(1) at
  /// any canvas size.
  void _startPixelBrushStroke(
    final AppProvider appProvider,
    final Offset position,
    final PixelBrushMode mode,
  ) {
    // A prior stroke whose pointer-up was cancelled or arrived with a mismatched
    // pointer id never ran _clearPixelBrushStroke; reclaim its state first.
    if (_pixelBrushLayerRestoreState != null) {
      _clearPixelBrushStroke();
    }
    _pixelBrushStrokeGeneration++;
    _pixelBrushMode = mode;
    _pixelBrushIntensity = appProvider.brushIntensity;
    _pixelBrushLayerRestoreState = appProvider.captureSelectedLayerRestoreState();
    _pixelBrushClipPath = appProvider.selectorModel.isVisible && appProvider.selectorModel.path1 != null
        ? ui.Path.from(appProvider.selectorModel.path1!)
        : null;
    _pixelBrushStrokePatchBounds = null;
    _appendPixelBrushPoint(position, appProvider.brushSize);
    appProvider.showPixelBrushGesture(
      points: _pixelBrushStrokePoints,
      size: appProvider.brushSize,
    );
  }
}
