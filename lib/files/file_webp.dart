import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fpaint/files/file_operation_exception.dart';
import 'package:fpaint/files/webp_encoder.dart';

const String _errorFailedToGetWebpRgbaBytes = 'Failed to get raw RGBA bytes from image.';

/// Converts a [ui.Image] to WebP format bytes using lossless encoding.
///
/// [image] The source image.
/// Returns the image bytes in WebP format.
Future<Uint8List> convertImageToWebp(final ui.Image image) async {
  final ByteData? byteData = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  if (byteData == null) {
    throw const WebpConversionException(_errorFailedToGetWebpRgbaBytes);
  }

  return encodeWebpLossless(
    byteData.buffer.asUint8List(),
    image.width,
    image.height,
  );
}
