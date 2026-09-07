part of 'app_provider.dart';

/// Selection, region, transform, effect, and crop operations.
extension AppProviderSelection on AppProvider {
  bool get _isSelectionToggleInCancelState {
    return selectedAction == ActionType.selector || selectorModel.isVisible;
  }

  double get _straightLineRegionCloseDistance {
    return AppInteraction.selectionHandleSize / layers.scale;
  }

  /// Toggles selection overlay behavior from the FAB without coupling to tool state.
  void toggleSelectionOverlayFromFab() {
    if (_isSelectionToggleInCancelState) {
      clearSelectionAndRestorePreviousTool();
      return;
    }
    activateSelectionAction();
    prewarmWandSourceCache();
  }

  /// Warms the wand source-pixel cache (layer render + readback) as soon as Edge
  /// Detection becomes active, so the first tap-and-drag is responsive instead of
  /// stalling ~half a second while the first sample builds the cache. No-ops when
  /// the wand isn't active or the cache is already warm; safe to call repeatedly.
  void prewarmWandSourceCache() {
    if (!isWandSelectionActive) {
      return;
    }
    unawaited(getSelectedLayerFillImageData(sampleAllLayers: selectorModel.allLayers));
  }

  /// Erases a region on the canvas.
  void regionErase() {
    if (selectorModel.allLayers) {
      regionEraseAllLayers();
      return;
    }

    if (isSelectedLayerLocked) {
      return;
    }

    if (selectorModel.path1 != null) {
      recordExecuteDrawingActionToSelectedLayer(
        action: UserActionDrawing(
          action: ActionType.cut,
          positions: <ui.Offset>[],
          path: Path.from(selectorModel.path1!),
        ),
      );
      update();
    }
  }

  /// Cuts a region on the canvas.
  Future<void> regionCut() async {
    if (selectorModel.allLayers) {
      await regionCutAllLayers();
      return;
    }

    if (isSelectedLayerLocked) {
      return;
    }

    regionCopy();
    regionErase();
  }

  /// Copies a region on the canvas. With the "All layers" scope active the
  /// clipboard receives the merged visible composite instead of the selected
  /// layer's pixels.
  Future<void> regionCopy() async {
    final ui.Image? clippedImage = selectorModel.allLayers
        ? await createSelectionImageMerged()
        : await createSelectionImage();
    if (clippedImage == null) {
      return;
    }

    await copyImageToClipboard(clippedImage);
  }

  /// Duplicates the current selection without touching system clipboard data.
  Future<void> regionDuplicate() async {
    await _startDuplicateTransform(commitMode: ImagePlacementCommitMode.newLayer);
  }

  /// Duplicates the current selection into the same selected layer.
  Future<void> regionDuplicateSameLayer() async {
    if (isSelectedLayerLocked) {
      return;
    }

    await _startDuplicateTransform(commitMode: ImagePlacementCommitMode.selectedLayer);
  }

  /// Duplicates the current selection and applies an initial move offset to the
  /// new transform session without forcing translate mode to stay selected.
  Future<void> regionDuplicateMove(Offset offset, {bool onNewLayer = true}) async {
    if (onNewLayer) {
      await regionDuplicate();
    } else {
      await regionDuplicateSameLayer();
    }
    if (!transformModel.isVisible) {
      return;
    }

    transformModel.moveAll(offset);
    update();
  }

  /// Floats the entire selected layer into a transform session before committing back.
  Future<void> modifySelectedLayer() async {
    if (isSelectedLayerLocked) {
      return;
    }

    final bool wasLayerModifyMode = isLayerModifyMode;

    cancelEffectPreview();
    activateSelectionAction();
    selectAll();

    final ImagePlacementLayerRestoreState restoreState = _captureSelectedLayerRestoreState();

    imagePlacementModel.clear();
    imagePlacementModel.commitMode = ImagePlacementCommitMode.replaceLayer;
    imagePlacementModel.layerRestoreState = restoreState;
    notifyLayerModifyModeChanged(wasActive: wasLayerModifyMode);
    await startTransform();
  }

