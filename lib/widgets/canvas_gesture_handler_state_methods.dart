part of 'canvas_gesture_handler.dart';

extension _CanvasGestureHandlerStateMethods on _CanvasGestureHandlerState {
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

  /// Reads the current keyboard modifier state and temporarily overrides
  /// [selectorModel.math] for the upcoming selection gesture:
  ///   Shift + Option/Alt -> intersect
  ///   Shift             -> add
  ///   Option/Alt        -> remove
  ///   (none)            -> no override; existing math is preserved
  ///
  /// The original value is saved in [_previousSelectorMath] and restored by
  /// [_restoreSelectionMath] once the gesture completes.
  void _applySelectionModifierMath(final AppProvider appProvider) {
    final bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final bool isAltPressed = HardwareKeyboard.instance.isAltPressed;

    if (!isShiftPressed && !isAltPressed) {
      return;
    }

    final SelectorMath overrideMath;
    if (isShiftPressed && isAltPressed) {
      overrideMath = SelectorMath.intersect;
    } else if (isShiftPressed) {
      overrideMath = SelectorMath.add;
    } else {
      overrideMath = SelectorMath.remove;
    }

    _previousSelectorMath = appProvider.selectorModel.math;
    appProvider.selectorModel.math = overrideMath;
    appProvider.repaintToolOptions();
  }

