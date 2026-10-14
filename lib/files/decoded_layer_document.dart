import 'package:flutter/widgets.dart';
import 'package:fpaint/files/decoded_raster_layer.dart';
import 'package:fpaint/files/package_image_bridge.dart';
import 'package:fpaint/providers/layers_provider.dart';

/// A validated layered document ready to be applied to the canvas.
class DecodedRasterDocument {
  /// Creates a decoded document.
  const DecodedRasterDocument({
    required this.size,
    required this.layers,
  });

  /// Canvas size in pixels.
  final Size size;

  /// Decoded layers ordered bottom-to-top.
  final List<DecodedRasterLayer> layers;
}

/// Replaces the content of [layers] with [document].
///
/// Layers are stacked bottom-to-top with [LayersProvider.addTop], keeping each
/// layer's placement and properties. The layer flagged `selected` is restored
/// once the rebuild completes, since [LayersProvider.replaceAll] resets the
/// selection to the first layer.
Future<void> applyDecodedDocument(
  LayersProvider layers,
  DecodedRasterDocument document,
) async {
  LayerProvider? selectedLayer;
  await layers.replaceAll(
    canvasSize: document.size,
    addLayers: () async {
      for (final DecodedRasterLayer decoded in document.layers) {
        final LayerProvider appended = await _appendDecodedLayer(layers, decoded);
        if (decoded.selected) {
          selectedLayer = appended;
        }
      }
    },
  );
  layers.selectLayerIfPresent(selectedLayer);
}

/// Appends one decoded layer to the top of [layers], preserving its placement.
Future<LayerProvider> _appendDecodedLayer(
  LayersProvider layers,
  DecodedRasterLayer decoded,
) async {
  final LayerProvider newLayer = layers.addTop(name: decoded.name);
  newLayer.opacity = decoded.opacity;
  newLayer.blendMode = decoded.blendMode;
  newLayer.isVisible = decoded.visible;
  newLayer.isLocked = decoded.locked;

  newLayer.addImage(
    imageToAdd: await packageImageToUiImage(decoded.image),
    offset: decoded.offset,
  );
  return newLayer;
}
