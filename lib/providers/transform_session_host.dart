import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/models/image_placement_layer_restore_state.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/providers/layers_provider.dart';

/// The editor context a transform/placement session needs from its host.
///
/// A narrow interface rather than the whole app provider: the controller
/// depends on this abstraction (Dependency Inversion), which keeps the session
/// flow separate from the provider's other jobs.
abstract interface class TransformSessionHost {
  /// The document whose layers are lifted from and committed to.
  LayersProvider get layers;

  /// The selection a session floats.
  SelectorModel get selectorModel;

  /// Whether the selected layer refuses edits.
  bool get isSelectedLayerLocked;

  /// Cancels any live effect preview before the selection is floated.
  void cancelEffectPreview();

  /// Switches to the selection tool.
  void activateSelectionAction();

  /// Selects the whole canvas.
  void selectAll();

  /// Clips the selection (or the whole layer) into a standalone image.
  Future<ui.Image?> createSelectionImage();

  /// Lifts the selection from every visible, unlocked layer into a session.
  Future<void> startTransformAllLayers();

  /// Commits an "All layers" session back onto each lifted layer.
  Future<void> confirmTransformAllLayers();

  /// Commits [image] at [offset] as one undoable placement.
  void commitPlacedImage({
    required ui.Image image,
    required Offset offset,
    required ImagePlacementCommitMode commitMode,
    required ImagePlacementLayerRestoreState? layerRestoreState,
    SelectionStateSnapshot? selectionSnapshot,
    Rect? selectionBounds,
  });

  /// Erases [erasePath] on the selected layer and places [replacement] at
  /// [offset] as one undo entry named [name].
  bool replaceRegion({
    required String name,
    required Path erasePath,
    required ui.Image replacement,
    required Offset offset,
  });

  /// Rebuilds layer-modify chrome when that mode toggled from [wasActive].
  void notifyLayerModifyModeChanged({required bool wasActive});

  /// Notifies provider listeners.
  void update();
}
