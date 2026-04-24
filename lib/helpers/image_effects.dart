import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

/// Applies a Gaussian blur with the given [sigma] to [image], scaled by [strength].
///
/// [strength] ranges from 0.0 (no blur) to 1.0 (full blur at the authored [sigma]).
Future<ui.Image> applyGaussianBlur(
  final ui.Image image,
  final double sigma, {
  final double strength = AppEffects.defaultIntensity,
}) async {
  if (strength <= AppEffects.minIntensity) {
    return image;
  }
  final double effectiveSigma = sigma * strength;
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
        sigmaX: effectiveSigma,
        sigmaY: effectiveSigma,
        tileMode: TileMode.decal,
      ),
  );
  canvas.drawImage(image, Offset.zero, Paint());
  canvas.restore();
  return recorder.endRecording().toImage(image.width, image.height);
}

/// Applies pixelation by downscaling then upscaling with no filtering.
///
/// [strength] blends the pixelated result over the original: 0.0 = unchanged,
/// 1.0 = fully pixelated.
Future<ui.Image> applyPixelate(
  final ui.Image image, {
  final double strength = AppEffects.defaultIntensity,
}) async {
  if (strength <= AppEffects.minIntensity) {
    return image;
  }
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
  final ui.Image pixelated = await upRecorder.endRecording().toImage(w, h);

  if (strength >= AppEffects.maxIntensity) {
    return pixelated;
  }

  // Blend pixelated over original at the requested strength.
  return _blendOver(image, pixelated, strength);
}

/// Converts the image to grayscale using a color matrix filter.
///
/// [strength] blends the grayscale result over the original: 0.0 = unchanged,
/// 1.0 = fully desaturated.
Future<ui.Image> applyGrayscale(
  final ui.Image image, {
  final double strength = AppEffects.defaultIntensity,
}) async {
  if (strength <= AppEffects.minIntensity) {
    return image;
  }
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  // Draw the original beneath so partial strength blends correctly.
  canvas.drawImage(image, Offset.zero, Paint());
  final Paint grayPaint = Paint()
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
  // Overlay grayscale at opacity = strength for a linear blend.
  final int opacityByte = (strength * AppLimits.rgbChannelMax).round();
  canvas.saveLayer(
    null,
    Paint()
      ..color = Color.fromARGB(
        opacityByte,
        AppLimits.rgbChannelMax,
        AppLimits.rgbChannelMax,
        AppLimits.rgbChannelMax,
      ),
  );
  canvas.drawImage(image, Offset.zero, grayPaint);
  canvas.restore();
  return recorder.endRecording().toImage(image.width, image.height);
}

/// Applies an unsharp-mask style sharpening by blending the original over
/// a blurred version.
///
/// [strength] scales the sharpening amount: 0.0 = no sharpening,
/// 1.0 = full authored strength.
Future<ui.Image> applySharpen(
  final ui.Image image, {
  final double strength = AppEffects.defaultIntensity,
}) async {
  if (strength <= AppEffects.minIntensity) {
    return image;
  }
  final double effectiveAmount = AppEffects.sharpenAmount * strength;
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
      result[i + c] = (o + effectiveAmount * (o - b)).round().clamp(0, AppLimits.rgbChannelMax);
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
///
/// [strength] scales the noise amplitude: 0.0 = no noise,
/// 1.0 = full authored noise range.
Future<ui.Image> applyNoise(
  final ui.Image image, {
  final double strength = AppEffects.defaultIntensity,
}) async {
  if (strength <= AppEffects.minIntensity) {
    return image;
  }
  final int effectiveRange = max(1, (AppEffects.noiseRange * strength).round());
  final int effectiveOffset = effectiveRange ~/ 2;
  final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) {
    return image;
  }

  final Uint8List pixels = byteData.buffer.asUint8List();
  final Random rng = Random();

  for (int i = 0; i < pixels.length; i += AppMath.bytesPerPixel) {
    for (int c = 0; c < AppEffects.rgbChannelCount; c++) {
      final int noise = rng.nextInt(effectiveRange) - effectiveOffset;
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
///
/// [strength] scales the edge-darkening: 0.0 = no vignette,
/// 1.0 = full authored strength.
Future<ui.Image> applyVignette(
  final ui.Image image, {
  final double strength = AppEffects.defaultIntensity,
}) async {
  if (strength <= AppEffects.minIntensity) {
    return image;
  }
  final double effectiveStrength = AppEffects.vignetteStrength * strength;
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
        AppPalette.transparent,
        AppPalette.black.withValues(alpha: effectiveStrength),
      ],
    ).createShader(rect);
  canvas.drawRect(rect, vignettePaint);

  return recorder.endRecording().toImage(w, h);
}

/// Blends [top] over [bottom] at [opacity] (0.0–1.0) and returns the result.
Future<ui.Image> _blendOver(
  final ui.Image bottom,
  final ui.Image top,
  final double opacity,
) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawImage(bottom, Offset.zero, Paint());
  final int opacityByte = (opacity * AppLimits.rgbChannelMax).round();
  canvas.drawImage(
    top,
    Offset.zero,
    Paint()
      ..color = Color.fromARGB(
        opacityByte,
        AppLimits.rgbChannelMax,
        AppLimits.rgbChannelMax,
        AppLimits.rgbChannelMax,
      ),
  );
  return recorder.endRecording().toImage(bottom.width, bottom.height);
}
