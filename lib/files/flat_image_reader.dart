import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/providers/layers_provider.dart';

/// Decodes a flat (single-image) file's [bytes] into [layers], replacing the
/// document with one layer named [name] sized to the image.
///
/// Throws when [bytes] are not a decodable image; callers turn that into
/// user-facing feedback.
Future<void> readFlatImageFromBytes(
  LayersProvider layers,
  Uint8List bytes,
  String name,
) async {
  final ui.Image image = await fromBytesToImage(bytes);
  await layers.replaceAll(
    canvasSize: ui.Size(image.width.toDouble(), image.height.toDouble()),
    addLayers: () async => addImageAsTopLayer(layers, image, name),
  );
}

/// Adds [image] as a new top layer named [name] and selects it.
void addImageAsTopLayer(
  LayersProvider layers,
  ui.Image image,
  String name,
) {
  layers.addTop(name: name);
  layers.selectedLayer.addImage(imageToAdd: image);
}
