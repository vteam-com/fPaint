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
///
/// [size] controls the block size of the pixelation.
Future<ui.Image> applyPixelate(
  final ui.Image image, {
  final double strength = AppEffects.defaultIntensity,
  final double size = AppEffects.pixelateDefaultSize,
}) async {
  if (strength <= AppEffects.minIntensity) {
    return image;
  }
  final int w = image.width;
  final int h = image.height;
  final int blockSize = _resolvePixelateBlockSize(size);
  final int smallW = max(1, w ~/ blockSize);
  final int smallH = max(1, h ~/ blockSize);

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
  final int opacityByte = (strength.clamp(AppEffects.minIntensity, AppEffects.maxIntensity) * AppLimits.rgbChannelMax)
      .round();
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
///
/// [size] controls the grain size of the noise.
Future<ui.Image> applyNoise(
  final ui.Image image, {
  final double strength = AppEffects.defaultIntensity,
  final double size = AppEffects.noiseDefaultSize,
  final Random? random,
}) async {
  if (strength <= AppEffects.minIntensity) {
    return image;
  }
  final int effectiveRange = max(1, (AppEffects.noiseRange * strength).round());
  final int effectiveOffset = effectiveRange ~/ 2;
  final int cellSize = _resolveNoiseCellSize(size);
  final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) {
    return image;
  }

  final Uint8List pixels = byteData.buffer.asUint8List();
  final Random rng = random ?? Random();

  for (int y = 0; y < image.height; y += cellSize) {
    final int cellHeight = min(cellSize, image.height - y);
    for (int x = 0; x < image.width; x += cellSize) {
      final int cellWidth = min(cellSize, image.width - x);
      final List<int> channelNoise = <int>[
        rng.nextInt(effectiveRange) - effectiveOffset,
        rng.nextInt(effectiveRange) - effectiveOffset,
        rng.nextInt(effectiveRange) - effectiveOffset,
      ];

      for (int yOffset = 0; yOffset < cellHeight; yOffset++) {
        final int rowStart = ((y + yOffset) * image.width + x) * AppMath.bytesPerPixel;
        for (int xOffset = 0; xOffset < cellWidth; xOffset++) {
          final int pixelIndex = rowStart + (xOffset * AppMath.bytesPerPixel);
          final int alpha = pixels[pixelIndex + AppEffects.alphaChannelIndex];
          if (alpha == 0) {
            for (int c = 0; c < AppEffects.rgbChannelCount; c++) {
              pixels[pixelIndex + c] = 0;
            }
            continue;
          }
          for (int c = 0; c < AppEffects.rgbChannelCount; c++) {
            pixels[pixelIndex + c] = (pixels[pixelIndex + c] + channelNoise[c]).clamp(0, AppLimits.rgbChannelMax);
          }
        }
      }
    }
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

int _resolvePixelateBlockSize(final double size) {
  final double clampedSize = size.clamp(AppEffects.minSize, AppEffects.maxSize);
  final double blockSpan = (AppEffects.pixelateMaxBlockSize - AppEffects.pixelateMinBlockSize).toDouble();
  return AppEffects.pixelateMinBlockSize + (blockSpan * clampedSize).round();
}

int _resolveNoiseCellSize(final double size) {
  final double clampedSize = size.clamp(AppEffects.minSize, AppEffects.maxSize);
  final double cellSpan = (AppEffects.noiseMaxCellSize - AppEffects.noiseMinCellSize).toDouble();
  return AppEffects.noiseMinCellSize + (cellSpan * clampedSize).round();
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
  final double effectiveStrength = (AppEffects.vignetteStrength * strength).clamp(
    AppEffects.minIntensity,
    AppEffects.maxIntensity,
  );
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
        AppColors.transparent,
        AppColors.black.withValues(alpha: effectiveStrength),
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
  final int opacityByte = (opacity.clamp(AppEffects.minIntensity, AppEffects.maxIntensity) * AppLimits.rgbChannelMax)
      .round();
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

/// Adjusts the brightness of [image] by adding a per-channel offset.
///
/// [strength] ranges from 0.0 (no change) to 1.0 (maximum brightening).
Future<ui.Image> applyBrightness(
  final ui.Image image, {
  final double strength = AppEffects.defaultIntensity,
}) async {
  if (strength <= AppEffects.minIntensity) {
    return image;
  }
  final int offset = (AppEffects.brightnessOffset * strength).round();
  final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) {
    return image;
  }

  final Uint8List pixels = byteData.buffer.asUint8List();

  for (int i = 0; i < pixels.length; i += AppMath.bytesPerPixel) {
    for (int c = 0; c < AppEffects.rgbChannelCount; c++) {
      pixels[i + c] = (pixels[i + c] + offset).clamp(0, AppLimits.rgbChannelMax);
    }
  }

  return _imageFromPixels(pixels, image.width, image.height);
}

/// Adjusts the contrast of [image] by scaling each channel around the midpoint.
///
/// [strength] ranges from 0.0 (no change) to 1.0 (maximum contrast boost).
Future<ui.Image> applyContrast(
  final ui.Image image, {
  final double strength = AppEffects.defaultIntensity,
}) async {
  if (strength <= AppEffects.minIntensity) {
    return image;
  }
  final double factor = 1.0 + (AppEffects.contrastMax - 1.0) * strength;
  final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) {
    return image;
  }

  final Uint8List pixels = byteData.buffer.asUint8List();

  for (int i = 0; i < pixels.length; i += AppMath.bytesPerPixel) {
    for (int c = 0; c < AppEffects.rgbChannelCount; c++) {
      final int v = pixels[i + c];
      pixels[i + c] = ((factor * (v - AppEffects.shadowMidtone)) + AppEffects.shadowMidtone).round().clamp(
        0,
        AppLimits.rgbChannelMax,
      );
    }
  }

  return _imageFromPixels(pixels, image.width, image.height);
}

/// Rotates the hue of [image] by up to [AppEffects.hueRotationMax] degrees.
///
/// [strength] ranges from 0.0 (no hue shift) to 1.0 (maximum rotation).
Future<ui.Image> applyHueSaturation(
  final ui.Image image, {
  final double strength = AppEffects.defaultIntensity,
}) async {
  if (strength <= AppEffects.minIntensity) {
    return image;
  }
  final double hueShift = AppEffects.hueRotationMax * strength;
  final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) {
    return image;
  }

  final Uint8List pixels = byteData.buffer.asUint8List();

  for (int i = 0; i < pixels.length; i += AppMath.bytesPerPixel) {
    final int r = pixels[i + AppMath.rgbChannelRed];
    final int g = pixels[i + AppMath.rgbChannelGreen];
    final int b = pixels[i + AppMath.rgbChannelBlue];
    final List<double> hsl = _rgbToHsl(r, g, b);
    hsl[0] = (hsl[0] + hueShift) % AppEffects.hueFullCircle;
    final List<int> rgb = _hslToRgb(
      hsl[AppMath.rgbChannelRed],
      hsl[AppMath.rgbChannelGreen],
      hsl[AppMath.rgbChannelBlue],
    );
    pixels[i + AppMath.rgbChannelRed] = rgb[AppMath.rgbChannelRed];
    pixels[i + AppMath.rgbChannelGreen] = rgb[AppMath.rgbChannelGreen];
    pixels[i + AppMath.rgbChannelBlue] = rgb[AppMath.rgbChannelBlue];
  }

  return _imageFromPixels(pixels, image.width, image.height);
}

