import 'dart:typed_data';
import 'package:image/image.dart' as img;

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
    throw Exception('Failed to decode PNG image');
  }

  // Encode the image to JPG format
  final Uint8List outputBytes = img.encodeJpg(image);

  return Uint8List.fromList(outputBytes);
}
