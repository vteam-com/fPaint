part of 'layers_provider.dart';

/// Undoable layer-stack edits.
///
/// The raw list mutators on [LayersProvider] ([LayersProvider.remove],
/// [LayersProvider.insert]) record nothing; user-facing commands go through
/// these so every stack change lands in the shared undo history.
extension LayersProviderLayerCommands on LayersProvider {
  /// Inserts a new empty layer above the selected one and selects it, as one
  /// undo entry named [undoName]. Undo removes it and restores the selection.
  void addLayerAbove({required String undoName}) {
    final int currentIndex = selectedLayerIndex;

    undoProvider.executeAction(
      name: undoName,
      forward: () {
        final LayerProvider newLayer = insertAt(currentIndex);
        selectedLayerIndex = getLayerIndex(newLayer);
      },
      backward: () {
        removeByIndex(currentIndex);
        selectedLayerIndex = currentIndex;
      },
    );
  }

  /// Removes [layer] from the stack as one undo entry named [undoName].
  ///
  /// Undo re-inserts the same instance at its original index, content
  /// intact, and restores the selection. The layer's textures are listed as
  /// retained images so they stay alive while the record can still bring the
  /// layer back, and are freed once it leaves history. Returns false,
  /// recording nothing, when [layer] is not in the stack.
  bool deleteLayer(LayerProvider layer, {required String undoName}) {
    final int index = getLayerIndex(layer);
    if (index < AppMath.zero) {
      return false;
    }
    final int selectedIndexBefore = selectedLayerIndex;

    undoProvider.executeAction(
      name: undoName,
      retainedImages: LayerStateSnapshot.imagesOf(layer.actionStack.followedBy(layer.redoStack)),
      forward: () {
        remove(layer);
        update();
      },
      backward: () {
        insert(index, layer);
        selectedLayerIndex = selectedIndexBefore;
        update();
      },
    );
    return true;
  }
}