  /// Pastes an image from the clipboard onto the canvas.
  Future<void> paste() async {
    final ui.Image? image = await getImageFromClipboard();
    if (image == null) {
      return;
    }

    await _beginPreparedImageTransform(
      image,
      source: TransformSessionSource.clipboardPaste,
    );
  }

  /// Renders the active selection bounds into a standalone clipped image.
  ///
  /// When no selection exists the entire active layer is used as the
  /// implicit target (auto-select-all).
  ///
  /// Returns `null` when the computed selection bounds are empty.
  Future<ui.Image?> createSelectionImage() async {
    _ensureSelection();

    final ui.Rect bounds = selectorModel.path1!.getBounds();
    if (bounds.isEmpty) {
      return null;
    }

    final ui.Image image = layers.selectedLayer.toImageForStorage(layers.size);

    return renderCanvasImage(
      width: bounds.width.toInt(),
      height: bounds.height.toInt(),
      draw: (ui.Canvas canvas) {
        canvas.translate(-bounds.left, -bounds.top);
        canvas.clipPath(selectorModel.path1!);
        canvas.drawImage(image, Offset.zero, Paint());
      },
    );
  }

  /// Captures the selected layer so same-layer duplicate and layer modify undo
  /// can restore it exactly.
  ImagePlacementLayerRestoreState _captureSelectedLayerRestoreState() {
    return ImagePlacementLayerRestoreState(
      layerIndex: layers.selectedLayerIndex,
      layerState: layers.selectedLayer.captureSnapshot(),
    );
  }

  /// Prepares image placement state for follow-up transform or commit flows.
  void _prepareImagePlacement(
    ui.Image image, {
    Offset? initialPosition,
    ImagePlacementCommitMode commitMode = ImagePlacementCommitMode.newLayer,
    ImagePlacementLayerRestoreState? layerRestoreState,
  }) {
    final Offset center = Offset(
      layers.size.width / AppMath.pair,
      layers.size.height / AppMath.pair,
    );
    final Offset resolvedInitialPosition =
        initialPosition ??
        Offset(
          center.dx - image.width / AppMath.pair,
          center.dy - image.height / AppMath.pair,
        );

    imagePlacementModel.start(
      imageToPlace: image,
      initialPosition: resolvedInitialPosition,
      commitMode: commitMode,
      layerRestoreState: layerRestoreState,
    );
    update();
  }

  /// Starts a duplicate transform using [commitMode] for the eventual commit.
  Future<void> _startDuplicateTransform({
    required ImagePlacementCommitMode commitMode,
  }) async {
    final ui.Image? clippedImage = await createSelectionImage();
    final Path? selectionPath = selectorModel.path1;
    if (clippedImage == null || selectionPath == null) {
      return;
    }

    final ImagePlacementLayerRestoreState? layerRestoreState = commitMode == ImagePlacementCommitMode.selectedLayer
        ? _captureSelectedLayerRestoreState()
        : null;

    await _beginPreparedImageTransform(
      clippedImage,
      initialPosition: selectionPath.getBounds().topLeft,
      source: TransformSessionSource.duplicateSelection,
      commitMode: commitMode,
      layerRestoreState: layerRestoreState,
    );
  }

  /// Prepares [image] and immediately enters a transform session from it.
  Future<void> _beginPreparedImageTransform(
    ui.Image image, {
    required TransformSessionSource source,
    Offset? initialPosition,
    ImagePlacementCommitMode commitMode = ImagePlacementCommitMode.newLayer,
    ImagePlacementLayerRestoreState? layerRestoreState,
  }) async {
    _prepareImagePlacement(
      image,
      initialPosition: initialPosition,
      commitMode: commitMode,
      layerRestoreState: layerRestoreState,
    );
    await _startPreparedImageTransform(source: source);
  }