/// Darkens shadow (dark) regions of [image].
///
/// [strength] ranges from 0.0 (no change) to 1.0 (maximum darkening of shadows).
Future<ui.Image> applyShadow(
  final ui.Image image, {
  final double strength = AppEffects.defaultIntensity,
}) async {
  if (strength <= AppEffects.minIntensity) {
    return image;
  }
  final double darken = AppEffects.shadowDarkening * strength;
  final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) {
    return image;
  }

  final Uint8List pixels = byteData.buffer.asUint8List();

  for (int i = 0; i < pixels.length; i += AppMath.bytesPerPixel) {
    final int r = pixels[i];
    final int g = pixels[i + 1];
    final int b = pixels[i + AppMath.rgbChannelBlue];
    final double luma = AppEffects.lumaRed * r + AppEffects.lumaGreen * g + AppEffects.lumaBlue * b;
    if (luma < AppEffects.shadowMidtone) {
      final double shadowFactor = 1.0 - darken * (1.0 - luma / AppEffects.shadowMidtone);
      pixels[i] = (r * shadowFactor).round().clamp(0, AppLimits.rgbChannelMax);
      pixels[i + AppMath.rgbChannelGreen] = (g * shadowFactor).round().clamp(0, AppLimits.rgbChannelMax);
      pixels[i + AppMath.rgbChannelBlue] = (b * shadowFactor).round().clamp(0, AppLimits.rgbChannelMax);
    }
  }

  return _imageFromPixels(pixels, image.width, image.height);
}

