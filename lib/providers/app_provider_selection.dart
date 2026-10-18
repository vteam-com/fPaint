part of 'app_provider.dart';

/// Selection, region, transform, effect, and crop operations.
extension AppProviderSelection on AppProvider {
  bool get _isSelectionToggleInCancelState {
    return selectedTool == ToolKind.selector || selectorModel.isVisible;
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

  /// Toggles [math] (add / remove) for the next selection: turning on one
  /// turns the other off, and tapping the active one returns to replace.
  void toggleSelectorMath(SelectorMath math) {
    setSelectorMath(selectorModel.math == math ? SelectorMath.replace : math);
  }

  /// Inverts the visible selection against the whole canvas.
  void invertSelection() {
    selectorModel.invert(
      Rect.fromLTWH(AppMath.zero.toDouble(), AppMath.zero.toDouble(), layers.size.width, layers.size.height),
    );
    update();
  }

  /// Switches to the selection tool in [mode]. Picking Edge Detection warms
  /// its source cache right away, so the first tap-and-drag is live rather
  /// than stalled on the first sample's layer render + readback.
  void activateSelectorMode(SelectorMode mode) {
    activateSelectionAction();
    setSelectorMode(mode);
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
        action: CutAction(path: Path.from(selectorModel.path1!)),
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
  Future<void> regionDuplicate() =>
      transformController.duplicateSelection(commitMode: ImagePlacementCommitMode.newLayer);

  /// Duplicates the current selection into the same selected layer.
  Future<void> regionDuplicateSameLayer() async {
    if (isSelectedLayerLocked) {
      return;
    }
    await transformController.duplicateSelection(commitMode: ImagePlacementCommitMode.selectedLayer);
  }

  /// Duplicates the current selection and applies an initial move offset to the
  /// new transform session without forcing translate mode to stay selected.
  Future<void> regionDuplicateMove(Offset offset, {bool onNewLayer = true}) =>
      transformController.duplicateSelectionMoved(offset, onNewLayer: onNewLayer);

  /// Floats the entire selected layer into a transform session before committing back.
  Future<void> modifySelectedLayer() => transformController.modifySelectedLayer();

  /// Pastes an image from the clipboard onto the canvas.
  Future<void> paste() async {
    final ui.Image? image = await getImageFromClipboard();
    if (image == null) {
      return;
    }
    await transformController.beginPaste(image);
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

    return this._clipLayerToSelection(
      layers.selectedLayer,
      selectionPath: selectorModel.path1!,
      bounds: bounds,
    );
  }

  /// Confirms the active layer-modify session, even during async startup handoff.
  Future<void> confirmLayerModifySession() => transformController.confirmLayerModifySession();

  /// Commits the interactively placed image using the active placement mode.
  Future<void> confirmImagePlacement() => transformController.confirmImagePlacement();

  /// Cancels an in-progress image placement.
  void cancelImagePlacement() => transformController.cancelImagePlacement();

  /// Cancels the active layer-modify session, even during async startup handoff.
  void cancelLayerModifySession() => transformController.cancelLayerModifySession();

  /// Begins a perspective/skew transform on the current selection.
  Future<void> startTransform() => transformController.startTransform();

  /// Commits the current transform; see [TransformSessionController.confirmTransform].
  Future<void> confirmTransform() => transformController.confirmTransform();

  /// Cancels an in-progress transform operation.
  void cancelTransform() => transformController.cancelTransform();

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

    this._executeLayerAppend(
      name: name,
      resolveTargets: this._selectedLayerTarget,
      buildActions: (_) => <UserActionDrawing>[
        CutAction(path: erasePath, erasesEntireLayer: erasesEntireLayer),
        ImageAction.placedAt(image: replacement, offset: offset),
      ],
    );

    return true;
  }

  /// Starts a selector creation.
  void selectorCreationStart(
    Offset position, {
    bool sampleAllLayers = false,
  }) => selectorGeometry.creationStart(position, sampleAllLayers: sampleAllLayers);

  /// Maps a horizontal screen drag [screenDx] from the wand sample anchor onto a
  /// tolerance, starting from [startTolerance]. Dragging right loosens (grows)
  /// the selection; dragging left tightens it.
  int wandToleranceForDrag(int startTolerance, double screenDx) =>
      selectorGeometry.wandToleranceForDrag(startTolerance, screenDx);

  /// Re-runs the Edge Detection wand selection at the fixed sample [position]
  /// using [tolerance]. Drives the live "tap to sample, drag to grow/shrink"
  /// gesture — each drag step resamples the same anchor at the new tolerance.
  void wandSelectionResampleAt(
    Offset position, {
    required int tolerance,
    required bool sampleAllLayers,
  }) => selectorGeometry.wandResampleAt(
    position,
    tolerance: tolerance,
    sampleAllLayers: sampleAllLayers,
  );

  /// Translates the active selection by [screenDelta], a screen-space offset.
  void selectionTranslateByScreenDelta(Offset screenDelta) => selectorGeometry.translateByScreenDelta(screenDelta);

  /// Scales the active selection uniformly by [factor].
  void selectionScaleUniform(double factor) => selectorGeometry.scaleUniform(factor);

  /// Resizes the active selection by dragging [handle] by [screenDelta].
  void selectionResize(NineGridHandle handle, Offset screenDelta) => selectorGeometry.resize(handle, screenDelta);

  /// Rotates the active selection by [angleRadians].
  void selectionRotate(double angleRadians) => selectorGeometry.rotate(angleRadians);

  /// Adds an additional point to the selector creation.
  void selectorCreationAdditionalPoint(Offset position) => selectorGeometry.creationAdditionalPoint(position);

  /// Updates the selector preview while a multi-click straight-line region is in progress.
  void selectorCreationPreview(Offset position) => selectorGeometry.creationPreview(position);

  /// Ends the selector creation.
  void selectorCreationEnd() => selectorGeometry.creationEnd();

  /// Closes an active straight-line region selection and commits it.
  bool selectorCreationClosePolygon() => selectorGeometry.creationClosePolygon();

  /// Ensures a selection exists. If no selection path is set, selects the
  /// entire canvas so that operations can treat the full layer as the target.
  void _ensureSelection() {
    if (selectorModel.path1 == null) {
      selectAll();
    }
  }

  /// Selects all.
  void selectAll() => selectorGeometry.selectAll();

  /// Gets the path adjusted to the canvas size and position.
  ///
  /// Uses the full viewport transform so the path still lands correctly when
  /// the view is rotated.
  Path? getPathAdjustToCanvasSizeAndPosition(Path? path) {
    if (path != null) {
      return path.transform(viewportTransform.matrix.storage);
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

        if (selectedTool != ToolKind.selector || selectorModel.mode != SelectorMode.wand) {
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
        updateWithToolOptions();
      }
    } finally {
      wandSelection.isInProgress = false;
    }
  }

  /// Returns cached wand source RGBA bytes, refreshing cache when signature changes.
  /// Samples either the selected layer only or all visible layers for the current request.
  Future<FillImageData?> getSelectedLayerFillImageData({
    required bool sampleAllLayers,
  }) => wandSourceSampler.sample(layers, sampleAllLayers: sampleAllLayers);
}
