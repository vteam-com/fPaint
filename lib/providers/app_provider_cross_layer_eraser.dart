part of 'app_provider.dart';

/// Owns an in-progress "All layers" eraser stroke: the layers it erases and
/// the single stroke action they all share.
///
/// Every target layer appends the *same* [StrokeAction] instance, so growing
/// its positions once extends the erase on every layer, and each layer's own
/// freehand-stroke preview renders the shared tail live.
class CrossLayerEraserStroke {
  /// Visible, unlocked layers the active stroke erases (empty when idle).
  final List<LayerProvider> targets = <LayerProvider>[];

  /// The stroke shared by every target layer, or null when idle.
  StrokeAction? action;

  /// Whether a cross-layer eraser stroke is in progress.
  bool get isActive => action != null;
}

/// Eraser strokes under the sticky "All layers" scope
/// ([SelectorModel.allLayers]): one stroke erases every visible, unlocked
/// layer as a single undo entry, leaving locked and hidden layers untouched.
extension AppProviderCrossLayerEraser on AppProvider {
  /// Whether an eraser stroke should erase across all layers right now.
  bool get isCrossLayerEraserScope => selectorModel.allLayers && !isLayerModifyMode;

  /// Whether at least one layer is visible and unlocked for a cross-layer erase.
  bool get hasCrossLayerEditTargets => _crossLayerEditTargets.isNotEmpty;

  /// Starts an eraser stroke at [position] on every visible, unlocked layer.
  /// Returns false (and records nothing) when no layer can be erased or an
  /// async undo replay is in flight.
  bool startCrossLayerEraserStroke(Offset position) {
    final List<LayerProvider> targets = _crossLayerEditTargets;
    if (targets.isEmpty || undoProvider.isReplaying) {
      return false;
    }

    final StrokeAction action = StrokeAction(
      action: ActionType.eraser,
      positions: <Offset>[position, position],
      brush: MyBrush(color: brushColor, size: brushSize, style: brushStyle),
      fillColor: fillColor,
      clipPath: selectorModel.isVisible ? selectorModel.path1 : null,
    );

    final CrossLayerEraserStroke stroke = crossLayerEraser;
    stroke.targets
      ..clear()
      ..addAll(targets);
    stroke.action = action;

    // Freeze each layer's committed composite before the shared action lands,
    // so every target composites baseline + live tail per frame.
    for (final LayerProvider layer in targets) {
      layer.isUserDrawing = true;
      layer.beginStrokePreview();
    }

    undoProvider.executeAction(
      name: ActionType.eraser.name,
      forward: () {
        for (final LayerProvider layer in targets) {
          layer.appendDrawingAction(action);
        }
      },
      backward: () {
        for (final LayerProvider layer in targets.reversed) {
          layer.undo();
        }
      },
    );

    layers.update();
    return true;
  }

  /// Extends the active cross-layer eraser stroke to [position].
  void extendCrossLayerEraserStroke(Offset position) {
    final StrokeAction? action = crossLayerEraser.action;
    if (action == null) {
      return;
    }
    // The positions list is shared by every target layer's action stack.
    action.positions.add(position);
    layers.repaintCanvas();
  }

  /// Ends the active cross-layer eraser stroke, releasing every target's
  /// frozen stroke baseline. A no-op when no such stroke is active.
  void endCrossLayerEraserStroke() {
    final CrossLayerEraserStroke stroke = crossLayerEraser;
    if (!stroke.isActive) {
      return;
    }
    for (final LayerProvider layer in stroke.targets) {
      layer.isUserDrawing = false;
      layer.clearStrokePreview();
      // The stroke grew after the append-time invalidation; re-render the
      // committed raster and thumbnail from the final shared positions.
      layer.clearCache();
    }
    stroke.targets.clear();
    stroke.action = null;
    layers.update();
  }
}