  /// Starts a transform session from [image] constrained to [bounds].
  void _startTransformSession({
    required ui.Image image,
    required Rect bounds,
    TransformSessionSource source = TransformSessionSource.selection,
  }) {
    transformModel.start(
      image: image,
      bounds: bounds,
      source: source,
    );
    update();
  }

  /// Starts a transform session from the prepared image placement state.
  Future<void> _startPreparedImageTransform({
    required TransformSessionSource source,
  }) async {
    final ui.Image? sourceImage = imagePlacementModel.image;
    if (sourceImage == null) {
      return;
    }

    final ui.Image bakedImage = await _renderPlacedImage(
      sourceImage: sourceImage,
      outWidth: imagePlacementModel.displayWidth,
      outHeight: imagePlacementModel.displayHeight,
      rotation: imagePlacementModel.rotation,
    );

    final Rect transformBounds = Rect.fromLTWH(
      imagePlacementModel.position.dx,
      imagePlacementModel.position.dy,
      bakedImage.width.toDouble(),
      bakedImage.height.toDouble(),
    );

    imagePlacementModel.isVisible = false;
    _startTransformSession(
      image: bakedImage,
      bounds: transformBounds,
      source: source,
    );
  }

  /// Confirms the active layer-modify session, even during async startup handoff.
  Future<void> confirmLayerModifySession() async {
    if (transformModel.isVisible) {
      await confirmTransform();
      return;
    }

    await confirmImagePlacement();
  }

  /// Commits the interactively placed image using the active placement mode.
  Future<void> confirmImagePlacement() async {
    final bool wasLayerModifyMode = isLayerModifyMode;
    final ui.Image? sourceImage = imagePlacementModel.image;
    if (sourceImage == null) {
      imagePlacementModel.clear();
      notifyLayerModifyModeChanged(wasActive: wasLayerModifyMode);
      update();
      return;
    }

    final double outWidth = imagePlacementModel.displayWidth;
    final double outHeight = imagePlacementModel.displayHeight;
    final double rotation = imagePlacementModel.rotation;
    final ImagePlacementCommitMode commitMode = imagePlacementModel.commitMode;
    final ImagePlacementLayerRestoreState? layerRestoreState = imagePlacementModel.layerRestoreState;

    final ui.Image bakedImage = await _renderPlacedImage(
      sourceImage: sourceImage,
      outWidth: outWidth,
      outHeight: outHeight,
      rotation: rotation,
    );

    final Offset offset = imagePlacementModel.position;
    commitPlacedImage(
      this,
      image: bakedImage,
      offset: offset,
      commitMode: commitMode,
      layerRestoreState: layerRestoreState,
    );

    imagePlacementModel.clear();
    notifyLayerModifyModeChanged(wasActive: wasLayerModifyMode);
    update();
  }

  /// Cancels an in-progress image placement.
  void cancelImagePlacement() {
    final bool wasLayerModifyMode = isLayerModifyMode;
    final ImagePlacementLayerRestoreState? layerRestoreState = imagePlacementModel.layerRestoreState;
    if (imagePlacementModel.commitMode == ImagePlacementCommitMode.replaceLayer && layerRestoreState != null) {
      final LayerProvider targetLayer = layers.get(layerRestoreState.layerIndex);
      layers.selectedLayerIndex = layerRestoreState.layerIndex;
      targetLayer.restoreFromSnapshot(layerRestoreState.layerState);
    }

    imagePlacementModel.clear();
    notifyLayerModifyModeChanged(wasActive: wasLayerModifyMode);
    update();
  }

  /// Cancels the active layer-modify session, even during async startup handoff.
  void cancelLayerModifySession() {
    if (transformModel.isVisible) {
      cancelTransform();
      return;
    }

    cancelImagePlacement();
  }

