import 'dart:typed_data';

import 'package:fpaint/files/file_operation_exception.dart';
import 'package:image/image.dart' as img;

const String _errorFailedToDecodePngForJpeg = 'Failed to decode image bytes for JPEG conversion.';

/// Converts the given image bytes to JPG format.
///
/// This function takes the image bytes in PNG format and converts them to JPG
/// format.
///
/// [inputBytes] The image bytes in PNG format.
/// Returns the image bytes in JPG format.

Future<Uint8List> convertToJpg(final Uint8List inputBytes) async {
  // Decode the PNG image
  final img.Image? image = img.decodeImage(inputBytes);
  if (image == null) {
    throw const JpegConversionException(_errorFailedToDecodePngForJpeg);
  }

  // Encode the image to JPG format
  final Uint8List outputBytes = img.encodeJpg(image);

  return Uint8List.fromList(outputBytes);
}