/// Creates a [ui.Image] from raw RGBA pixel data.
Future<ui.Image> _imageFromPixels(
  final Uint8List pixels,
  final int width,
  final int height,
) async {
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final ui.Codec codec = await descriptor.instantiateCodec();
  final ui.FrameInfo frame = await codec.getNextFrame();
  return frame.image;
}

/// Converts RGB (0–255) to HSL (h: 0–360, s: 0–1, l: 0–1).
List<double> _rgbToHsl(final int r, final int g, final int b) {
  final double rn = r / AppLimits.rgbChannelMax;
  final double gn = g / AppLimits.rgbChannelMax;
  final double bn = b / AppLimits.rgbChannelMax;
  final double cMax = max(rn, max(gn, bn));
  final double cMin = min(rn, min(gn, bn));
  final double delta = cMax - cMin;
  final double l = (cMax + cMin) / AppMath.pair;
  if (delta == AppMath.zero.toDouble()) {
    return <double>[AppMath.zero.toDouble(), AppMath.zero.toDouble(), l];
  }
  final double s = delta / (1 - (AppMath.pair * l - 1).abs());
  double h;
  if (cMax == rn) {
    h = AppMath.degrees60 * (((gn - bn) / delta) % AppMath.six);
  } else if (cMax == gn) {
    h = AppMath.degrees60 * ((bn - rn) / delta + AppMath.two);
  } else {
    h = AppMath.degrees60 * ((rn - gn) / delta + AppMath.four);
  }
  if (h < AppMath.zero.toDouble()) {
    h += AppEffects.hueFullCircle;
  }
  return <double>[h, s, l];
}

/// Converts HSL (h: 0–360, s: 0–1, l: 0–1) to RGB (0–255).
List<int> _hslToRgb(final double h, final double s, final double l) {
  final double c = (1 - (AppMath.pair * l - 1).abs()) * s;
  final double x = c * (1 - ((h / AppMath.degrees60) % AppMath.two - 1).abs());
  final double m = l - c / AppMath.pair;
  double rn, gn, bn;
  if (h < AppMath.degrees60) {
    rn = c;
    gn = x;
    bn = AppMath.zero.toDouble();
  } else if (h < AppMath.degrees120) {
    rn = x;
    gn = c;
    bn = AppMath.zero.toDouble();
  } else if (h < AppMath.degrees180) {
    rn = AppMath.zero.toDouble();
    gn = c;
    bn = x;
  } else if (h < AppMath.degrees240) {
    rn = AppMath.zero.toDouble();
    gn = x;
    bn = c;
  } else if (h < AppMath.degrees300) {
    rn = x;
    gn = AppMath.zero.toDouble();
    bn = c;
  } else {
    rn = c;
    gn = AppMath.zero.toDouble();
    bn = x;
  }
  return <int>[
    ((rn + m) * AppLimits.rgbChannelMax).round().clamp(AppMath.zero, AppLimits.rgbChannelMax),
    ((gn + m) * AppLimits.rgbChannelMax).round().clamp(AppMath.zero, AppLimits.rgbChannelMax),
    ((bn + m) * AppLimits.rgbChannelMax).round().clamp(AppMath.zero, AppLimits.rgbChannelMax),
  ];
}
