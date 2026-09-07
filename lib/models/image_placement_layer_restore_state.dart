import 'package:fpaint/models/layer_state_snapshot.dart';

/// Describes how a placed image should be committed.
enum ImagePlacementCommitMode {
  newLayer,
  selectedLayer,
  replaceLayer,
}

/// Captures the original state of a layer while its content is floating.
class ImagePlacementLayerRestoreState {
  /// Creates an [ImagePlacementLayerRestoreState].
  const ImagePlacementLayerRestoreState({
    required this.layerIndex,
    required this.layerState,
  });

  /// The layer index that should receive the committed placement.
  final int layerIndex;

  /// The layer's captured content state to restore on cancel or undo.
  final LayerStateSnapshot layerState;
}
