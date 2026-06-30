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
    PixelBrushProfiler.endStroke();
    // Bump the generation first so any in-flight worker startup disposes the
    // isolate it spawns instead of leaking it.
    _pixelBrushStrokeGeneration++;
    // Dispose the GPU stroke if it wasn't committed (commit calls detachImage(),
    // which leaves _gpuPixelBrushStroke null so this is a no-op then).
    _gpuPixelBrushStroke?.dispose();
    _gpuPixelBrushStroke = null;
    _lastDabCenter = null;
    _pixelBrushWorker?.dispose();
    _pixelBrushWorker = null;
    _pixelBrushWorkerStartup = null;
    _pixelBrushStrokePoints.clear();
    _pixelBrushLayerRestoreState = null;
    // Free the full-canvas source/baseline images captured for this stroke;
    // they are stroke-internal and not handed to the committed action, so
    // overwriting them on the next stroke without disposing leaks a full-canvas
    // texture per stroke. The prepared source's image may alias
    // [_pixelBrushSourceImage], so guard against a double dispose.
    final ui.Image? strokeSourceImage = _pixelBrushSourceImage;
    final ui.Image? preparedSourceImage = _preparedPixelBrushSource?.image;
    strokeSourceImage?.dispose();
    if (preparedSourceImage != null && !identical(preparedSourceImage, strokeSourceImage)) {
      preparedSourceImage.dispose();
    }
    _preparedPixelBrushSource = null;
    _pixelBrushPreparation = null;
    _pixelBrushSourceImage = null;
    _pixelBrushClipPath = null;
    _livePixelBuffer = null;
    _lastKickedPointIndex = 0;
    _pixelBrushStrokePatchBounds = null;
    _pixelBrushTargetLayer?.clearLivePixelBrushPreview();
    _pixelBrushTargetLayer = null;
    _pixelBrushRasterBusy = false;
    _pixelBrushUpdateNeeded = false;
  }

  /// Commits the pixel-brush stroke as an undoable image action.
  ///
  /// If a live preview has been running we already have an up-to-date
  /// [_livePixelBuffer]; we only run a final segment for any points appended
  /// after the last kick, then convert the buffer to a [ui.Image].
  Future<void> _commitPixelBrushStroke(final AppProvider appProvider) async {
    final ui.Image? sourceImage = _pixelBrushSourceImage;
    final ImagePlacementLayerRestoreState? layerRestoreState = _pixelBrushLayerRestoreState;
    if (sourceImage == null || layerRestoreState == null || _pixelBrushStrokePoints.length < AppMath.pair) {
      if (layerRestoreState != null) {
        _restorePixelBrushLayerState(appProvider: appProvider, restoreState: layerRestoreState);
      }
      return;
    }

    // GPU path: the final working image is already on the GPU. Commit it as a
    // full-canvas image patch — no readback, no CPU compute.
    if (_gpuPixelBrushStroke != null) {
      final ui.Image finalImage = _gpuPixelBrushStroke!.detachImage();
      _gpuPixelBrushStroke = null;
      _applyCommittedPixelBrushPatch(
        appProvider: appProvider,
        layerRestoreState: layerRestoreState,
        committedPatch: PixelBrushLayerPatch(
          bounds: ui.Rect.fromLTWH(0, 0, sourceImage.width.toDouble(), sourceImage.height.toDouble()),
          image: finalImage,
        ),
      );
      return;
    }

    final PreparedSmudgeStrokeSource? prepared =
        _preparedPixelBrushSource ??
        await _pixelBrushPreparation ??
        await preparePixelBrushSource(
          sourceImage: sourceImage,
          clipPath: _pixelBrushClipPath,
        );
    if (prepared == null) {
      _restorePixelBrushLayerState(appProvider: appProvider, restoreState: layerRestoreState);
      return;
    }

    // Apply any remaining un-kicked segment, then read back the accumulated
    // buffer. When the background worker handled the stroke it owns the
    // authoritative buffer; otherwise fall back to the synchronous path.
    final PixelBrushStrokeWorker? worker = _pixelBrushWorker ?? await _pixelBrushWorkerStartup;
    final int remainingStart = normalizePixelBrushRemainingStart(
      lastKickedPointIndex: _lastKickedPointIndex,
      strokePointCount: _pixelBrushStrokePoints.length,
    );
    final List<Offset> remaining = _pixelBrushStrokePoints.sublist(remainingStart);

    Uint8List currentPixels = _livePixelBuffer ?? Uint8List.fromList(prepared.pixels);

    if (worker != null) {
      if (remaining.length >= AppMath.pair) {
        final ui.Rect? remainingBounds = resolvePixelBrushPatchBounds(
          strokePoints: remaining,
          imageWidth: sourceImage.width,
          imageHeight: sourceImage.height,
          brushSize: appProvider.brushSize,
        );
        if (remainingBounds != null) {
          await worker.applySegment(
            segmentPoints: remaining,
            brushSize: appProvider.brushSize,
            intensity: _pixelBrushIntensity,
            mode: _pixelBrushMode,
            patchBounds: remainingBounds,
          );
        }
      }
      final Uint8List? finalized = await worker.finalizePixels();
      if (finalized != null) {
        currentPixels = finalized;
      }
    } else if (remaining.length >= AppMath.pair) {
      final PixelBrushSegmentResult? segResult = await rasterizePixelBrushSegment(
        livePixels: currentPixels,
        imageWidth: sourceImage.width,
        imageHeight: sourceImage.height,
        segmentPoints: remaining,
        brushSize: appProvider.brushSize,
        intensity: _pixelBrushIntensity,
        mode: _pixelBrushMode,
        clipMask: prepared.clipMask,
        preferSynchronous: true,
      );
      if (segResult != null) {
        currentPixels = segResult.pixels;
      }
    }

    final PixelBrushLayerPatch? committedPatch = await buildPixelBrushLayerPatch(
      pixels: currentPixels,
      imageWidth: sourceImage.width,
      imageHeight: sourceImage.height,
      strokePoints: _pixelBrushStrokePoints,
      brushSize: appProvider.brushSize,
      preferredBounds: _pixelBrushStrokePatchBounds,
    );
    if (committedPatch == null) {
      _restorePixelBrushLayerState(appProvider: appProvider, restoreState: layerRestoreState);
      return;
    }

    _applyCommittedPixelBrushPatch(
      appProvider: appProvider,
      layerRestoreState: layerRestoreState,
      committedPatch: committedPatch,
    );
  }

  /// Commits [committedPatch] to the layer as an undoable pixel-brush action and
  /// trims the undo history. Shared by the GPU and CPU commit paths.
  void _applyCommittedPixelBrushPatch({
    required final AppProvider appProvider,
    required final ImagePlacementLayerRestoreState layerRestoreState,
    required final PixelBrushLayerPatch committedPatch,
  }) {
    appProvider.undoProvider.executeAction(
      name: _pixelBrushMode.name,
      forward: () {
        final LayerProvider targetLayer = appProvider.layers.get(layerRestoreState.layerIndex);
        appProvider.layers.selectedLayerIndex = layerRestoreState.layerIndex;
        targetLayer.clearLivePixelBrushPreview();
        applyPixelBrushPatchToLayer(
          restoreState: layerRestoreState,
          targetLayer: targetLayer,
          patch: committedPatch,
          mode: _pixelBrushMode,
        );
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

  /// Fires an incremental pixel-brush rasterization for live drag preview.
  ///
  /// Sends only the *new* segment of points since the last successful kick so
  /// each isolate call is O(segment) rather than O(full stroke). The resulting
  /// pixel buffer is stored in [_livePixelBuffer] and fed back as the starting
  /// state for the next segment, making the effect accumulate correctly.
  ///
  /// Skips if a rasterization is already running; marks that a re-run is
  /// needed so the next completion triggers another pass.
  void _kickLivePixelBrushPreview(final AppProvider appProvider) {
    PixelBrushProfiler.recordKickAttempt();
    if (_pixelBrushRasterBusy) {
      _pixelBrushUpdateNeeded = true;
      PixelBrushProfiler.recordSkipBusy();
      return;
    }
    // Need at least one overlap point (the last processed point) plus one new
    // point so the isolate has a valid segment.
    final int currentLength = _pixelBrushStrokePoints.length;
    final int segmentStart = _lastKickedPointIndex > AppMath.zero ? _lastKickedPointIndex : AppMath.zero;
    if (currentLength - segmentStart < AppMath.pair) {
      PixelBrushProfiler.recordSkipFewPoints();
      return;
    }
    final ui.Image? sourceImage = _pixelBrushSourceImage;
    final ImagePlacementLayerRestoreState? restoreState = _pixelBrushLayerRestoreState;
    if (sourceImage == null || restoreState == null) {
      return;
    }
    _pixelBrushRasterBusy = true;
    _pixelBrushUpdateNeeded = false;
    PixelBrushProfiler.markKickStart();

    // Snapshot the segment we are about to process.
    final List<Offset> segmentPoints = List<Offset>.of(_pixelBrushStrokePoints.sublist(segmentStart));
    // After this kick succeeds the new "last processed" index will be:
    final int nextLastIndex = currentLength - AppMath.one;
    final double brushSize = appProvider.brushSize;
    final PixelBrushMode mode = _pixelBrushMode;
    final Uint8List? startPixels = _livePixelBuffer;
    final int strokeGeneration = _pixelBrushStrokeGeneration;
    // Compute the dirty rect for this segment only — avoids growing the patch
    // image to full-stroke size on every update.
    final ui.Rect? segmentBounds = resolvePixelBrushPatchBounds(
      strokePoints: segmentPoints,
      imageWidth: sourceImage.width,
      imageHeight: sourceImage.height,
      brushSize: brushSize,
    );

    unawaited(
      (() async {
            // Prefer the long-lived stroke worker (background isolate): it owns the
            // accumulating buffer, so we send only the new segment points and get
            // back the small dirty-rect patch — no full-image transfer and no
            // main-thread blocking. Awaiting the startup future also waits for the
            // source preparation it depends on.
            final Stopwatch startupAwaitWatch = Stopwatch()..start();
            final PixelBrushStrokeWorker? worker = _pixelBrushWorker ?? await _pixelBrushWorkerStartup;
            startupAwaitWatch.stop();
            PixelBrushProfiler.record('awaitStartup', startupAwaitWatch.elapsedMicroseconds);
            if (strokeGeneration != _pixelBrushStrokeGeneration) {
              return;
            }
            if (!mounted || _pixelBrushSourceImage == null) {
              _pixelBrushRasterBusy = false;
              return;
            }

            if (worker != null) {
              // The worker mutated its retained buffer, so these points are now
              // consumed regardless of whether they produced a visible change.
              _lastKickedPointIndex = nextLastIndex;
              if (segmentBounds != null) {
                final PixelBrushPatchUpdate? update = await worker.applySegment(
                  segmentPoints: segmentPoints,
                  brushSize: brushSize,
                  intensity: _pixelBrushIntensity,
                  mode: mode,
                  patchBounds: segmentBounds,
                );
                if (strokeGeneration != _pixelBrushStrokeGeneration) {
                  return;
                }
                if (!mounted || _pixelBrushSourceImage == null) {
                  _pixelBrushRasterBusy = false;
                  return;
                }
                if (update != null) {
                  final Stopwatch patchWatch = Stopwatch()..start();
                  final PixelBrushLayerPatch? livePatch = await buildPixelBrushLayerPatchFromBytes(
                    pixels: update.pixels,
                    left: update.left,
                    top: update.top,
                    width: update.width,
                    height: update.height,
                  );
                  patchWatch.stop();
                  PixelBrushProfiler.record('patchImageBuild', patchWatch.elapsedMicroseconds);
                  if (!mounted || _pixelBrushSourceImage == null) {
                    _pixelBrushRasterBusy = false;
                    return;
                  }
                  if (livePatch != null && strokeGeneration == _pixelBrushStrokeGeneration) {
                    _pixelBrushTargetLayer?.setLivePixelBrushPatch(
                      livePatch.image,
                      livePatch.bounds,
                    );
                    appProvider.layers.repaintCanvas();
                  }
                }
              }
            } else {
              // Synchronous fallback (web, or worker spawn failed). Mutates
              // basePixels in place, so copy the pristine source on the first
              // segment to keep it intact for commit/undo.
              final PreparedSmudgeStrokeSource? prepared = _preparedPixelBrushSource ?? await _pixelBrushPreparation;
              if (strokeGeneration != _pixelBrushStrokeGeneration) {
                return;
              }
              if (!mounted || _pixelBrushSourceImage == null || prepared == null) {
                _pixelBrushRasterBusy = false;
                return;
              }
              final Uint8List basePixels = startPixels ?? Uint8List.fromList(prepared.pixels);
              final PixelBrushSegmentResult? result = await rasterizePixelBrushSegment(
                livePixels: basePixels,
                imageWidth: sourceImage.width,
                imageHeight: sourceImage.height,
                segmentPoints: segmentPoints,
                brushSize: brushSize,
                intensity: _pixelBrushIntensity,
                mode: mode,
                clipMask: prepared.clipMask,
                preferSynchronous: true,
              );
              if (strokeGeneration != _pixelBrushStrokeGeneration) {
                return;
              }
              if (!mounted || _pixelBrushSourceImage == null) {
                _pixelBrushRasterBusy = false;
                return;
              }
              if (result != null) {
                _livePixelBuffer = result.pixels;
                _lastKickedPointIndex = nextLastIndex;
                if (segmentBounds != null) {
                  final PixelBrushLayerPatch? livePatch = await buildPixelBrushLayerPatchFast(
                    pixels: result.pixels,
                    imageWidth: result.width,
                    imageHeight: result.height,
                    patchBounds: segmentBounds,
                  );
                  if (!mounted || _pixelBrushSourceImage == null) {
                    _pixelBrushRasterBusy = false;
                    return;
                  }
                  if (livePatch != null) {
                    _pixelBrushTargetLayer?.setLivePixelBrushPatch(
                      livePatch.image,
                      livePatch.bounds,
                    );
                    appProvider.layers.repaintCanvas();
                  }
                }
              }
            }

            _pixelBrushRasterBusy = false;
            if (_pixelBrushUpdateNeeded) {
              _kickLivePixelBrushPreview(appProvider);
            }
          })()
          .then<void>(
            (final void _) {},
            onError: (final Object error, final StackTrace stack) {
              PixelBrushProfiler.recordException();
              debugPrint('[PixelBrushProfile] kick exception: $error\n$stack');
            },
          )
          .whenComplete(() {
            // Safety net: an exception must never strand the busy flag — if it did,
            // every later move would early-return on `busy` and the live preview
            // would freeze for the rest of the stroke.
            if (_pixelBrushRasterBusy) {
              _pixelBrushRasterBusy = false;
              if (_pixelBrushUpdateNeeded && mounted && _pixelBrushSourceImage != null) {
                _kickLivePixelBrushPreview(appProvider);
              }
            }
          }),
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
  void _startPixelBrushStroke(
    final AppProvider appProvider,
    final Offset position,
    final PixelBrushMode mode,
  ) {
    _pixelBrushStrokeGeneration++;
    PixelBrushProfiler.beginStroke();
    _pixelBrushMode = mode;
    _pixelBrushIntensity = appProvider.brushIntensity;
    _pixelBrushLayerRestoreState = appProvider.captureSelectedLayerRestoreState();
    final Stopwatch captureWatch = Stopwatch()..start();
    _pixelBrushSourceImage = pixelBrushUsesCompositeBackdrop(mode)
        ? appProvider.layers.capturePainterToImageThroughLayerSync(appProvider.layers.selectedLayerIndex)
        : appProvider.layers.selectedLayer.toImageForStorage(appProvider.layers.size);
    captureWatch.stop();
    PixelBrushProfiler.record('sourceCapture', captureWatch.elapsedMicroseconds);
    _pixelBrushClipPath = appProvider.selectorModel.isVisible && appProvider.selectorModel.path1 != null
        ? ui.Path.from(appProvider.selectorModel.path1!)
        : null;
    _preparedPixelBrushSource = null;
    _livePixelBuffer = null;
    _lastKickedPointIndex = 0;
    _pixelBrushStrokePatchBounds = null;
    _pixelBrushTargetLayer = appProvider.layers.get(appProvider.layers.selectedLayerIndex);
    _pixelBrushTargetLayer!.beginLivePixelBrushPreview();

    // GPU path (primary): if the shader is loaded, run the whole effect on the
    // GPU seeded from the just-captured baseline image. No readback, no worker,
    // no async — each pointer-move applies one synchronous dab.
    _gpuPixelBrushStroke = null;
    _lastDabCenter = null;
    final ui.FragmentProgram? gpuProgram = GpuPixelBrushStroke.loadedProgram;
    final ui.Image? gpuBaseline = _pixelBrushTargetLayer!.livePreviewBaseline;
    if (gpuProgram != null && gpuBaseline != null) {
      _gpuPixelBrushStroke = GpuPixelBrushStroke.create(program: gpuProgram, baseline: gpuBaseline);
      _lastDabCenter = position;
      _appendPixelBrushPoint(position, appProvider.brushSize);
      return;
    }

    final int startGeneration = _pixelBrushStrokeGeneration;
    final int selectedLayerIndex = appProvider.layers.selectedLayerIndex;
    final Size strokeSize = appProvider.layers.size;
    final bool usesCompositeBackdrop = pixelBrushUsesCompositeBackdrop(mode);
    final Stopwatch prepWatch = Stopwatch()..start();
    // Render the source pixels via async `toImage()` (not `toImageSync()`):
    // `toByteData()` on a `toImageSync()` image stalls the GPU for *seconds* on
    // Impeller, which was freezing the entire live preview until stroke end.
    final Future<PreparedSmudgeStrokeSource?> preparation =
        (() async {
          final Stopwatch renderWatch = Stopwatch()..start();
          final ui.Image readbackImage = usesCompositeBackdrop
              ? await appProvider.layers.capturePainterToImageThroughLayer(selectedLayerIndex)
              : await appProvider.layers.get(selectedLayerIndex).toImageForStorageAsync(strokeSize);
          renderWatch.stop();
          PixelBrushProfiler.record('srcRender', renderWatch.elapsedMicroseconds);
          final Stopwatch extractWatch = Stopwatch()..start();
          final PreparedSmudgeStrokeSource? prepared = await preparePixelBrushSource(
            sourceImage: readbackImage,
            clipPath: _pixelBrushClipPath,
          );
          extractWatch.stop();
          PixelBrushProfiler.record('srcExtractAndMask', extractWatch.elapsedMicroseconds);
          return prepared;
        })().then((final PreparedSmudgeStrokeSource? prepared) {
          prepWatch.stop();
          PixelBrushProfiler.record('prepareSource', prepWatch.elapsedMicroseconds);
          return prepared;
        });
    _pixelBrushPreparation = preparation;
    // Start the long-lived stroke worker as soon as the source pixels are
    // prepared. It owns the accumulating buffer in a background isolate so the
    // per-pixel blending never blocks the UI isolate.
    _pixelBrushWorker = null;
    _pixelBrushWorkerStartup = preparation.then((final PreparedSmudgeStrokeSource? prepared) async {
      if (prepared == null || startGeneration != _pixelBrushStrokeGeneration) {
        return null;
      }
      _preparedPixelBrushSource = prepared;
      final PixelBrushStrokeWorker? worker = await PixelBrushStrokeWorker.start(
        basePixels: prepared.pixels,
        imageWidth: prepared.image.width,
        imageHeight: prepared.image.height,
        clipMask: prepared.clipMask,
      );
      // A newer stroke may have started (or this one ended) while spawning.
      if (startGeneration != _pixelBrushStrokeGeneration) {
        worker?.dispose();
        return null;
      }
      _pixelBrushWorker = worker;
      return worker;
    });
    unawaited(_pixelBrushWorkerStartup);
    _appendPixelBrushPoint(position, appProvider.brushSize);
  }
}
