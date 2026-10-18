import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/transform_helper.dart';
import 'package:fpaint/models/image_placement_layer_restore_state.dart';
import 'package:fpaint/models/image_placement_model.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/transform_model.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/transform_session.dart';
import 'package:fpaint/providers/transform_session_host.dart';

/// Undo-history name of a committed selection transform.
const String _transformRecordName = 'Transform';

/// Runs floating transform/placement sessions: duplicate, paste, layer modify
/// and perspective transform — starting them, and confirming or cancelling
/// them per [TransformSessionKind].
///
/// [TransformSession] owns the session's state; this controller owns its
/// behaviour and reaches the editor only through [TransformSessionHost], so
/// the session flow no longer lives on the app-wide provider (Single
/// Responsibility, Dependency Inversion).
class TransformSessionController {
  TransformSessionController(this._host, this._session);

  final TransformSessionHost _host;
  final TransformSession _session;

  LayersProvider get _layers => _host.layers;

  SelectorModel get _selector => _host.selectorModel;

  ImagePlacementModel get _placement => _session.imagePlacementModel;

  TransformModel get _transform => _session.transformModel;

  /// Floats the selection as a duplicate that commits per [commitMode].
  Future<void> duplicateSelection({required ImagePlacementCommitMode commitMode}) async {
    final ui.Image? clippedImage = await _host.createSelectionImage();
    final Path? selectionPath = _selector.path1;
    if (clippedImage == null || selectionPath == null) {
      return;
    }

    final ImagePlacementLayerRestoreState? layerRestoreState = commitMode == ImagePlacementCommitMode.selectedLayer
        ? _layers.captureSelectedLayerRestoreState()
        : null;

    await _beginPreparedImageTransform(
      clippedImage,
      initialPosition: selectionPath.getBounds().topLeft,
      source: TransformSessionSource.duplicateSelection,
      commitMode: commitMode,
      layerRestoreState: layerRestoreState,
    );
  }

  /// Duplicates the selection and moves the new session by [offset].
  Future<void> duplicateSelectionMoved(Offset offset, {required bool onNewLayer}) async {
    if (!onNewLayer && _host.isSelectedLayerLocked) {
      return;
    }
    await duplicateSelection(
      commitMode: onNewLayer ? ImagePlacementCommitMode.newLayer : ImagePlacementCommitMode.selectedLayer,
    );
    if (!_transform.isVisible) {
      return;
    }

    _transform.moveAll(offset);
    _host.update();
  }

  /// Floats the entire selected layer into a transform session that replaces
  /// the layer on commit.
  Future<void> modifySelectedLayer() async {
    if (_host.isSelectedLayerLocked) {
      return;
    }

    final bool wasLayerModifyMode = _session.isLayerModifyMode;

    _host.cancelEffectPreview();
    _host.activateSelectionAction();
    _host.selectAll();

    final ImagePlacementLayerRestoreState restoreState = _layers.captureSelectedLayerRestoreState();

    _placement.clear();
    _placement.commitMode = ImagePlacementCommitMode.replaceLayer;
    _placement.layerRestoreState = restoreState;
    _host.notifyLayerModifyModeChanged(wasActive: wasLayerModifyMode);
    await startTransform();
  }

  /// Places a pasted [image] and enters a transform session from it.
  Future<void> beginPaste(ui.Image image) {
    return _beginPreparedImageTransform(image, source: TransformSessionSource.clipboardPaste);
  }

  /// Starts a transform session from [image] constrained to [bounds].
  void startSession({
    required ui.Image image,
    required Rect bounds,
    TransformSessionSource source = TransformSessionSource.selection,
  }) {
    _transform.start(
      image: image,
      bounds: bounds,
      source: source,
    );
    _host.update();
  }

  /// Begins a perspective/skew transform on the current selection.
  Future<void> startTransform() async {
    // Layer-modify sessions always float the selected layer alone, even while
    // the "All layers" scope is active.
    if (_selector.allLayers && !_session.isLayerModifyMode) {
      await _host.startTransformAllLayers();
      return;
    }

    if (_host.isSelectedLayerLocked) {
      return;
    }

    _host.cancelEffectPreview();
    final ui.Image? clippedImage = await _host.createSelectionImage();
    if (clippedImage == null || _selector.path1 == null) {
      return;
    }

    final Rect bounds = _selector.path1!.getBounds();
    if (bounds.width <= 0 || bounds.height <= 0) {
      return;
    }

    startSession(image: clippedImage, bounds: bounds);
  }

