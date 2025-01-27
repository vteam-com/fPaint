import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Converts the given image bytes to JPG format.
///
/// This function takes the image bytes in PNG format and converts them to JPG
/// format.
///
/// [image] The image bytes in PNG format.
/// Returns the image bytes in JPG format.

Future<Uint8List> convertToJpg(Uint8List image) async {
  // Decode the PNG image
  final img.Image? pngImage = img.decodeImage(image);
  if (pngImage == null) {
    throw Exception('Failed to decode PNG image');
  }

  // Encode the image to JPG format
  final List<int> jpgBytes = img.encodeJpg(pngImage);

  return Uint8List.fromList(jpgBytes);
}
