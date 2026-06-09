import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/transform_helper.dart';
import 'package:fpaint/models/image_placement_layer_restore_state.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/transform_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_selection_commit.dart';
import 'package:fpaint/providers/fill_service.dart';
import 'package:vector_math/vector_math_64.dart';

part 'app_provider_selection_effects.dart';
part 'app_provider_selection_crop.dart';

/// Selection, region, transform, effect, and crop operations.
extension AppProviderSelection on AppProvider {
  double get _straightLineRegionCloseDistance {
    return AppInteraction.selectionHandleSize / layers.scale;
  }

  /// Toggles selection overlay behavior from the FAB without coupling to tool state.
  void toggleSelectionOverlayFromFab() {
    if (selectorModel.isVisible) {
      clearSelectionAndRestorePreviousTool();
      return;
    }
    activateSelectionAction();
  }

  /// Erases a region on the canvas.
  void regionErase() {
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
    if (isSelectedLayerLocked) {
      return;
    }

    regionCopy();
    regionErase();
  }

  /// Copies a region on the canvas.
  Future<void> regionCopy() async {
    final ui.Image? clippedImage = await createSelectionImage();
    if (clippedImage == null) {
      return;
    }

    await copyImageToClipboard(clippedImage);
  }

  /// Duplicates the current selection without touching system clipboard data.
  Future<void> regionDuplicate() async {
    await _startDuplicateTransform(commitMode: ImagePlacementCommitMode.newLayer);
  }

