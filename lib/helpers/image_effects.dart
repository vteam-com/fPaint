import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';

/// Applies a Gaussian blur with the given [sigma] to [image].
Future<ui.Image> applyGaussianBlur(
  final ui.Image image,
  final double sigma,
) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.saveLayer(
    Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    ),
    Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.decal,
      ),
  );
  canvas.drawImage(image, Offset.zero, Paint());
  canvas.restore();
  return recorder.endRecording().toImage(image.width, image.height);
}

/// Applies pixelation by downscaling then upscaling with no filtering.
Future<ui.Image> applyPixelate(final ui.Image image) async {
  final int w = image.width;
  final int h = image.height;
  final int smallW = max(1, w ~/ AppEffects.pixelateBlockSize);
  final int smallH = max(1, h ~/ AppEffects.pixelateBlockSize);

  // Downscale.
  final ui.PictureRecorder downRecorder = ui.PictureRecorder();
  final Canvas downCanvas = Canvas(downRecorder);
  downCanvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Rect.fromLTWH(0, 0, smallW.toDouble(), smallH.toDouble()),
    Paint(),
  );
  final ui.Image small = await downRecorder.endRecording().toImage(smallW, smallH);

  // Upscale with no filtering to get blocky pixels.
  final ui.PictureRecorder upRecorder = ui.PictureRecorder();
  final Canvas upCanvas = Canvas(upRecorder);
  upCanvas.drawImageRect(
    small,
    Rect.fromLTWH(0, 0, smallW.toDouble(), smallH.toDouble()),
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..filterQuality = FilterQuality.none,
  );
  return upRecorder.endRecording().toImage(w, h);
}

/// Converts the image to grayscale using a color matrix filter.
Future<ui.Image> applyGrayscale(final ui.Image image) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Paint paint = Paint()
    ..colorFilter = const ColorFilter.matrix(<double>[
      AppEffects.lumaRed,
      AppEffects.lumaGreen,
      AppEffects.lumaBlue,
      0,
      0,
      AppEffects.lumaRed,
      AppEffects.lumaGreen,
      AppEffects.lumaBlue,
      0,
      0,
      AppEffects.lumaRed,
      AppEffects.lumaGreen,
      AppEffects.lumaBlue,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);
  canvas.drawImage(image, Offset.zero, paint);
  return recorder.endRecording().toImage(image.width, image.height);
}

/// Applies an unsharp-mask style sharpening by blending the original over
/// a blurred version.
Future<ui.Image> applySharpen(final ui.Image image) async {
  final int w = image.width;
  final int h = image.height;
  final Rect rect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());

  // Create a blurred version.
  final ui.PictureRecorder blurRecorder = ui.PictureRecorder();
  final Canvas blurCanvas = Canvas(blurRecorder);
  blurCanvas.saveLayer(
    rect,
    Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: AppEffects.sharpenBlurSigma,
        sigmaY: AppEffects.sharpenBlurSigma,
        tileMode: TileMode.decal,
      ),
  );
  blurCanvas.drawImage(image, Offset.zero, Paint());
  blurCanvas.restore();
  final ui.Image blurred = await blurRecorder.endRecording().toImage(w, h);

  // Pixel-level unsharp mask: result = original + amount * (original - blurred)
  final ByteData? origData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final ByteData? blurData = await blurred.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (origData == null || blurData == null) {
    return image;
  }

  final Uint8List origPixels = origData.buffer.asUint8List();
  final Uint8List blurPixels = blurData.buffer.asUint8List();
  final Uint8List result = Uint8List(origPixels.length);

  for (int i = 0; i < origPixels.length; i += AppMath.bytesPerPixel) {
    for (int c = 0; c < AppEffects.rgbChannelCount; c++) {
      final int o = origPixels[i + c];
      final int b = blurPixels[i + c];
      result[i + c] = (o + AppEffects.sharpenAmount * (o - b)).round().clamp(0, AppLimits.rgbChannelMax);
    }
    result[i + AppEffects.alphaChannelIndex] = origPixels[i + AppEffects.alphaChannelIndex]; // preserve alpha
  }

  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(result);
  final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final ui.Codec codec = await descriptor.instantiateCodec();
  final ui.FrameInfo frame = await codec.getNextFrame();
  return frame.image;
}

/// Adds random noise to each pixel.
Future<ui.Image> applyNoise(final ui.Image image) async {
  final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) {
    return image;
  }

  final Uint8List pixels = byteData.buffer.asUint8List();
  final Random rng = Random();

  for (int i = 0; i < pixels.length; i += AppMath.bytesPerPixel) {
    for (int c = 0; c < AppEffects.rgbChannelCount; c++) {
      final int noise = rng.nextInt(AppEffects.noiseRange) - AppEffects.noiseOffset;
      pixels[i + c] = (pixels[i + c] + noise).clamp(0, AppLimits.rgbChannelMax);
    }
    // alpha channel left unchanged
  }

  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: image.width,
    height: image.height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final ui.Codec codec = await descriptor.instantiateCodec();
  final ui.FrameInfo frame = await codec.getNextFrame();
  return frame.image;
}

/// Applies a vignette effect — darkening the edges while keeping the center bright.
Future<ui.Image> applyVignette(final ui.Image image) async {
  final int w = image.width;
  final int h = image.height;
  final Rect rect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);

  // Draw the original image.
  canvas.drawImage(image, Offset.zero, Paint());

  // Overlay a radial gradient from transparent center to dark edges.
  final Paint vignettePaint = Paint()
    ..shader = RadialGradient(
      colors: <Color>[
        Colors.transparent,
        Colors.black.withValues(alpha: AppEffects.vignetteStrength),
      ],
    ).createShader(rect);
  canvas.drawRect(rect, vignettePaint);

  return recorder.endRecording().toImage(w, h);
}
