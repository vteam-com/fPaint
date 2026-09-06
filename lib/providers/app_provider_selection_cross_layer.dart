part of 'app_provider.dart';

/// One layer's lifted selection content during an "All layers" transform
/// session: the pixels clipped from [layer], sized to the selection bounds.
class CrossLayerLiftEntry {
  CrossLayerLiftEntry({
    required this.layer,
    required this.image,
  });

  /// The layer the lifted content came from and commits back onto.
  final LayerProvider layer;

  /// The layer's pixels clipped to the selection, selection-bounds sized.
  final ui.Image image;
}

/// Cross-layer ("All layers") selection scope: the wand samples the merged
/// composite, and transform/cut/copy act on every visible, unlocked layer
/// instead of only the selected one — each layer keeps its own content, so
/// moving a shape that spans several layers preserves the layer structure.
extension AppProviderSelectionCrossLayer on AppProvider {
  /// Layers a cross-layer edit writes to: visible and unlocked, top-first.
  List<LayerProvider> get _crossLayerEditTargets {
    return layers.list.where((LayerProvider layer) => layer.isVisible && !layer.isLocked).toList();
  }

  /// Whether the active transform session lifted content from all layers.
  bool get isCrossLayerTransformActive => crossLayerLift != null;

  /// Sets the sticky "All layers" selection scope and re-warms the wand
  /// source cache so the first sample under the new scope is responsive.
  void setSelectorAllLayers(bool value) {
    if (selectorModel.allLayers == value) {
      return;
    }
    selectorModel.allLayers = value;
    prewarmWandSourceCache();
    repaintToolOptions();
    update();
  }

  /// Renders the current selection clipped from the merged visible composite
  /// (the flattened pixels the user sees), for cross-layer copy.
  ///
  /// When no selection exists the entire canvas is used as the implicit
  /// target (auto-select-all). Returns `null` for empty selection bounds.
  Future<ui.Image?> createSelectionImageMerged() async {
    _ensureSelection();

    final ui.Rect bounds = selectorModel.path1!.getBounds();
    if (bounds.isEmpty) {
      return null;
    }

    // Prime every visible layer's raster first so renderLayer takes the
    // one-blit fast path instead of replaying each action stack (the same
    // trick capturePainterToImage uses).
    await Future.wait(
      layers.list
          .where((LayerProvider layer) => layer.isVisible)
          .map((LayerProvider layer) => layer.ensureCachePrimed()),
    );

    return renderCanvasImage(
      width: bounds.width.toInt(),
      height: bounds.height.toInt(),
      draw: (ui.Canvas canvas) {
        canvas.translate(-bounds.left, -bounds.top);
        canvas.clipPath(selectorModel.path1!);
        for (final LayerProvider layer in layers.list.reversed) {
          if (layer.isVisible) {
            layer.renderLayer(canvas, compositeBounds: Offset.zero & layers.size);
          }
        }
      },
    );
  }

  /// Copies the merged visible composite within the selection to the clipboard.
  Future<void> regionCopyMerged() async {
    final ui.Image? clippedImage = await createSelectionImageMerged();
    if (clippedImage == null) {
      return;
    }

    await copyImageToClipboard(clippedImage);
  }

  /// Erases the selection from every visible, unlocked layer as one undo entry.
  bool regionEraseAllLayers() {
    final ui.Path? selectionPath = selectorModel.path1;
    if (selectionPath == null) {
      return false;
    }

    final List<LayerProvider> targets = _crossLayerEditTargets;
    if (targets.isEmpty) {
      return false;
    }

    undoProvider.executeAction(
      name: ActionType.cut.name,
      forward: () {
        for (final LayerProvider layer in targets) {
          layer.appendDrawingAction(
            UserActionDrawing(
              action: ActionType.cut,
              positions: <ui.Offset>[],
              path: Path.from(selectionPath),
            ),
          );
        }
        update();
      },
      backward: () {
        for (final LayerProvider layer in targets.reversed) {
          layer.undo();
        }
        update();
      },
    );

    return true;
  }

  /// Cuts across all layers: copies the merged composite, then erases the
  /// region from every visible, unlocked layer.
  Future<void> regionCutAllLayers() async {
    await regionCopyMerged();
    regionEraseAllLayers();
  }