  /// Returns whether drawing may start on the selected layer, surfacing a
  /// message and aborting when the layer is hidden or locked.
  bool _canStartDrawingOnSelectedLayer(final AppProvider appProvider) {
    if (appProvider.layers.selectedLayer.isVisible == false) {
      final AppLocalizations l10n = context.l10n;
      context.showSnackBarMessage(
        l10n.selectionIsHidden,
      );
      return false;
    }

    if (appProvider.isSelectedLayerLocked) {
      _activePointerId = -1;
      _showLockedLayerMessage(appProvider);
      return false;
    }

    return true;
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

  void _clearSelectionTapTracking() {
    _lastSelectionTapTimestamp = null;
    _lastSelectionTapCanvasPosition = null;
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

  /// Returns the distance between the first two active touch points.
  ///
  /// Returns 0.0 when fewer than two touch pointers are active.
  double _getDistanceBetweenTouchPoints() {
    if (_pointerPositions.length >= AppMath.pair) {
      final List<Offset> positions = _pointerPositions.values.toList();
      final Offset pos1 = positions[0];
      final Offset pos2 = positions[1];
      return (pos2 - pos1).distance;
    } else {
      return 0.0;
    }
  }

  /// Captures an eyedropper sample at [adjustedPosition] when an eyedropper is
  /// armed. Returns whether the pointer-down was consumed.
  bool _handleEyeDropperPointerStart(
    final AppProvider appProvider,
    final ui.Offset adjustedPosition,
  ) {
    if (appProvider.eyeDropPositionForBrush != null) {
      appProvider.layers.capturePainterToImage();
      appProvider.eyeDropPositionForBrush = adjustedPosition;
      return true;
    }

    if (appProvider.eyeDropPositionForFill != null) {
      appProvider.layers.capturePainterToImage();
      appProvider.eyeDropPositionForFill = adjustedPosition;
      return true;
    }

    return false;
  }

  /// Starts a flood fill at [adjustedPosition], honouring an active selection,
  /// solid fill, or gradient fill initialization.
  Future<void> _handleFillPointerStart(
    final AppProvider appProvider,
    final ui.Offset adjustedPosition,
  ) async {
    final bool sampleAllLayers = _isSampleAllLayersModifierPressed();

    if (await appProvider.prepareFloodFillSelection(
      adjustedPosition,
      sampleAllLayers: sampleAllLayers,
    )) {
      return;
    }

    if (appProvider.fillModel.mode == FillMode.solid) {
      appProvider.fillModel.gradientPoints.clear();
      appProvider.fillModel.sampleAllLayers = sampleAllLayers;
      appProvider.floodFillSolidAction(
        adjustedPosition,
        sampleAllLayers: sampleAllLayers,
      );
      return;
    }

    if (appProvider.fillModel.gradientPoints.isEmpty) {
      _initializeGradientFill(appProvider, adjustedPosition, sampleAllLayers: sampleAllLayers);
    }
  }

  /// Handles two-finger pan and pinch updates for manual canvas navigation.
  void _handleMultiTouchUpdate(
    final PointerMoveEvent event,
    final AppProvider appProvider,
    final ShellProvider shellProvider,
  ) {
    appProvider.canvasOffset += event.delta;
    final double newDistance = _getDistanceBetweenTouchPoints();
    final double distanceDelta = _baseDistance - newDistance;

    if (distanceDelta.abs() > AppInteraction.multiTouchScaleThreshold) {
      _scaleFactor = _getDistanceBetweenTouchPoints() / _baseDistance;
      _scaleFactor = max(AppInteraction.minCanvasScale, min(_scaleFactor, AppInteraction.maxCanvasScale));

      final Offset before = appProvider.toCanvas(event.localPosition);
      appProvider.layers.scale = _scaleFactor;
      final Offset after = appProvider.toCanvas(event.localPosition);
      final Offset adjustment = after - before;
      appProvider.canvasOffset += adjustment * appProvider.layers.scale;
    }

    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
    appProvider.repaintViewport();
  }

  /// Finalizes an active pointer interaction and clears temporary drawing state.
  void _handlePointerEnd(
    final AppProvider appProvider,
    final PointerEvent event,
  ) async {
    appProvider.layers.selectedLayer.isUserDrawing = false;
    final bool isSelectionActive =
        appProvider.selectedAction == ActionType.selector && !appProvider.transformModel.isVisible;

    if (_activePointerId == event.pointer) {
      if (isSelectionActive) {
        appProvider.selectorCreationEnd();
        _restoreSelectionMath(appProvider);
        if (appProvider.selectorModel.mode != SelectorMode.line || !appProvider.selectorModel.isDrawing) {
          _clearSelectionTapTracking();
        }
      } else if (_pixelBrushSourceImage != null) {
        _appendPixelBrushPoint(appProvider.toCanvas(event.localPosition), appProvider.brushSize);
        await _commitPixelBrushStroke(appProvider);
        _clearSelectionTapTracking();
      } else {
        _clearSelectionTapTracking();
      }
      appProvider.hideDrawingToolPreview();
      _activePointerId = -1;
      _clearPixelBrushStroke();
      appProvider.layers.selectedLayer.clearCache();
      if (!mounted) {
        return;
      }
      final DraftFlusher controller = Provider.of<DraftFlusher>(context, listen: false);
      unawaited(controller.flushNow());
      appProvider.update();
    }
  }

  /// Handles pointer move events for drawing, selection, and eyedropper interactions.
  void _handlePointerMove(
    final AppProvider appProvider,
    final PointerEvent event,
  ) {
    if (appProvider.hasActiveTransformOverlay) {
      return;
    }

    final Offset adjustedPosition = appProvider.toCanvas(event.localPosition);
    final bool isSelectionActive =
        appProvider.selectedAction == ActionType.selector && !appProvider.transformModel.isVisible;

    if (appProvider.eyeDropPositionForBrush != null) {
      appProvider.eyeDropPositionForBrush = event.localPosition;
      appProvider.repaintMainView();
      return;
    }
    if (appProvider.eyeDropPositionForFill != null) {
      appProvider.eyeDropPositionForFill = event.localPosition;
      appProvider.repaintMainView();
      return;
    }

    if (isSelectionActive &&
        appProvider.selectorModel.mode == SelectorMode.line &&
        appProvider.selectorModel.isDrawing) {
      appProvider.selectorCreationPreview(adjustedPosition);
      return;
    }

    if (event.buttons == 1 && _activePointerId == event.pointer) {
      if (isSelectionActive) {
        appProvider.selectorCreationAdditionalPoint(adjustedPosition);
        return;
      }

      if (_pixelBrushSourceImage != null) {
        PixelBrushProfiler.recordMove();
        // Keep the brush-size marquee tracking the cursor for the whole drag.
        // (Safe now that the GPU stroke has no readback to starve, and the
        // canvas RepaintBoundary stops repaintMainView from re-rasterizing it.)
        _updateDrawingToolPreview(appProvider, event.localPosition);
        _appendPixelBrushPoint(adjustedPosition, appProvider.brushSize);
        // GPU path: synchronous shader dabs displayed immediately. A pointer
        // moves more than one spacing between frames, so — exactly like the CPU
        // stepping in rasterizePixelBrushSegment — interpolate the move into
        // spacing-sized sub-dabs. Dabbing only at the raw pointer position would
        // leave gaps (visible dots) and a large per-dab displacement that pulls
        // the smudge source far off the cursor centre. Each dab is a full-canvas
        // `toImageSync`, so the spacing also bounds the dab count per stroke.
        if (_gpuPixelBrushStroke != null) {
          final double radius = max(
            AppInteraction.smudgeMinimumRadius,
            appProvider.brushSize * AppInteraction.smudgeBrushRadiusFactor,
          );
          final double baseSpacing = max(
            AppInteraction.smudgeInputPointSpacing,
            radius * AppInteraction.smudgeGpuStepSpacingFactor,
          );
          final ui.Offset start = _lastDabCenter ?? adjustedPosition;
          final double dist = (adjustedPosition - start).distance;
          if (dist < baseSpacing) {
            return;
          }
          final GpuPixelBrushStroke stroke = _gpuPixelBrushStroke!;
          // Fine spacing for a seamless trail, but clamp the count for one move
          // so a fast flick widens spacing slightly rather than stalling.
          int steps = (dist / baseSpacing).floor();
          final double spacing = steps > AppInteraction.smudgeGpuMaxDabsPerMove
              ? dist / AppInteraction.smudgeGpuMaxDabsPerMove
              : baseSpacing;
          steps = min(steps, AppInteraction.smudgeGpuMaxDabsPerMove);
          final ui.Offset stepDelta = (adjustedPosition - start) / dist * spacing;
          final Stopwatch dabWatch = Stopwatch()..start();
          ui.Offset prev = start;
          for (int step = AppMath.one; step <= steps; step++) {
            final ui.Offset cur = start + stepDelta * step.toDouble();
            stroke.dab(
              from: prev,
              to: cur,
              brushSize: appProvider.brushSize,
              intensity: _pixelBrushIntensity,
              mode: _pixelBrushMode,
            );
            prev = cur;
          }
          dabWatch.stop();
          PixelBrushProfiler.record('gpuDab', dabWatch.elapsedMicroseconds);
          // Advance by whole steps only; the sub-spacing remainder is picked up
          // once the cursor travels another full spacing, keeping displacement
          // constant at `spacing` per dab.
          _lastDabCenter = prev;
          _pixelBrushTargetLayer?.setLivePixelBrushImage(stroke.image);
          appProvider.layers.repaintCanvas();
          return;
        }
        _kickLivePixelBrushPreview(appProvider);
        return;
      }

      _updateDrawingToolPreview(appProvider, event.localPosition);

      if (appProvider.selectedAction == ActionType.fill) {
        return;
      }

      if (appProvider.selectedAction == ActionType.pencil) {
        appProvider.appendLineFromLastUserAction(adjustedPosition);
      } else if (appProvider.selectedAction == ActionType.eraser) {
        appProvider.appendLineFromLastUserAction(adjustedPosition);
      } else if (appProvider.selectedAction == ActionType.brush) {
        appProvider.layers.selectedLayer.lastActionAppendPosition(position: adjustedPosition);
        appProvider.layers.repaintCanvas();
      } else {
        appProvider.updateAction(end: adjustedPosition);
        appProvider.layers.repaintCanvas();
      }
    }
  }

  /// Starts pointer interactions including drawing, selection, fill, and text placement.
  ///
  /// Acts as a dispatcher: each tool's behaviour lives in a focused handler so this
  /// method only decides which one applies for the current pointer-down.
  void _handlePointerStart(
    final AppProvider appProvider,
    final PointerDownEvent event,
  ) async {
    if (appProvider.hasActiveTransformOverlay) {
      return;
    }

    if (event.buttons != 1 || _activePointerId != -1) {
      return;
    }

    final ui.Offset adjustedPosition = appProvider.toCanvas(event.localPosition);

    if (_handleEyeDropperPointerStart(appProvider, adjustedPosition)) {
      return;
    }

    _activePointerId = event.pointer;

    final bool isSelectionActive =
        appProvider.selectedAction == ActionType.selector && !appProvider.transformModel.isVisible;
    if (isSelectionActive) {
      _handleSelectionPointerStart(appProvider, event, adjustedPosition);
      return;
    }

    _updateDrawingToolPreview(appProvider, event.localPosition);

    if (!_canStartDrawingOnSelectedLayer(appProvider)) {
      return;
    }

    if (appProvider.selectedAction == ActionType.text) {
      _handleTextPointerStart(appProvider, adjustedPosition);
      return;
    }

    if (appProvider.selectedAction == ActionType.fill) {
      await _handleFillPointerStart(appProvider, adjustedPosition);
      return;
    }

    _startDrawingPointer(appProvider, adjustedPosition);
  }

  /// Begins a selection at [adjustedPosition], applying modifier math and
  /// closing an in-progress straight-line selection on a double tap.
  void _handleSelectionPointerStart(
    final AppProvider appProvider,
    final PointerDownEvent event,
    final ui.Offset adjustedPosition,
  ) {
    _applySelectionModifierMath(appProvider);
    if (_tryCloseStraightLineSelectionOnDoubleTap(appProvider, event, adjustedPosition)) {
      return;
    }
    appProvider.selectorCreationStart(
      adjustedPosition,
      sampleAllLayers: appProvider.selectorModel.mode == SelectorMode.wand && _isSampleAllLayersModifierPressed(),
    );
  }

  /// Selects an existing text object under [adjustedPosition] or opens the text
  /// dialog to create a new one. Releases the active pointer because a modal may
  /// consume the matching pointer-up.
  void _handleTextPointerStart(
    final AppProvider appProvider,
    final ui.Offset adjustedPosition,
  ) {
    TextObject? selectedText;

    for (final UserActionDrawing action in appProvider.layers.selectedLayer.actionStack.reversed) {
      if (action.textObject != null && action.textObject!.containsPoint(adjustedPosition)) {
        selectedText = action.textObject;
        break;
      }
    }

    if (selectedText != null) {
      _activePointerId = -1;
      appProvider.adoptTextToolStateFromObject(selectedText);
      appProvider.selectedTextObject = selectedText;
      return;
    }

    _activePointerId = -1;
    _showTextDialog(appProvider, adjustedPosition);
  }

  void _handleUserPanningTheCanvas(
    final ShellProvider shellProvider,
    final AppProvider appProvider,
    final Offset offsetDelta,
  ) {
    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
    appProvider.canvasPan(
      offsetDelta: offsetDelta,
      notifyListener: false,
      notifyViewport: true,
    );
  }

  /// Applies user-driven canvas scaling around [anchorPoint].
  void _handleUserScalingTheCanvas(
    final ShellProvider shellProvider,
    final AppProvider appProvider,
    final Offset anchorPoint,
    final double scaleDelta,
  ) {
    if (scaleDelta == 1) {
      return;
    }

    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;

    appProvider.applyScaleToCanvas(
      scaleDelta: scaleDelta,
      anchorPoint: anchorPoint,
      notifyListener: false,
      notifyViewport: true,
    );
  }

  /// Seeds the gradient fill handles around [adjustedPosition] for the active
  /// linear or radial fill mode and commits the initial gradient action.
  void _initializeGradientFill(
    final AppProvider appProvider,
    final ui.Offset adjustedPosition, {
    required final bool sampleAllLayers,
  }) {
    appProvider.fillModel.sampleAllLayers = sampleAllLayers;
    if (appProvider.fillModel.mode == FillMode.linear) {
      appProvider.fillModel.addPoint(
        GradientPoint(
          offset: appProvider.fromCanvas(
            adjustedPosition + const Offset(-AppInteraction.linearFillHandleOffset, 0),
          ),
          color: appProvider.fillModel.gradientStopColors.first,
        ),
      );
      appProvider.fillModel.addPoint(
        GradientPoint(
          offset: appProvider.fromCanvas(
            adjustedPosition + const Offset(AppInteraction.linearFillHandleOffset, 0),
          ),
          color: appProvider.fillModel.gradientStopColors.last,
        ),
      );
    } else if (appProvider.fillModel.mode == FillMode.radial) {
      appProvider.fillModel.addPoint(
        GradientPoint(
          offset: appProvider.fromCanvas(adjustedPosition),
          color: appProvider.fillModel.gradientStopColors.first,
        ),
      );
      appProvider.fillModel.addPoint(
        GradientPoint(
          offset: appProvider.fromCanvas(
            adjustedPosition +
                const Offset(AppInteraction.radialFillHandleOffset, AppInteraction.radialFillHandleOffset),
          ),
          color: appProvider.fillModel.gradientStopColors.last,
        ),
      );
    }
    appProvider.fillModel.isVisible = true;
    appProvider.floodFillGradientAction(appProvider.fillModel);
    appProvider.update();
  }

  /// Returns whether the current keyboard state requests sampling from all visible layers.
  bool _isSampleAllLayersModifierPressed() {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    return keyboard.isControlPressed || keyboard.isMetaPressed;
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

  /// Updates the shell interaction modality based on the current pointer kind.
  void _registerInputModality(
    final ShellProvider shellProvider,
    final PointerDeviceKind kind,
  ) {
    switch (kind) {
      case PointerDeviceKind.touch:
        shellProvider.interactionInputModality = InteractionInputModality.touch;
        return;
      case PointerDeviceKind.stylus:
      case PointerDeviceKind.invertedStylus:
        shellProvider.interactionInputModality = InteractionInputModality.pen;
        return;
      case PointerDeviceKind.mouse:
      case PointerDeviceKind.trackpad:
      case PointerDeviceKind.unknown:
        shellProvider.interactionInputModality = InteractionInputModality.mouse;
        return;
    }
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

  /// Restores [selectorModel.math] to the value captured before a
  /// modifier-key override, then clears the saved value.
  void _restoreSelectionMath(final AppProvider appProvider) {
    if (_previousSelectorMath != null) {
      appProvider.selectorModel.math = _previousSelectorMath!;
      _previousSelectorMath = null;
      appProvider.repaintToolOptions();
    }
  }

  /// Returns whether the current tool should show a live size marker while drawing.
  bool _shouldShowDrawingToolPreview(final AppProvider appProvider) {
    return appProvider.selectedAction.isSupported(ActionOptions.brushSize) &&
        appProvider.selectedAction != ActionType.text;
  }

  void _showLockedLayerMessage(final AppProvider appProvider) {
    context.showSnackBarMessage(
      context.l10n.layerLockedForEditing(appProvider.layers.selectedLayer.name),
    );
  }

  /// Shows a text editor dialog at the given canvas [position].
  ///
  /// When the user finishes editing, the resulting [TextObject] is recorded
  /// as a drawing action on the currently selected layer.
  void _showTextDialog(final AppProvider appProvider, final Offset position) {
    final AppLocalizations l10n = context.l10n;
    showAppBottomSheet<void>(
      context: context,
      barrierColor: AppColors.transparent,
      builder: (final BuildContext _) {
        return TextEditorDialog(
          title: l10n.addText,
          submitLabel: l10n.addText,
          position: position,
          initialText: '',
          initialStyle: appProvider.textToolState.copy(),
          onSubmitted: (final TextObject textObject) {
            appProvider.adoptTextToolStateFromObject(textObject);
            appProvider.recordExecuteDrawingActionToSelectedLayer(
              action: UserActionDrawing(
                action: ActionType.text,
                positions: <ui.Offset>[position],
                textObject: textObject,
              ),
            );
          },
        );
      },
    );
  }

  /// Starts a brush/pencil/eraser or pixel-brush stroke at [adjustedPosition]
  /// for the active drawing tool.
  void _startDrawingPointer(
    final AppProvider appProvider,
    final ui.Offset adjustedPosition,
  ) {
    appProvider.layers.selectedLayer.isUserDrawing = true;

    if (appProvider.selectedAction == ActionType.smudge) {
      _startPixelBrushStroke(appProvider, adjustedPosition, PixelBrushMode.smudge);
      return;
    }

    if (appProvider.selectedAction == ActionType.blurBrush) {
      _startPixelBrushStroke(appProvider, adjustedPosition, PixelBrushMode.blur);
      return;
    }

    appProvider.recordExecuteDrawingActionToSelectedLayer(
      action: UserActionDrawing(
        action: appProvider.selectedAction,
        positions: <ui.Offset>[adjustedPosition, adjustedPosition],
        brush: MyBrush(
          color: appProvider.brushColor,
          size: appProvider.brushSize,
          style: appProvider.brushStyle,
        ),
        fillColor: appProvider.fillColor,
      ),
    );
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

  /// Returns whether [kind] can report hover location before pointer down.
  bool _supportsHoverPreview(final PointerDeviceKind kind) {
    return kind == PointerDeviceKind.mouse ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus;
  }

  /// Closes an in-progress line selection when two taps occur within the
  /// configured time and distance thresholds.
  bool _tryCloseStraightLineSelectionOnDoubleTap(
    final AppProvider appProvider,
    final PointerDownEvent event,
    final Offset canvasPosition,
  ) {
    if (appProvider.selectorModel.mode != SelectorMode.line || !appProvider.selectorModel.isDrawing) {
      return false;
    }

    final Duration eventTimestamp = event.timeStamp;
    final Duration? previousTimestamp = _lastSelectionTapTimestamp;
    final Offset? previousPosition = _lastSelectionTapCanvasPosition;
    final bool isDoubleTap =
        previousTimestamp != null &&
        previousPosition != null &&
        eventTimestamp - previousTimestamp <= AppInteraction.selectionDoubleTapTimeout &&
        (canvasPosition - previousPosition).distance <=
            AppInteraction.selectionDoubleTapSlop / appProvider.layers.scale;

    _lastSelectionTapTimestamp = eventTimestamp;
    _lastSelectionTapCanvasPosition = canvasPosition;

    if (!isDoubleTap) {
      return false;
    }

    final bool didClose = appProvider.selectorCreationClosePolygon();
    if (didClose) {
      _activePointerId = -1;
      _restoreSelectionMath(appProvider);
      _clearSelectionTapTracking();
    }
    return didClose;
  }

  /// Updates the live drawing marker to the current pointer location.
  void _updateDrawingToolPreview(
    final AppProvider appProvider,
    final Offset localPosition,
  ) {
    if (!_shouldShowDrawingToolPreview(appProvider)) {
      return;
    }

    appProvider.showDrawingToolPreviewAt(
      size: appProvider.brushSize,
      position: localPosition,
    );
  }
}
