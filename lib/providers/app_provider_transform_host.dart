part of 'app_provider.dart';

/// Adapts [AppProvider] to the narrow [TransformSessionHost] the transform
/// controller depends on.
///
/// Lives in the provider library so it can forward to the selection
/// extensions, which a class `implements` clause cannot satisfy.
class _AppTransformSessionHost implements TransformSessionHost {
  _AppTransformSessionHost(this._app);

  final AppProvider _app;

  @override
  LayersProvider get layers => _app.layers;

  @override
  SelectorModel get selectorModel => _app.selectorModel;

  @override
  bool get isSelectedLayerLocked => _app.isSelectedLayerLocked;

  @override
  void cancelEffectPreview() => _app.cancelEffectPreview();

  @override
  void activateSelectionAction() => _app.activateSelectionAction();

  @override
  void selectAll() => _app.selectAll();

  @override
  Future<ui.Image?> createSelectionImage() => _app.createSelectionImage();

  @override
  Future<void> startTransformAllLayers() => _app.startTransformAllLayers();

  @override
  Future<void> confirmTransformAllLayers() => _app.confirmTransformAllLayers();

  @override
  void commitPlacedImage({
    required ui.Image image,
    required Offset offset,
    required ImagePlacementCommitMode commitMode,
    required ImagePlacementLayerRestoreState? layerRestoreState,
    SelectionStateSnapshot? selectionSnapshot,
    Rect? selectionBounds,
  }) {
    _commitPlacedImage(
      _app,
      image: image,
      offset: offset,
      commitMode: commitMode,
      layerRestoreState: layerRestoreState,
      selectionSnapshot: selectionSnapshot,
      selectionBounds: selectionBounds,
    );
  }

  @override
  bool replaceRegion({
    required String name,
    required Path erasePath,
    required ui.Image replacement,
    required Offset offset,
  }) {
    return _app.replaceRegion(name: name, erasePath: erasePath, replacement: replacement, offset: offset);
  }

  @override
  void notifyLayerModifyModeChanged({required bool wasActive}) =>
      _app.notifyLayerModifyModeChanged(wasActive: wasActive);

  @override
  void update() => _app.update();
}
