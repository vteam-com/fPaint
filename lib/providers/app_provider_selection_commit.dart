import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/models/image_placement_layer_restore_state.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/providers/app_provider.dart';

typedef SelectionStateSnapshot = ({
  bool isVisible,
  bool isDrawing,
  Path? path1,
  Path? path2,
  List<Offset> points,
  SelectorMath math,
});

/// Captures the current selection state so duplicate-apply undo can restore it.
SelectionStateSnapshot captureSelectionState(final AppProvider appProvider) {
  return (
    isVisible: appProvider.selectorModel.isVisible,
    isDrawing: appProvider.selectorModel.isDrawing,
    path1: appProvider.selectorModel.path1 == null ? null : Path.from(appProvider.selectorModel.path1!),
    path2: appProvider.selectorModel.path2 == null ? null : Path.from(appProvider.selectorModel.path2!),
    points: List<Offset>.from(appProvider.selectorModel.points),
    math: appProvider.selectorModel.math,
  );
}

/// Restores a previously captured selection state.
void restoreSelectionState(
  final AppProvider appProvider,
  final SelectionStateSnapshot selectionSnapshot,
) {
  appProvider.selectorModel.isVisible = selectionSnapshot.isVisible;
  appProvider.selectorModel.isDrawing = selectionSnapshot.isDrawing;
  appProvider.selectorModel.path1 = selectionSnapshot.path1 == null ? null : Path.from(selectionSnapshot.path1!);
  appProvider.selectorModel.path2 = selectionSnapshot.path2 == null ? null : Path.from(selectionSnapshot.path2!);
  appProvider.selectorModel.points
    ..clear()
    ..addAll(selectionSnapshot.points);
  appProvider.selectorModel.math = selectionSnapshot.math;
}

/// Replaces the active selection with a rectangle matching [bounds].
void selectRectOnCanvas(final AppProvider appProvider, final Rect bounds) {
  appProvider.selectorModel.isVisible = true;
  appProvider.selectorModel.isDrawing = false;
  appProvider.selectorModel.path1 = Path()..addRect(bounds);
  appProvider.selectorModel.path2 = null;
  appProvider.selectorModel.points.clear();
  appProvider.selectorModel.math = SelectorMath.replace;
}

/// Commits a placed image as a new layer or layer replacement with undo support.
void commitPlacedImage(
  final AppProvider appProvider, {
  required final ui.Image image,
  required final Offset offset,
  required final ImagePlacementCommitMode commitMode,
  required final ImagePlacementLayerRestoreState? layerRestoreState,
  final SelectionStateSnapshot? selectionSnapshot,
  final Rect? selectionBounds,
}) {
  final int currentIndex = appProvider.layers.selectedLayerIndex;
  int newLayerIndex = -1;

  appProvider.undoProvider.executeAction(
    name: 'Paste',
    forward: () {
      if (commitMode == ImagePlacementCommitMode.replaceLayer && layerRestoreState != null) {
        final LayerProvider targetLayer = appProvider.layers.get(layerRestoreState.layerIndex);
        appProvider.layers.selectedLayerIndex = layerRestoreState.layerIndex;
        targetLayer.actionStack.clear();
        targetLayer.redoStack.clear();
        targetLayer.backgroundColor = null;
        targetLayer.addImage(imageToAdd: image, offset: offset);
        targetLayer.hasChanged = true;
        targetLayer.clearCache();
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
      if (commitMode == ImagePlacementCommitMode.replaceLayer && layerRestoreState != null) {
        final LayerProvider targetLayer = appProvider.layers.get(layerRestoreState.layerIndex);
        appProvider.layers.selectedLayerIndex = layerRestoreState.layerIndex;
        targetLayer.actionStack
          ..clear()
          ..addAll(layerRestoreState.originalActions);
        targetLayer.redoStack
          ..clear()
          ..addAll(layerRestoreState.originalRedoActions);
        targetLayer.backgroundColor = layerRestoreState.originalBackgroundColor;
        targetLayer.hasChanged = layerRestoreState.originalHasChanged;
        targetLayer.clearCache();
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