  /// Captures the selected layer so destructive tools can restore it on undo.
  ImagePlacementLayerRestoreState captureSelectedLayerRestoreState() {
    return _captureSelectedLayerRestoreState();
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
  Future<void> regionDuplicateMove(final Offset offset, {final bool onNewLayer = true}) async {
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
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    canvas.translate(-bounds.left, -bounds.top);
    canvas.clipPath(selectorModel.path1!);
    canvas.drawImage(image, Offset.zero, Paint());

    return recorder.endRecording().toImage(
      bounds.width.toInt(),
      bounds.height.toInt(),
    );
  }

  /// Captures the selected layer so same-layer duplicate and layer modify undo
  /// can restore it exactly.
  ImagePlacementLayerRestoreState _captureSelectedLayerRestoreState() {
    final LayerProvider targetLayer = layers.selectedLayer;
    return ImagePlacementLayerRestoreState(
      layerIndex: layers.selectedLayerIndex,
      originalActions: List<UserActionDrawing>.from(targetLayer.actionStack),
      originalRedoActions: List<UserActionDrawing>.from(targetLayer.redoStack),
      originalHasChanged: targetLayer.hasChanged,
      originalBackgroundColor: targetLayer.backgroundColor,
      originalBlendMode: targetLayer.blendMode,
      originalOpacity: targetLayer.opacity,
    );
  }

  /// Prepares image placement state for follow-up transform or commit flows.
  void _prepareImagePlacement(
    final ui.Image image, {
    final Offset? initialPosition,
    final ImagePlacementCommitMode commitMode = ImagePlacementCommitMode.newLayer,
    final ImagePlacementLayerRestoreState? layerRestoreState,
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
    required final ImagePlacementCommitMode commitMode,
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
    final ui.Image image, {
    required final TransformSessionSource source,
    final Offset? initialPosition,
    final ImagePlacementCommitMode commitMode = ImagePlacementCommitMode.newLayer,
    final ImagePlacementLayerRestoreState? layerRestoreState,
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
    required final ui.Image image,
    required final Rect bounds,
    final TransformSessionSource source = TransformSessionSource.selection,
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
    required final TransformSessionSource source,
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
      targetLayer.actionStack
        ..clear()
        ..addAll(layerRestoreState.originalActions);
      targetLayer.redoStack
        ..clear()
        ..addAll(layerRestoreState.originalRedoActions);
      targetLayer.backgroundColor = layerRestoreState.originalBackgroundColor;
      targetLayer.hasChanged = layerRestoreState.originalHasChanged;
      targetLayer.clearCache();
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
  /// and placing the warped result as a new image action.
  Future<void> confirmTransform() async {
    final bool wasLayerModifyMode = isLayerModifyMode;
    cancelEffectPreview();
    final ui.Image? sourceImage = transformModel.sourceImage;
    if (sourceImage == null) {
      transformModel.clear();
      notifyLayerModifyModeChanged(wasActive: wasLayerModifyMode);
      update();
      return;
    }

    final ui.Image transformedImage = await renderTransformedImage(
      sourceImage,
      transformModel.corners,
      AppInteraction.transformGridSubdivisions,
      edgeMidpoints: transformModel.effectiveEdgeMidpoints,
    );

    final Rect quadBounds = transformModel.quadBounds;

    if (_isPreparedImageTransformSource(transformModel.source)) {
      final SelectionStateSnapshot selectionSnapshot = captureSelectionState(this);
      final ImagePlacementCommitMode commitMode = imagePlacementModel.commitMode;
      final ImagePlacementLayerRestoreState? layerRestoreState = imagePlacementModel.layerRestoreState;

      commitPlacedImage(
        this,
        image: transformedImage,
        offset: Offset(quadBounds.left, quadBounds.top),
        commitMode: commitMode,
        layerRestoreState: layerRestoreState,
        selectionSnapshot: selectionSnapshot,
        selectionBounds: quadBounds,
      );

      transformModel.clear();
      imagePlacementModel.clear();
      notifyLayerModifyModeChanged(wasActive: wasLayerModifyMode);
      update();
      return;
    }

    final Path erasePath = Path.from(selectorModel.path1!);
    final Offset imageOffset = Offset(quadBounds.left, quadBounds.top);

    replaceRegion(
      name: 'Transform',
      erasePath: erasePath,
      replacement: transformedImage,
      offset: imageOffset,
    );

    selectorModel.clear();
    transformModel.clear();
    if (_isLayerModifySession) {
      imagePlacementModel.clear();
    }
    notifyLayerModifyModeChanged(wasActive: wasLayerModifyMode);
    update();
  }

  /// Cancels an in-progress transform operation.
  void cancelTransform() {
    final bool wasLayerModifyMode = isLayerModifyMode;
    cancelEffectPreview();

    if (_isPreparedImageTransformSource(transformModel.source)) {
      transformModel.clear();
      imagePlacementModel.clear();
      notifyLayerModifyModeChanged(wasActive: wasLayerModifyMode);
      update();
      return;
    }

    if (_isLayerModifySession) {
      selectorModel.clear();
      transformModel.clear();
      imagePlacementModel.clear();
      notifyLayerModifyModeChanged(wasActive: wasLayerModifyMode);
      update();
      return;
    }

    transformModel.clear();
    update();
  }

  bool get _isLayerModifySession => isLayerModifyMode;

  bool _isPreparedImageTransformSource(final TransformSessionSource source) {
    return source == TransformSessionSource.duplicateSelection || source == TransformSessionSource.clipboardPaste;
  }

  /// Renders the current image-placement preview into a baked image.
  Future<ui.Image> _renderPlacedImage({
    required final ui.Image sourceImage,
    required final double outWidth,
    required final double outHeight,
    required final double rotation,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

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

    return recorder.endRecording().toImage(outWidth.ceil(), outHeight.ceil());
  }

  /// Flips the selected region horizontally (left ↔ right).
  ///
  /// When no selection exists the entire active layer is used as the
  /// implicit target (auto-select-all).
  Future<void> flipSelectionHorizontal(final String actionName) async {
    await _flipSelection(actionName, isHorizontal: true);
  }

  /// Flips the selected region vertically (top ↔ bottom).
  ///
  /// When no selection exists the entire active layer is used as the
  /// implicit target (auto-select-all).
  Future<void> flipSelectionVertical(final String actionName) async {
    await _flipSelection(actionName, isHorizontal: false);
  }

  /// Shared implementation for selection-aware flipping.
  Future<void> _flipSelection(
    final String actionName, {
    required final bool isHorizontal,
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
  Future<void> rotateSelection90(final String actionName) async {
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
  bool replaceRegion({
    required final String name,
    required final Path erasePath,
    required final ui.Image replacement,
    required final Offset offset,
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
    final Offset position, {
    final bool sampleAllLayers = false,
  }) {
    cancelEffectPreview();
    if (selectorModel.mode == SelectorMode.wand) {
      selectorModel.isDrawing = true;
      wandSelectionRequestVersion += AppMath.one;
      pendingWandSelectionPosition = position;
      pendingWandSelectionSampleAllLayers = sampleAllLayers;
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

  /// Adds an additional point to the selector creation.
  void selectorCreationAdditionalPoint(final Offset position) {
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
  void selectorCreationPreview(final Offset position) {
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
    wandSelectionRequestVersion += AppMath.one;
    pendingWandSelectionPosition = null;
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
  Path? getPathAdjustToCanvasSizeAndPosition(final Path? path) {
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
    final ui.Offset position, {
    required final bool sampleAllLayers,
  }) async {
    final FillImageData? imageData = await _getSelectedLayerFillImageData(
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
    if (isWandSelectionInProgress) {
      return;
    }

    isWandSelectionInProgress = true;
    try {
      while (pendingWandSelectionPosition != null) {
        final Offset requestPosition = pendingWandSelectionPosition!;
        final bool requestSampleAllLayers = pendingWandSelectionSampleAllLayers;
        final int requestVersion = wandSelectionRequestVersion;
        pendingWandSelectionPosition = null;
        pendingWandSelectionSampleAllLayers = false;

        final FillRegion region = await getRegionPathFromLayerImage(
          requestPosition,
          sampleAllLayers: requestSampleAllLayers,
        );

        if (requestVersion != wandSelectionRequestVersion) {
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
      isWandSelectionInProgress = false;
    }
  }

  /// Returns cached wand source RGBA bytes, refreshing cache when signature changes.
  /// Samples either the selected layer only or all visible layers for the current request.
  Future<FillImageData?> _getSelectedLayerFillImageData({
    required final bool sampleAllLayers,
  }) async {
    final int signature = _createSelectedLayerFloodSourceSignature(
      sampleAllLayers: sampleAllLayers,
    );
    if (signature == cachedWandSourceSignature &&
        cachedWandSourcePixels != null &&
        cachedWandSourceWidth > AppMath.zero &&
        cachedWandSourceHeight > AppMath.zero) {
      return FillImageData(
        pixels: cachedWandSourcePixels!,
        width: cachedWandSourceWidth,
        height: cachedWandSourceHeight,
      );
    }

    final bool ownsImage = !sampleAllLayers;
    final ui.Image image = sampleAllLayers
        ? layers.cachedImage ?? await layers.capturePainterToImage()
        : layers.selectedLayer.toImageForStorage(layers.size);

    try {
      final Uint8List? pixels = await convertImageToUint8List(image);
      if (pixels == null) {
        return null;
      }

      cachedWandSourceSignature = signature;
      cachedWandSourcePixels = pixels;
      cachedWandSourceWidth = image.width;
      cachedWandSourceHeight = image.height;

      return FillImageData(
        pixels: pixels,
        width: image.width,
        height: image.height,
      );
    } finally {
      if (ownsImage) {
        image.dispose();
      }
    }
  }

  /// Creates a stable fingerprint for wand source cache invalidation.
  /// Includes the sampling mode in the signature.
  int _createSelectedLayerFloodSourceSignature({
    required final bool sampleAllLayers,
  }) {
    if (sampleAllLayers) {
      return Object.hash(
        layers,
        layers.width.toInt(),
        layers.height.toInt(),
        sampleAllLayers,
        layers.list
            .map(
              (final LayerProvider l) => Object.hash(
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
