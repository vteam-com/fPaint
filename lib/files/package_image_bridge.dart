import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:image/image.dart' as img;

/// Number of colour channels in the canonical 8-bit RGBA layout.
const int _rgbaChannelCount = AppMath.bytesPerPixel;

/// Builds an 8-bit `package:image` image from tightly packed straight RGBA
/// [rgba] bytes (honouring the view's offset into its buffer).
///
/// The pixels are copied into the new image, so [rgba] may be reused freely.
img.Image packageImageFromRgbaBytes(
  Uint8List rgba,
  int width,
  int height,
) {
  return img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    rowStride: width * _rgbaChannelCount,
    numChannels: _rgbaChannelCount,
    order: img.ChannelOrder.rgba,
  );
}

/// Reads [image] back as an 8-bit straight-RGBA `package:image` image.
///
/// Uses the raw straight-alpha readback, so no PNG encode/decode round-trip is
/// paid. Returns null when the engine yields no pixel data.
Future<img.Image?> uiImageToPackageImage(ui.Image image) async {
  final Uint8List? pixels = await extractImagePixels(
    image,
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  if (pixels == null) {
    return null;
  }

  return packageImageFromRgbaBytes(pixels, image.width, image.height);
}

/// Returns [image] in the canonical 8-bit, 4-channel layout, converting only
/// when its format, channel count or palette differ.
///
/// When no conversion is needed [image] itself is returned.
img.Image toRgba8PackageImage(img.Image image) {
  if (image.format == img.Format.uint8 && image.numChannels == _rgbaChannelCount && !image.hasPalette) {
    return image;
  }

  return image.convert(format: img.Format.uint8, numChannels: _rgbaChannelCount);
}

/// Uploads a straight-alpha `package:image` [image] as a [ui.Image].
///
/// The pixels are normalized to 8-bit RGBA, premultiplied (the upload format
/// is premultiplied, see [premultiplyRgbaInPlace]) and decoded through
/// [imageFromPixelsDecode]. [image] itself is never modified.
Future<ui.Image> packageImageToUiImage(img.Image image) {
  final img.Image rgbaImage = toRgba8PackageImage(image);
  final Uint8List viewedPixels = rgbaImage.getBytes(order: img.ChannelOrder.rgba);
  // A converted image is already a private copy; otherwise the bytes view the
  // caller's buffer and must be copied before premultiplying in place.
  final Uint8List pixels = identical(rgbaImage, image) ? Uint8List.fromList(viewedPixels) : viewedPixels;

  return imageFromPixelsDecode(
    premultiplyRgbaInPlace(pixels),
    rgbaImage.width,
    rgbaImage.height,
  );
}