  /// Begins a perspective/skew transform on the current selection.
  Future<void> startTransform() async {
    // Layer-modify sessions always float the selected layer alone, even while
    // the "All layers" scope is active.
    if (selectorModel.allLayers && !isLayerModifyMode) {
      await startTransformAllLayers();
      return;
    }

    if (isSelectedLayerLocked) {
      return;
    }

    cancelEffectPreview();
    final ui.Image? clippedImage = await createSelectionImage();
    if (clippedImage == null || selectorModel.path1 == null) {
      return;
    }

    final Rect bounds = selectorModel.path1!.getBounds();
    if (bounds.width <= 0 || bounds.height <= 0) {
      return;
    }

    _startTransformSession(image: clippedImage, bounds: bounds);
  }

  /// Commits the current transform, erasing the original selection region
  /// and placing the warped result as a new image action. Dispatches on the
  /// [TransformSessionKind] so each session flavor owns its own commit path.
  Future<void> confirmTransform() async {
    final bool wasLayerModifyMode = isLayerModifyMode;
    cancelEffectPreview();
    final ui.Image? sourceImage = transformModel.sourceImage;
    if (sourceImage == null) {
      transformModel.clear();
      _endTransformSession(wasLayerModifyMode: wasLayerModifyMode);
      return;
    }

    switch (transformSession.kind) {
      case TransformSessionKind.crossLayer:
        await confirmTransformAllLayers();
        selectorModel.clear();
        transformModel.clear();
        // The merged overlay preview was never committed anywhere; free it.
        sourceImage.dispose();
      case TransformSessionKind.preparedImage:
        await _confirmPreparedImageTransform();
      case TransformSessionKind.layerModify:
      case TransformSessionKind.selection:
        await _confirmSelectionRegionTransform();
    }

    _endTransformSession(wasLayerModifyMode: wasLayerModifyMode);
  }

  /// Commits a duplicate/paste transform through the image-placement pipeline.
  Future<void> _confirmPreparedImageTransform() async {
    final ui.Image transformedImage = await _renderConfirmedTransformImage();
    final Rect quadBounds = transformModel.quadBounds;
    final SelectionStateSnapshot selectionSnapshot = captureSelectionState(this);

    commitPlacedImage(
      this,
      image: transformedImage,
      offset: Offset(quadBounds.left, quadBounds.top),
      commitMode: imagePlacementModel.commitMode,
      layerRestoreState: imagePlacementModel.layerRestoreState,
      selectionSnapshot: selectionSnapshot,
      selectionBounds: quadBounds,
    );

    transformModel.clear();
    imagePlacementModel.clear();
  }

  /// Commits a selection (or layer-modify) transform by erasing the original
  /// region and placing the warped result on the selected layer.
  Future<void> _confirmSelectionRegionTransform() async {
    final ui.Image transformedImage = await _renderConfirmedTransformImage();
    final Rect quadBounds = transformModel.quadBounds;
    final Path erasePath = Path.from(selectorModel.path1!);

    replaceRegion(
      name: 'Transform',
      erasePath: erasePath,
      replacement: transformedImage,
      offset: Offset(quadBounds.left, quadBounds.top),
    );

    selectorModel.clear();
    transformModel.clear();
    if (transformSession.isLayerModifyMode) {
      imagePlacementModel.clear();
    }
  }

  /// Renders the transform overlay's source image warped by the current corners.
  Future<ui.Image> _renderConfirmedTransformImage() {
    return renderTransformedImage(
      transformModel.sourceImage!,
      transformModel.corners,
      AppInteraction.transformGridSubdivisions,
      edgeMidpoints: transformModel.effectiveEdgeMidpoints,
    );
  }

  /// Shared transform-session epilogue: refresh layer-modify chrome and the app.
  void _endTransformSession({required bool wasLayerModifyMode}) {
    notifyLayerModifyModeChanged(wasActive: wasLayerModifyMode);
    update();
  }