  /// Commits the current transform. Dispatches on [TransformSessionKind] so
  /// each session flavor owns its own commit path.
  Future<void> confirmTransform() async {
    final bool wasLayerModifyMode = _session.isLayerModifyMode;
    _host.cancelEffectPreview();
    final ui.Image? sourceImage = _transform.sourceImage;
    if (sourceImage == null) {
      _transform.clear();
      _endSession(wasLayerModifyMode: wasLayerModifyMode);
      return;
    }

    switch (_session.kind) {
      case TransformSessionKind.crossLayer:
        await _host.confirmTransformAllLayers();
        _selector.clear();
        _transform.clear();
        // The merged overlay preview was never committed anywhere; free it.
        sourceImage.dispose();
      case TransformSessionKind.preparedImage:
        await _confirmPreparedImageTransform();
      case TransformSessionKind.layerModify:
      case TransformSessionKind.selection:
        await _confirmSelectionRegionTransform();
    }

    _endSession(wasLayerModifyMode: wasLayerModifyMode);
  }

  /// Cancels the active transform, dispatching on [TransformSessionKind] so
  /// each session flavor cleans up its own state.
  void cancelTransform() {
    final bool wasLayerModifyMode = _session.isLayerModifyMode;
    _host.cancelEffectPreview();

    switch (_session.kind) {
      case TransformSessionKind.crossLayer:
        final ui.Image? mergedPreview = _transform.sourceImage;
        _session.disposeCrossLayerLift();
        _transform.clear();
        mergedPreview?.dispose();
      case TransformSessionKind.preparedImage:
        _transform.clear();
        _placement.clear();
      case TransformSessionKind.layerModify:
        _selector.clear();
        _transform.clear();
        _placement.clear();
      case TransformSessionKind.selection:
        _transform.clear();
    }

    _endSession(wasLayerModifyMode: wasLayerModifyMode);
  }

  /// Commits the interactively placed image using the active placement mode.
  Future<void> confirmImagePlacement() async {
    final bool wasLayerModifyMode = _session.isLayerModifyMode;
    final ui.Image? sourceImage = _placement.image;
    if (sourceImage == null) {
      _placement.clear();
      _endSession(wasLayerModifyMode: wasLayerModifyMode);
      return;
    }

    final ImagePlacementCommitMode commitMode = _placement.commitMode;
    final ImagePlacementLayerRestoreState? layerRestoreState = _placement.layerRestoreState;
    final ui.Image bakedImage = await _bakePlacement(sourceImage);

    _host.commitPlacedImage(
      image: bakedImage,
      offset: _placement.position,
      commitMode: commitMode,
      layerRestoreState: layerRestoreState,
    );

    _placement.clear();
    _endSession(wasLayerModifyMode: wasLayerModifyMode);
  }

  /// Cancels an in-progress image placement, restoring a replaced layer.
  void cancelImagePlacement() {
    final bool wasLayerModifyMode = _session.isLayerModifyMode;
    final ImagePlacementLayerRestoreState? layerRestoreState = _placement.layerRestoreState;
    if (_placement.commitMode == ImagePlacementCommitMode.replaceLayer && layerRestoreState != null) {
      final LayerProvider targetLayer = _layers.get(layerRestoreState.layerIndex);
      _layers.selectedLayerIndex = layerRestoreState.layerIndex;
      targetLayer.restoreFromSnapshot(layerRestoreState.layerState);
    }

    _placement.clear();
    _endSession(wasLayerModifyMode: wasLayerModifyMode);
  }

  /// Confirms the active layer-modify session, even during async startup
  /// handoff (before its transform overlay is up).
  Future<void> confirmLayerModifySession() {
    return _transform.isVisible ? confirmTransform() : confirmImagePlacement();
  }

  /// Cancels the active layer-modify session, even during async startup
  /// handoff (before its transform overlay is up).
  void cancelLayerModifySession() {
    if (_transform.isVisible) {
      cancelTransform();
    } else {
      cancelImagePlacement();
    }
  }

  /// Prepares [image] and immediately enters a transform session from it.
  Future<void> _beginPreparedImageTransform(
    ui.Image image, {
    required TransformSessionSource source,
    Offset? initialPosition,
    ImagePlacementCommitMode commitMode = ImagePlacementCommitMode.newLayer,
    ImagePlacementLayerRestoreState? layerRestoreState,
  }) async {
    _preparePlacement(
      image,
      initialPosition: initialPosition,
      commitMode: commitMode,
      layerRestoreState: layerRestoreState,
    );
    final ui.Image? sourceImage = _placement.image;
    if (sourceImage == null) {
      return;
    }

    final ui.Image bakedImage = await _bakePlacement(sourceImage);
    _placement.isVisible = false;
    startSession(
      image: bakedImage,
      bounds: Rect.fromLTWH(
        _placement.position.dx,
        _placement.position.dy,
        bakedImage.width.toDouble(),
        bakedImage.height.toDouble(),
      ),
      source: source,
    );
  }

