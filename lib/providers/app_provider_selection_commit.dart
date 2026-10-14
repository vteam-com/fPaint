part of 'app_provider.dart';

/// Captures the current selection state so duplicate-apply undo can restore it.
SelectionStateSnapshot captureSelectionState(AppProvider appProvider) {
  return appProvider.selectorModel.snapshot();
}

/// Restores a previously captured selection state.
void restoreSelectionState(
  AppProvider appProvider,
  SelectionStateSnapshot selectionSnapshot,
) {
  appProvider.selectorModel.restore(selectionSnapshot);
  appProvider.repaintToolOptions();
}

/// Replaces the active selection with a rectangle matching [bounds].
void selectRectOnCanvas(AppProvider appProvider, Rect bounds) {
  appProvider.selectorModel.replacePath(Path()..addRect(bounds));
  appProvider.repaintToolOptions();
}

/// Commits a placed image as a new layer, selected-layer append, or layer
/// replacement with undo support.
void commitPlacedImage(
  AppProvider appProvider, {
  required ui.Image image,
  required Offset offset,
  required ImagePlacementCommitMode commitMode,
  required ImagePlacementLayerRestoreState? layerRestoreState,
  SelectionStateSnapshot? selectionSnapshot,
  Rect? selectionBounds,
}) {
  final int currentIndex = appProvider.layers.selectedLayerIndex;
  int newLayerIndex = -1;

  if (commitMode != ImagePlacementCommitMode.newLayer && layerRestoreState != null) {
    final LayerProvider targetLayer = appProvider.layers.get(layerRestoreState.layerIndex);
    if (targetLayer.isLocked) {
      appProvider.update();
      return;
    }
  }

  appProvider.undoProvider.executeAction(
    name: 'Paste',
    forward: () {
      if (commitMode == ImagePlacementCommitMode.replaceLayer && layerRestoreState != null) {
        final LayerProvider targetLayer = appProvider.layers.get(layerRestoreState.layerIndex);
        appProvider.layers.selectedLayerIndex = layerRestoreState.layerIndex;
        targetLayer.replaceContentWithImage(image, offset: offset);
        if (selectionBounds != null) {
          selectRectOnCanvas(appProvider, selectionBounds);
        }
        appProvider.update();
        return;
      }

      if (commitMode == ImagePlacementCommitMode.selectedLayer && layerRestoreState != null) {
        final LayerProvider targetLayer = appProvider.layers.get(layerRestoreState.layerIndex);
        appProvider.layers.selectedLayerIndex = layerRestoreState.layerIndex;
        targetLayer.redoStack.clear();
        targetLayer.addImage(imageToAdd: image, offset: offset);
        if (selectionBounds != null) {
          selectRectOnCanvas(appProvider, selectionBounds);
        }
        appProvider.update();
        return;
      }

      final LayerProvider newLayer = appProvider.layers.addTop(name: 'Pasted');
      newLayerIndex = appProvider.layers.getLayerIndex(newLayer);
      newLayer.addImage(imageToAdd: image, offset: offset);
      if (selectionBounds != null) {
        selectRectOnCanvas(appProvider, selectionBounds);
      }
      appProvider.update();
    },
    backward: () {
      if (commitMode != ImagePlacementCommitMode.newLayer && layerRestoreState != null) {
        final LayerProvider targetLayer = appProvider.layers.get(layerRestoreState.layerIndex);
        appProvider.layers.selectedLayerIndex = layerRestoreState.layerIndex;
        targetLayer.restoreFromSnapshot(layerRestoreState.layerState);
        if (selectionSnapshot != null) {
          restoreSelectionState(appProvider, selectionSnapshot);
        }
        appProvider.update();
        return;
      }

      appProvider.layers.removeByIndex(newLayerIndex);
      appProvider.layers.selectedLayerIndex = currentIndex;
      if (selectionSnapshot != null) {
        restoreSelectionState(appProvider, selectionSnapshot);
      }
      appProvider.update();
    },
  );
}