  /// Cancels an in-progress transform operation, dispatching on the
  /// [TransformSessionKind] so each session flavor cleans up its own state.
  void cancelTransform() {
    final bool wasLayerModifyMode = isLayerModifyMode;
    cancelEffectPreview();

    switch (transformSession.kind) {
      case TransformSessionKind.crossLayer:
        final ui.Image? mergedPreview = transformModel.sourceImage;
        transformSession.disposeCrossLayerLift();
        transformModel.clear();
        mergedPreview?.dispose();
      case TransformSessionKind.preparedImage:
        transformModel.clear();
        imagePlacementModel.clear();
      case TransformSessionKind.layerModify:
        selectorModel.clear();
        transformModel.clear();
        imagePlacementModel.clear();
      case TransformSessionKind.selection:
        transformModel.clear();
    }

    _endTransformSession(wasLayerModifyMode: wasLayerModifyMode);
  }

  /// Renders the current image-placement preview into a baked image.
  Future<ui.Image> _renderPlacedImage({
    required ui.Image sourceImage,
    required double outWidth,
    required double outHeight,
    required double rotation,
  }) {
    return renderCanvasImage(
      width: outWidth.ceil(),
      height: outHeight.ceil(),
      draw: (ui.Canvas canvas) {
        canvas.translate(outWidth / AppMath.pair, outHeight / AppMath.pair);
        canvas.rotate(rotation);
        canvas.translate(-outWidth / AppMath.pair, -outHeight / AppMath.pair);
        canvas.drawImageRect(
          sourceImage,
          Rect.fromLTWH(
            0,
            0,
            sourceImage.width.toDouble(),
            sourceImage.height.toDouble(),
          ),
          Rect.fromLTWH(0, 0, outWidth, outHeight),
          Paint()..filterQuality = FilterQuality.high,
        );
      },
    );
  }

  /// Flips the selected region horizontally (left ↔ right).
  ///
  /// When no selection exists the entire active layer is used as the
  /// implicit target (auto-select-all).
  Future<void> flipSelectionHorizontal(String actionName) async {
    await _flipSelection(actionName, isHorizontal: true);
  }

  /// Flips the selected region vertically (top ↔ bottom).
  ///
  /// When no selection exists the entire active layer is used as the
  /// implicit target (auto-select-all).
  Future<void> flipSelectionVertical(String actionName) async {
    await _flipSelection(actionName, isHorizontal: false);
  }

  /// Shared implementation for selection-aware flipping.
  Future<void> _flipSelection(
    String actionName, {
    required bool isHorizontal,
  }) async {
    _ensureSelection();

    final ui.Image? clippedImage = await createSelectionImage();
    if (clippedImage == null) {
      return;
    }

    final Rect bounds = selectorModel.path1!.getBounds();
    final ui.Image flippedImage = await flipImage(
      clippedImage,
      isHorizontal: isHorizontal,
    );

    replaceRegion(
      name: actionName,
      erasePath: Path.from(selectorModel.path1!),
      replacement: flippedImage,
      offset: Offset(bounds.left, bounds.top),
    );

    update();
  }

  /// Rotates the selected region 90 degrees clockwise.
  ///
  /// The rotated image is centered within the original selection bounds.
  /// When no selection exists the entire active layer is used as the
  /// implicit target (auto-select-all).
  Future<void> rotateSelection90(String actionName) async {
    _ensureSelection();

    final ui.Image? clippedImage = await createSelectionImage();
    if (clippedImage == null) {
      return;
    }

    final Rect bounds = selectorModel.path1!.getBounds();
    final ui.Image rotatedImage = await rotateImage90(clippedImage);

    // The rotated image has swapped dimensions.  Center it within the
    // original selection bounds so the visual anchor stays consistent.
    final double dx = bounds.left + (bounds.width - rotatedImage.width) / AppMath.pair;
    final double dy = bounds.top + (bounds.height - rotatedImage.height) / AppMath.pair;

    replaceRegion(
      name: actionName,
      erasePath: Path.from(selectorModel.path1!),
      replacement: rotatedImage,
      offset: Offset(dx, dy),
    );

    update();
  }

