import 'dart:ui' as ui;

import 'package:fpaint/models/user_action_drawing.dart';

/// Describes how a placed image should be committed.
enum ImagePlacementCommitMode {
  newLayer,
  replaceLayer,
}

/// Captures the original state of a layer while its content is floating.
class ImagePlacementLayerRestoreState {
  /// Creates an [ImagePlacementLayerRestoreState].
  const ImagePlacementLayerRestoreState({
    required this.layerIndex,
    required this.originalActions,
    required this.originalRedoActions,
    required this.originalHasChanged,
    required this.originalBackgroundColor,
  });

  /// The layer index that should receive the committed placement.
  final int layerIndex;

  /// The original action stack to restore on cancel or undo.
  final List<UserActionDrawing> originalActions;

  /// The original redo stack to restore on cancel or undo.
  final List<UserActionDrawing> originalRedoActions;

  /// Whether the source layer had unsaved changes.
  final bool originalHasChanged;

  /// The original layer background color.
  final ui.Color? originalBackgroundColor;
}