  /// Begins a transform that lifts the selection from every visible, unlocked
  /// layer. The overlay shows one merged preview; commit warps each layer's
  /// lifted content back onto its own layer so layer structure is preserved.
  Future<void> startTransformAllLayers() async {
    cancelEffectPreview();
    _ensureSelection();

    final ui.Path? selectionPath = selectorModel.path1;
    if (selectionPath == null) {
      return;
    }

    final Rect bounds = selectionPath.getBounds();
    if (bounds.width <= 0 || bounds.height <= 0) {
      return;
    }

    final List<LayerProvider> targets = _crossLayerEditTargets;
    if (targets.isEmpty) {
      return;
    }

    final List<CrossLayerLiftEntry> lift = <CrossLayerLiftEntry>[];
    for (final LayerProvider layer in targets) {
      lift.add(
        CrossLayerLiftEntry(
          layer: layer,
          image: await _clipLayerToSelection(
            layer,
            selectionPath: selectionPath,
            bounds: bounds,
          ),
        ),
      );
    }

    // The merged preview drives the (single-image) transform overlay; the
    // per-layer lifts are what actually commit.
    final ui.Image preview = await renderCanvasImage(
      width: bounds.width.toInt(),
      height: bounds.height.toInt(),
      draw: (ui.Canvas canvas) {
        for (final CrossLayerLiftEntry entry in lift.reversed) {
          canvas.drawImage(entry.image, Offset.zero, Paint());
        }
      },
    );

    crossLayerLift = lift;
    _startTransformSession(image: preview, bounds: bounds);
  }

  /// Commits an all-layers transform: warps each layer's lifted content, then
  /// erases the original region and places the warped result on each touched
  /// layer, all wrapped in one undo entry.
  Future<void> confirmTransformAllLayers() async {
    final List<CrossLayerLiftEntry> lift = crossLayerLift!;
    crossLayerLift = null;

    final Rect quadBounds = transformModel.quadBounds;
    final Offset imageOffset = Offset(quadBounds.left, quadBounds.top);
    final ui.Path selectionPath = Path.from(selectorModel.path1!);

    final List<ui.Image> warpedImages = <ui.Image>[];
    for (final CrossLayerLiftEntry entry in lift) {
      warpedImages.add(
        await renderTransformedImage(
          entry.image,
          transformModel.corners,
          AppInteraction.transformGridSubdivisions,
          edgeMidpoints: transformModel.effectiveEdgeMidpoints,
        ),
      );
      // The warp has rasterized from the lifted texture; the engine ref-counts
      // it for the pending raster, so the intermediate can be freed now.
      entry.image.dispose();
    }

    undoProvider.executeAction(
      name: 'Transform',
      // The warped textures are re-added by forward on redo; retaining them
      // defers disposal until the record leaves history (crop's protocol).
      retainedImages: warpedImages,
      forward: () {
        for (int i = 0; i < lift.length; i++) {
          lift[i].layer.appendDrawingAction(
            UserActionDrawing(
              action: ActionType.cut,
              positions: <ui.Offset>[],
              path: Path.from(selectionPath),
            ),
          );
          lift[i].layer.addImage(
            imageToAdd: warpedImages[i],
            offset: imageOffset,
          );
        }
        update();
      },
      backward: () {
        for (final CrossLayerLiftEntry entry in lift.reversed) {
          entry.layer.undo(); // undo add image
          entry.layer.undo(); // undo cut
        }
        update();
      },
    );
  }

  /// Releases the lifted per-layer textures when a cross-layer transform
  /// session ends without committing.
  void disposeCrossLayerLift() {
    final List<CrossLayerLiftEntry>? lift = crossLayerLift;
    if (lift == null) {
      return;
    }
    crossLayerLift = null;
    for (final CrossLayerLiftEntry entry in lift) {
      entry.image.dispose();
    }
  }

  /// Clips [layer] to [selectionPath] into a selection-bounds sized image.
  Future<ui.Image> _clipLayerToSelection(
    LayerProvider layer, {
    required ui.Path selectionPath,
    required Rect bounds,
  }) async {
    final ui.Image layerImage = layer.toImageForStorage(layers.size);

    final ui.Image clipped = await renderCanvasImage(
      width: bounds.width.toInt(),
      height: bounds.height.toInt(),
      draw: (ui.Canvas canvas) {
        canvas.translate(-bounds.left, -bounds.top);
        canvas.clipPath(selectionPath);
        canvas.drawImage(layerImage, Offset.zero, Paint());
      },
    );
    // clipped is fully rasterized (awaited), so the full-canvas source raster
    // is no longer needed — release it instead of stranding a texture per layer.
    layerImage.dispose();

    return clipped;
  }
}