  /// Erases [erasePath] from the selected layer and places [replacement] at
  /// [offset], wrapped in an undoable action named [name].
  ///
  /// Set [erasesEntireLayer] when [erasePath] covers the whole canvas, so the
  /// action stack can collapse the generations it hides.
  bool replaceRegion({
    required String name,
    required Path erasePath,
    required ui.Image replacement,
    required Offset offset,
    bool erasesEntireLayer = false,
  }) {
    if (isSelectedLayerLocked) {
      return false;
    }

    undoProvider.executeAction(
      name: name,
      forward: () {
        layers.selectedLayer.appendDrawingAction(
          UserActionDrawing(
            action: ActionType.cut,
            positions: <ui.Offset>[],
            path: erasePath,
            erasesEntireLayer: erasesEntireLayer,
          ),
        );
        layers.selectedLayer.addImage(
          imageToAdd: replacement,
          offset: offset,
        );
        update();
      },
      backward: () {
        layers.selectedLayer.undo(); // undo add image
        layers.selectedLayer.undo(); // undo cut
        update();
      },
    );

    return true;
  }

  /// Starts a selector creation.
  void selectorCreationStart(
    Offset position, {
    bool sampleAllLayers = false,
  }) {
    cancelEffectPreview();
    if (selectorModel.mode == SelectorMode.wand) {
      selectorModel.isDrawing = true;
      wandSelection.queueRequest(position: position, sampleAllLayers: sampleAllLayers);
      unawaited(_processPendingWandSelectionRequests());
      return;
    }

    if (selectorModel.mode == SelectorMode.line) {
      final bool isClosed = selectorModel.addStraightLineRegionPoint(
        position,
        closeDistance: _straightLineRegionCloseDistance,
      );
      selectorModel.isDrawing = !isClosed;
      if (isClosed) {
        selectorModel.applyMath();
      }
      repaintToolOptions();
      update();
      return;
    }

    selectorModel.isDrawing = true;
    selectorModel.addP1(position);
    repaintToolOptions();
    update();
  }

  /// Maps a horizontal screen drag [screenDx] from the wand sample anchor onto a
  /// tolerance, starting from [startTolerance]. Dragging right loosens (grows)
  /// the selection; dragging left tightens it.
  int wandToleranceForDrag(int startTolerance, double screenDx) {
    final int delta = (screenDx / AppInteraction.wandToleranceDragPixelsPerUnit).round();
    return (startTolerance + delta).clamp(AppMath.one, AppLimits.percentMax);
  }

  /// Re-runs the Edge Detection wand selection at the fixed sample [position]
  /// using [tolerance]. Drives the live "tap to sample, drag to grow/shrink"
  /// gesture — each drag step resamples the same anchor at the new tolerance.
  void wandSelectionResampleAt(
    Offset position, {
    required int tolerance,
    required bool sampleAllLayers,
  }) {
    if (selectorModel.mode != SelectorMode.wand) {
      return;
    }
    this.tolerance = tolerance;
    selectorModel.isDrawing = true;
    wandSelection.queueRequest(position: position, sampleAllLayers: sampleAllLayers);
    unawaited(_processPendingWandSelectionRequests());
  }

  /// Translates the active selection by [screenDelta], a screen-space offset.
  void selectionTranslateByScreenDelta(Offset screenDelta) {
    selectorModel.translate(screenDelta / layers.scale);
    repaintMainView();
  }

  /// Scales the active selection uniformly by [factor].
  void selectionScaleUniform(double factor) {
    selectorModel.scaleUniform(factor);
    repaintMainView();
  }

  /// Resizes the active selection by dragging [handle] by [screenDelta].
  void selectionResize(NineGridHandle handle, Offset screenDelta) {
    selectorModel.nindeGridResize(handle, screenDelta / layers.scale);
    repaintMainView();
  }

  /// Rotates the active selection by [angleRadians].
  void selectionRotate(double angleRadians) {
    selectorModel.rotate(angleRadians);
    repaintMainView();
  }

