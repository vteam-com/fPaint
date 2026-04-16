import 'dart:typed_data';

import 'package:fpaint/files/webp_encoder_shared.dart';
import 'package:fpaint/files/webp_vp8l_encoder.dart';
import 'package:image/image.dart' as img;

/// Encodes RGBA image data into a lossless WebP byte stream.
class WebPEncoder {
  WebPEncoder() : _vp8lEncoder = WebPVp8LEncoder();

  final WebPVp8LEncoder _vp8lEncoder;

  /// Encodes [image] and returns the complete RIFF/WebP file bytes.
  Uint8List encode(img.Image image) {
    final int width = image.width;
    final int height = image.height;

    final Uint8List vp8lData = _vp8lEncoder.encode(image, width, height);

    final img.OutputBuffer out = img.OutputBuffer();
    final int paddedLen = vp8lData.length + (vp8lData.length.isOdd ? 1 : 0);
    final int fileSize = 4 + 8 + paddedLen;
    out
      ..writeBytes(webPTag(WebPEncodingConstants.riffContainerTag))
      ..writeUint32(fileSize)
      ..writeBytes(webPTag(WebPEncodingConstants.webpContainerTag))
      ..writeBytes(webPTag(WebPEncodingConstants.vp8lChunkTag))
      ..writeUint32(vp8lData.length)
      ..writeBytes(vp8lData);
    if (vp8lData.length.isOdd) {
      out.writeByte(0);
    }

    return out.getBytes();
  }
}

/// Convenience helper that encodes raw RGBA bytes into a lossless WebP file.
Uint8List encodeWebpLossless(
  final Uint8List rgba,
  final int width,
  final int height,
) {
  assert(rgba.length == width * height * WebPEncodingConstants.rgbaBytesPerPixel);

  final img.Image image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    rowStride: width * WebPEncodingConstants.rgbaBytesPerPixel,
    numChannels: WebPEncodingConstants.rgbaBytesPerPixel,
    order: img.ChannelOrder.rgba,
  );

  return WebPEncoder().encode(image);
}