  /// Prepares image placement state for a follow-up transform or commit.
  void _preparePlacement(
    ui.Image image, {
    Offset? initialPosition,
    ImagePlacementCommitMode commitMode = ImagePlacementCommitMode.newLayer,
    ImagePlacementLayerRestoreState? layerRestoreState,
  }) {
    // An image from outside the document has no relationship to this canvas's
    // size — a Retina screenshot is routinely several times wider than the
    // default 1024x768. Placed at 1:1 and centred, it would start mostly off
    // canvas with its transform handles out of reach, reading as "paste did
    // nothing". Shrink it to fit so the whole thing is visible and grabbable;
    // the session still starts in transform, so the user can scale it back up.
    // Only ever scales down: an image that already fits is placed untouched.
    final double initialScale = _fitToCanvasScale(image);
    final double displayWidth = image.width * initialScale;
    final double displayHeight = image.height * initialScale;

    final Offset center = Offset(
      _layers.size.width / AppMath.pair,
      _layers.size.height / AppMath.pair,
    );
    final Offset resolvedInitialPosition =
        initialPosition ??
        Offset(
          center.dx - displayWidth / AppMath.pair,
          center.dy - displayHeight / AppMath.pair,
        );

    _placement.start(
      imageToPlace: image,
      initialPosition: resolvedInitialPosition,
      commitMode: commitMode,
      layerRestoreState: layerRestoreState,
    );
    _placement.scale = initialScale;
    _host.update();
  }

  /// The scale that fits [image] inside the canvas, never above 1.
  ///
  /// Returns 1 when the image already fits, so a paste that needs no help is
  /// placed at its true pixel size.
  double _fitToCanvasScale(ui.Image image) {
    final double canvasWidth = _layers.size.width;
    final double canvasHeight = _layers.size.height;
    if (image.width <= canvasWidth && image.height <= canvasHeight) {
      return AppMath.one.toDouble();
    }
    if (image.width <= 0 || image.height <= 0) {
      return AppMath.one.toDouble();
    }
    return min(canvasWidth / image.width, canvasHeight / image.height);
  }

  /// Renders the placed [sourceImage] at its current display size and rotation.
  Future<ui.Image> _bakePlacement(ui.Image sourceImage) {
    return renderPlacedImage(
      sourceImage: sourceImage,
      outWidth: _placement.displayWidth,
      outHeight: _placement.displayHeight,
      rotation: _placement.rotation,
    );
  }

  /// Commits a duplicate/paste transform through the image-placement pipeline.
  Future<void> _confirmPreparedImageTransform() async {
    final ui.Image transformedImage = await _renderConfirmedTransformImage();
    final Rect quadBounds = _transform.quadBounds;

    _host.commitPlacedImage(
      image: transformedImage,
      offset: Offset(quadBounds.left, quadBounds.top),
      commitMode: _placement.commitMode,
      layerRestoreState: _placement.layerRestoreState,
      selectionSnapshot: _selector.snapshot(),
      selectionBounds: quadBounds,
    );

    _transform.clear();
    _placement.clear();
  }

  /// Commits a selection (or layer-modify) transform by erasing the original
  /// region and placing the warped result on the selected layer.
  Future<void> _confirmSelectionRegionTransform() async {
    final ui.Image transformedImage = await _renderConfirmedTransformImage();
    final Rect quadBounds = _transform.quadBounds;

    _host.replaceRegion(
      name: _transformRecordName,
      erasePath: Path.from(_selector.path1!),
      replacement: transformedImage,
      offset: Offset(quadBounds.left, quadBounds.top),
    );

    _selector.clear();
    _transform.clear();
    if (_session.isLayerModifyMode) {
      _placement.clear();
    }
  }

  /// Renders the overlay's source image warped by the current corners.
  Future<ui.Image> _renderConfirmedTransformImage() {
    return renderTransformedImage(
      _transform.sourceImage!,
      _transform.corners,
      AppInteraction.transformGridSubdivisions,
      edgeMidpoints: _transform.effectiveEdgeMidpoints,
    );
  }

  /// Shared session epilogue: refresh layer-modify chrome and the app.
  void _endSession({required bool wasLayerModifyMode}) {
    _host.notifyLayerModifyModeChanged(wasActive: wasLayerModifyMode);
    _host.update();
  }
}