  /// Adds an additional point to the selector creation.
  void selectorCreationAdditionalPoint(Offset position) {
    if (selectorModel.mode == SelectorMode.wand) {
      // Ignore since the PointerDown already did the job
    } else if (selectorModel.mode == SelectorMode.line) {
      // Ignore since straight-line region selection commits only on clicks.
    } else {
      selectorModel.addP2(position);
      repaintMainView();
    }
  }

  /// Updates the selector preview while a multi-click straight-line region is in progress.
  void selectorCreationPreview(Offset position) {
    if (selectorModel.mode != SelectorMode.line || !selectorModel.isDrawing) {
      return;
    }

    selectorModel.updateStraightLineRegionPreview(
      position,
      closeDistance: _straightLineRegionCloseDistance,
    );
    repaintMainView();
  }

  /// Ends the selector creation.
  void selectorCreationEnd() {
    if (selectorModel.mode == SelectorMode.wand) {
      selectorModel.isDrawing = false;
      repaintToolOptions();
      update();
      return;
    }

    if (selectorModel.mode == SelectorMode.line) {
      return;
    }

    selectorModel.isDrawing = false;
    selectorModel.applyMath();
    repaintToolOptions();
    update();
  }

  /// Closes an active straight-line region selection and commits it.
  bool selectorCreationClosePolygon() {
    if (selectorModel.mode != SelectorMode.line || !selectorModel.isDrawing) {
      return false;
    }

    final bool isClosed = selectorModel.closeStraightLineRegion();
    if (!isClosed) {
      return false;
    }

    selectorModel.isDrawing = false;
    selectorModel.applyMath();
    repaintToolOptions();
    update();
    return true;
  }

  /// Ensures a selection exists. If no selection path is set, selects the
  /// entire canvas so that operations can treat the full layer as the target.
  void _ensureSelection() {
    if (selectorModel.path1 == null) {
      selectAll();
    }
  }

  /// Selects all.
  void selectAll() {
    cancelEffectPreview();
    wandSelection.cancelPendingRequest();
    selectorModel.isVisible = true;
    selectorModel.isDrawing = false;
    selectorModel.path1 = Path()
      ..addRect(
        Rect.fromPoints(Offset.zero, Offset(layers.width, layers.height)),
      );
    selectorModel.path2 = null;
    selectorModel.points.clear();
    selectorModel.math = SelectorMath.replace;
    repaintToolOptions();
    update();
  }

  /// Gets the path adjusted to the canvas size and position.
  Path? getPathAdjustToCanvasSizeAndPosition(Path? path) {
    if (path != null) {
      final Matrix4 matrix = Matrix4.identity()
        ..translateByVector3(Vector3(canvasOffset.dx, canvasOffset.dy, 0.0))
        ..scaleByVector3(Vector3(layers.scale, layers.scale, layers.scale));
      return path.transform(matrix.storage);
    }
    return null;
  }

  /// Gets the region path from a layer image.
  Future<FillRegion> getRegionPathFromLayerImage(
    ui.Offset position, {
    required bool sampleAllLayers,
  }) async {
    final FillImageData? imageData = await getSelectedLayerFillImageData(
      sampleAllLayers: sampleAllLayers,
    );
    if (imageData == null) {
      return FillRegion(path: Path(), offset: Offset.zero);
    }

    return fillService.getRegionPathFromImage(
      imageData: imageData,
      position: position,
      tolerance: tolerance,
    );
  }

