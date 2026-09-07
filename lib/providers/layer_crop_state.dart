import 'dart:ui' show Image;

import 'package:fpaint/models/layer_state_snapshot.dart';

/// Captured per-layer state for a crop operation.
///
/// Bundles the undo snapshot needed to reverse the crop together with the images
/// produced for the new canvas size, replacing the parallel per-layer maps the
/// crop routine used to thread through several loops.
class LayerCropState {
  LayerCropState({
    required this.layerState,
    required this.croppedImage,
  });

  /// Snapshot of the layer's content state before cropping.
  final LayerStateSnapshot layerState;

  /// The layer cropped to the selection bounds, before trimming to content.
  final Image croppedImage;

  /// The layer cropped to the final content bounds; set once those are known.
  late final Image finalImage;
}
