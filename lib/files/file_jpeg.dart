import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fpaint/files/file_operation_exception.dart';
import 'package:fpaint/files/package_image_bridge.dart';
import 'package:image/image.dart' as img;

const String _errorFailedToGetJpegRgbaBytes = 'Failed to get raw RGBA bytes for JPEG conversion.';

/// Converts the given Flutter [ui.Image] to JPEG bytes.
///
/// This uses the in-memory raster directly so export callers do not need an
/// intermediate PNG encode/decode round-trip.
///
/// [image] The source image.
/// Returns the image bytes in JPEG format.
Future<Uint8List> convertToJpg(ui.Image image) async {
  final ByteData byteData = await requireImageByteData<JpegConversionException>(
    image: image,
    format: ui.ImageByteFormat.rawStraightRgba,
    errorMessage: _errorFailedToGetJpegRgbaBytes,
    exceptionBuilder: JpegConversionException.new,
  );

  final img.Image packageImage = packageImageFromRgbaBytes(
    byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
    image.width,
    image.height,
  );

  final Uint8List outputBytes = img.encodeJpg(packageImage);
  return Uint8List.fromList(outputBytes);
}
