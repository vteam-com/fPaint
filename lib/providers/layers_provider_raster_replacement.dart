part of 'layers_provider.dart';

/// One undoable whole-document raster swap (crop, image resize): the canvas
/// size before and after, every layer's pre-edit snapshot, and the new raster
/// for each layer that receives one.
///
/// Callers wrap [apply]/[revert] in their own undo record (crop records
/// synchronously, resize asynchronously) and list [retainedImages] on it so
/// no texture either direction can resurrect is freed while the record lives.
class LayerRasterReplacement {
  const LayerRasterReplacement({
    required this.oldSize,
    required this.newSize,
    required this.snapshots,
    required this.images,
  });

  /// The canvas size [revert] restores.
  final ui.Size oldSize;

  /// The canvas size [apply] installs.
  final ui.Size newSize;

  /// Every layer's state before the edit, restored by [revert].
  final Map<LayerProvider, LayerStateSnapshot> snapshots;

  /// The raster each replaced layer becomes; a layer without an entry keeps
  /// its content (for example an empty layer an image resize skips).
  final Map<LayerProvider, ui.Image> images;

  /// Textures the record can resurrect: each replacement raster (re-added on
  /// redo) plus every snapshot's action/redo images (restored on undo).
  List<ui.Image> get retainedImages => <ui.Image>[
    ...images.values,
    for (final LayerStateSnapshot snapshot in snapshots.values) ...snapshot.images,
  ];

  /// Resizes the canvas to [newSize] and replaces each layer that has an entry
  /// in [images] with that single raster.
  void apply(LayersProvider layers) {
    layers.size = newSize;
    for (final LayerProvider layer in layers.list) {
      final ui.Image? image = images[layer];
      if (image != null) {
        layer.replaceContentWithImage(image);
      }
    }
  }

  /// Restores [oldSize] and every layer's [snapshots] entry.
  void revert(LayersProvider layers) {
    layers.size = oldSize;
    for (final LayerProvider layer in layers.list) {
      layer.restoreFromSnapshot(snapshots[layer]!);
    }
  }
}