  /// Processes queued wand requests in order while applying only the latest valid result.
  Future<void> _processPendingWandSelectionRequests() async {
    if (wandSelection.isInProgress) {
      return;
    }

    wandSelection.isInProgress = true;
    try {
      while (wandSelection.hasPendingRequest) {
        final WandSelectionRequest request = wandSelection.takePendingRequest()!;

        final FillRegion region = await getRegionPathFromLayerImage(
          request.position,
          sampleAllLayers: request.sampleAllLayers,
        );

        if (request.version != wandSelection.requestVersion) {
          continue;
        }

        if (selectedAction != ActionType.selector || selectorModel.mode != SelectorMode.wand) {
          continue;
        }

        selectorModel.isVisible = true;
        if (selectorModel.math == SelectorMath.replace) {
          selectorModel.path1 = region.path.shift(region.offset);
        } else {
          selectorModel.path2 = region.path.shift(region.offset);
        }
        selectorModel.isDrawing = false;
        selectorModel.applyMath();
        repaintToolOptions();
        update();
      }
    } finally {
      wandSelection.isInProgress = false;
    }
  }

  /// Returns cached wand source RGBA bytes, refreshing cache when signature changes.
  /// Samples either the selected layer only or all visible layers for the current request.
  Future<FillImageData?> getSelectedLayerFillImageData({
    required bool sampleAllLayers,
  }) async {
    final int signature = _createSelectedLayerFloodSourceSignature(
      sampleAllLayers: sampleAllLayers,
    );
    final FillImageData? cached = wandSelection.cachedImageData(signature);
    if (cached != null) {
      return cached;
    }

    final int canvasWidth = layers.width.toInt();
    final int canvasHeight = layers.height.toInt();
    final int longestSide = canvasWidth > canvasHeight ? canvasWidth : canvasHeight;
    final double sourceScale = longestSide > AppLimits.floodFillSourceMaxDimension
        ? AppLimits.floodFillSourceMaxDimension / longestSide
        : AppVisual.full;
    final int sourceWidth = (canvasWidth * sourceScale).round().clamp(AppMath.one, canvasWidth);
    final int sourceHeight = (canvasHeight * sourceScale).round().clamp(AppMath.one, canvasHeight);
    final double sourceScaleX = sourceWidth / canvasWidth;
    final double sourceScaleY = sourceHeight / canvasHeight;

    final ui.Image image = await renderCanvasImage(
      width: sourceWidth,
      height: sourceHeight,
      draw: (ui.Canvas canvas) {
        canvas.scale(sourceScaleX, sourceScaleY);
        if (sampleAllLayers) {
          for (final LayerProvider layer in layers.list.reversed) {
            if (layer.isVisible) {
              layer.renderLayer(canvas, compositeBounds: Offset.zero & layers.size);
            }
          }
          return;
        }
        layers.selectedLayer.renderLayer(
          canvas,
          compositeBounds: Offset.zero & layers.size,
        );
      },
    );

    try {
      final Uint8List? pixels = await convertImageToUint8List(image);
      if (pixels == null) {
        return null;
      }

      wandSelection.storeCache(
        signature: signature,
        pixels: pixels,
        width: image.width,
        height: image.height,
        canvasScaleX: sourceScaleX,
        canvasScaleY: sourceScaleY,
      );

      return FillImageData(
        pixels: pixels,
        width: image.width,
        height: image.height,
        canvasScaleX: sourceScaleX,
        canvasScaleY: sourceScaleY,
      );
    } finally {
      image.dispose();
    }
  }

  /// Creates a stable fingerprint for wand source cache invalidation.
  /// Includes the sampling mode in the signature.
  int _createSelectedLayerFloodSourceSignature({
    required bool sampleAllLayers,
  }) {
    if (sampleAllLayers) {
      return Object.hash(
        layers,
        layers.width.toInt(),
        layers.height.toInt(),
        sampleAllLayers,
        layers.list
            .map(
              (LayerProvider l) => Object.hash(
                l,
                l.actionStack.length,
                l.redoStack.length,
                l.lastUserAction,
                l.isVisible,
              ),
            )
            .toList(),
      );
    }

    final LayerProvider layer = layers.selectedLayer;
    return Object.hash(
      layer,
      layers.selectedLayerIndex,
      layers.width.toInt(),
      layers.height.toInt(),
      layer.actionStack.length,
      layer.redoStack.length,
      layer.lastUserAction,
      sampleAllLayers,
    );
  }
}
