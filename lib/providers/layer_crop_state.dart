import 'dart:ui' show Color, Image;

import 'package:fpaint/models/user_action_drawing.dart';

/// Captured per-layer state for a crop operation.
///
/// Bundles the undo snapshot needed to reverse the crop together with the images
/// produced for the new canvas size, replacing the parallel per-layer maps the
/// crop routine used to thread through several loops.
class LayerCropState {
  LayerCropState({
    required this.originalActions,
    required this.originalRedoActions,
    required this.originalHasChanged,
    required this.originalBackgroundColor,
    required this.croppedImage,
  });

  /// Snapshot of the layer's action stack before cropping.
  final List<UserActionDrawing> originalActions;

  /// Snapshot of the layer's redo stack before cropping.
  final List<UserActionDrawing> originalRedoActions;

  /// Whether the layer had unsaved changes before cropping.
  final bool originalHasChanged;

  /// The layer's background color before cropping, if any.
  final Color? originalBackgroundColor;

  /// The layer cropped to the selection bounds, before trimming to content.
  final Image croppedImage;

  /// The layer cropped to the final content bounds; set once those are known.
  late final Image finalImage;
}
