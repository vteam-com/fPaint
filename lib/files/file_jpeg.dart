import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fpaint/files/file_operation_exception.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:image/image.dart' as img;

const String _errorFailedToGetJpegRgbaBytes = 'Failed to get raw RGBA bytes for JPEG conversion.';

/// Converts the given Flutter [ui.Image] to JPEG bytes.
///
/// This uses the in-memory raster directly so export callers do not need an
/// intermediate PNG encode/decode round-trip.
///
/// [image] The source image.
/// Returns the image bytes in JPEG format.
Future<Uint8List> convertToJpg(final ui.Image image) async {
  final ByteData? byteData = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  if (byteData == null) {
    throw const JpegConversionException(_errorFailedToGetJpegRgbaBytes);
  }

  final img.Image packageImage = img.Image.fromBytes(
    width: image.width,
    height: image.height,
    bytes: byteData.buffer,
    bytesOffset: byteData.offsetInBytes,
    rowStride: image.width * AppMath.bytesPerPixel,
    numChannels: AppMath.bytesPerPixel,
    order: img.ChannelOrder.rgba,
  );

  final Uint8List outputBytes = img.encodeJpg(packageImage);
  return Uint8List.fromList(outputBytes);
}
