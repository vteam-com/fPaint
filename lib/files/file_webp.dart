import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fpaint/files/webp_encoder.dart';

/// Converts a [ui.Image] to WebP format bytes using lossless encoding.
///
/// [image] The source image.
/// Returns the image bytes in WebP format.
Future<Uint8List> convertImageToWebp(final ui.Image image) async {
  final ByteData? byteData = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  if (byteData == null) {
    throw Exception('Failed to get raw RGBA bytes from image');
  }

  return encodeWebpLossless(
    byteData.buffer.asUint8List(),
    image.width,
    image.height,
  );
}
