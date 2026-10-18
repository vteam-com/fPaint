// ignore: fcheck_one_class_per_file
import 'dart:ui' as ui;

import 'package:fpaint/files/package_image_bridge.dart';
import 'package:image/image.dart' as img;

/// A decoded layer's pixels, in whichever form its reader produced them.
///
/// Sealed so applying a document stays exhaustive: CPU-decoded rasters (TIFF,
/// PSD) convert on apply, while formats that embed PNGs (ORA) keep the
/// engine's fast image decode instead of round-tripping through the CPU.
sealed class DecodedLayerPixels {
  const DecodedLayerPixels();

  /// The pixels as an engine image, ready to place on a layer.
  Future<ui.Image> toUiImage();
}

/// Straight-alpha pixels decoded on the CPU by `package:image`.
class PackageImagePixels extends DecodedLayerPixels {
  const PackageImagePixels(this.image);

  /// The decoded raster.
  final img.Image image;

  @override
  Future<ui.Image> toUiImage() => packageImageToUiImage(image);
}

/// Pixels the engine already decoded.
class UiImagePixels extends DecodedLayerPixels {
  const UiImagePixels(this.image);

  /// The decoded engine image.
  final ui.Image image;

  @override
  Future<ui.Image> toUiImage() => Future<ui.Image>.value(image);
}
