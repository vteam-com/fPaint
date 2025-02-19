import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Loads an image from the specified asset path.
///
/// This function asynchronously loads an image from the specified asset path and
/// returns a [Future] that completes with the loaded [ui.Image] instance.
///
/// The function uses [AssetImage] to resolve the image and listens to the
/// [ImageStream] to get the loaded image.
///
/// Example usage:
///
/// final image = await loadImage('assets/my_image.png');
///
Future<ui.Image> loadImageFromAssets(final String assetPath) async {
  final AssetImage assetImage = AssetImage(assetPath);
  final Completer<ui.Image> completer = Completer<ui.Image>();
  assetImage.resolve(ImageConfiguration.empty).addListener(
        ImageStreamListener(
          (final ImageInfo info, final _) => completer.complete(info.image),
        ),
      );
  return completer.future;
}

Future<ByteData> loadBinaryFromAssets(final String assetPath) async {
  return await rootBundle.load(assetPath);
}
