part of 'layers_provider.dart';

/// Whole-canvas geometric transforms: 90° rotation and axis flips.
///
/// Separated from the layer-stack file because these are one cohesive
/// responsibility — rewriting every layer's geometry as one undoable step —
/// rather than part of owning the stack itself.
extension LayersProviderCanvasGeometry on LayersProvider {
  /// Rotates the entire canvas and all its layers 90 degrees clockwise.
  Future<void> rotateCanvas90Clockwise() async {
    final Size oldSize = Size(width, height);
    final Size newSize = Size(height, width); // Swapped dimensions

    // Need to capture the state of all layers for undo.
    // This is tricky because layer.rotate90Clockwise modifies actions in place.
    // For a true undo, we'd need to implement rotate90CounterClockwise or store/restore actionStacks.
    // For now, the backward action will rotate 3 more times to get back to original.

    await _undoProvider.executeActionAsync(
      name: 'Rotate Canvas 90° clock wise',
      forward: () async {
        final List<ui.Image> replaced = <ui.Image>[];
        for (final LayerProvider layer in _list) {
          replaced.addAll(await layer.rotate90Clockwise(oldSize));
          layer.size = newSize; // Update individual layer's understanding of canvas size
        }
        this.size = newSize; // Update LayersProvider's canvas size
        disposeCommittedImagesIfUnreferenced(replaced);
        this.update();
      },
      backward: () async {
        // Rotate 3 times to get back to the original orientation.
        // Each rotation needs the "current" old size before that specific rotation.
        Size currentOldSize = newSize; // Size before the first CCW rotation
        Size nextSize = oldSize; // Size after the first CCW rotation

        final List<ui.Image> replaced = <ui.Image>[];
        for (int i = 0; i < AppMath.triple; i++) {
          for (final LayerProvider layer in _list) {
            // Effectively rotating counter-clockwise by passing the "new" size as old,
            // because rotate90Clockwise expects the size *before* its CW rotation.
            replaced.addAll(await layer.rotate90Clockwise(currentOldSize));
            layer.size = nextSize;
          }
          this.size = nextSize;

          // Prepare for next rotation
          currentOldSize = this.size;
          nextSize = Size(currentOldSize.height, currentOldSize.width);
        }
        disposeCommittedImagesIfUnreferenced(replaced);
        this.update();
      },
    );
  }

  /// Flips the entire canvas and all its layers horizontally (left ↔ right).
  Future<void> flipCanvasHorizontal(String actionName) => _flipCanvas(isHorizontal: true, actionName: actionName);

  /// Flips the entire canvas and all its layers vertically (top ↔ bottom).
  Future<void> flipCanvasVertical(String actionName) => _flipCanvas(isHorizontal: false, actionName: actionName);

  /// Shared implementation for flipping all layers on one axis.
  Future<void> _flipCanvas({
    required bool isHorizontal,
    required String actionName,
  }) async {
    final Size canvasSize = Size(width, height);

    Future<void> applyFlip() async {
      final List<ui.Image> replaced = <ui.Image>[];
      for (final LayerProvider layer in _list) {
        if (isHorizontal) {
          replaced.addAll(await layer.flipHorizontal(canvasSize));
        } else {
          replaced.addAll(await layer.flipVertical(canvasSize));
        }
      }
      disposeCommittedImagesIfUnreferenced(replaced);
      this.update();
    }

    await _undoProvider.executeActionAsync(
      name: actionName,
      forward: applyFlip,
      backward: applyFlip,
    );
  }
}
