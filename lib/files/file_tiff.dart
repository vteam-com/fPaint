import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Converts the given image bytes to TIF format.
///
/// This function takes the image bytes in PNG format and converts them to TIF
/// format.
///
/// [inputBytes] The image bytes in PNG format.
/// Returns the image bytes in TIF format.

Future<Uint8List> convertToTif(final Uint8List inputBytes) async {
  // Decode the PNG image
  final img.Image? image = img.decodeImage(inputBytes);
  if (image == null) {
    throw Exception('Failed to decode PNG image');
  }

  // Encode the image to TIFF format
  final Uint8List outputBytes = img.encodeTiff(image);
  return Uint8List.fromList(outputBytes);
}
