import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';

/// Runs [apply] only when [strength] is above the minimum effect intensity.
Future<ui.Image> _applyWithStrengthGuard(
  final ui.Image image, {
  required final double strength,
  required final Future<ui.Image> Function() apply,
}) async {
  if (strength <= AppEffects.minIntensity) {
    return image;
  }
  return apply();
}

/// Mutates raw RGBA pixels and rebuilds an image from the result.
Future<ui.Image> _applyPixelTransform(
  final ui.Image image, {
  required final double strength,
  required final void Function(Uint8List) mutate,
}) {
  return _applyWithStrengthGuard(
    image,
    strength: strength,
    apply: () async {
      final Uint8List? pixels = await extractImagePixels(image);
      if (pixels == null) {
        return image;
      }

      mutate(pixels);
      return imageFromPixels(pixels, image.width, image.height);
    },
  );
}

/// Converts normalized opacity values to the 0-255 byte range.
int _opacityToByte(final double opacity) {
  return (opacity.clamp(AppEffects.minIntensity, AppEffects.maxIntensity) * AppLimits.rgbChannelMax).round();
}

/// Applies a Gaussian blur with the given [sigma] to [image], scaled by [strength].
///
/// [strength] ranges from 0.0 (no blur) to 1.0 (full blur at the authored [sigma]).
Future<ui.Image> applyGaussianBlur(
  final ui.Image image,
  final double sigma, {
  final double strength = AppEffects.defaultIntensity,
}) {
  return _applyWithStrengthGuard(
    image,
    strength: strength,
    apply: () {
      final double effectiveSigma = sigma * strength;
      return renderCanvasImage(
        width: image.width,
        height: image.height,
        draw: (final Canvas canvas) {
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
        },
      );
    },
  );
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
  return _applyWithStrengthGuard(
    image,
    strength: strength,
    apply: () async {
      final int w = image.width;
      final int h = image.height;
      final int blockSize = _resolvePixelateBlockSize(size);
      final int smallW = max(1, w ~/ blockSize);
      final int smallH = max(1, h ~/ blockSize);

      final ui.Image small = await renderCanvasImage(
        width: smallW,
        height: smallH,
        draw: (final Canvas canvas) {
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
            Rect.fromLTWH(0, 0, smallW.toDouble(), smallH.toDouble()),
            Paint(),
          );
        },
      );

      final ui.Image pixelated = await renderCanvasImage(
        width: w,
        height: h,
        draw: (final Canvas canvas) {
          canvas.drawImageRect(
            small,
            Rect.fromLTWH(0, 0, smallW.toDouble(), smallH.toDouble()),
            Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
            Paint()..filterQuality = FilterQuality.none,
          );
        },
      );

      if (strength >= AppEffects.maxIntensity) {
        return pixelated;
      }

      return _blendOver(image, pixelated, strength);
    },
  );
}

/// Converts the image to grayscale using a color matrix filter.
///
/// [strength] blends the grayscale result over the original: 0.0 = unchanged,
/// 1.0 = fully desaturated.
Future<ui.Image> applyGrayscale(
  final ui.Image image, {
  final double strength = AppEffects.defaultIntensity,
}) {
  return _applyWithStrengthGuard(
    image,
    strength: strength,
    apply: () {
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
      final int opacityByte = _opacityToByte(strength);

      return renderCanvasImage(
        width: image.width,
        height: image.height,
        draw: (final Canvas canvas) {
          canvas.drawImage(image, Offset.zero, Paint());
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
        },
      );
    },
  );
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
  return _applyWithStrengthGuard(
    image,
    strength: strength,
    apply: () async {
      final double effectiveAmount = AppEffects.sharpenAmount * strength;
      final int w = image.width;
      final int h = image.height;
      final Rect rect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());

      final ui.Image blurred = await renderCanvasImage(
        width: w,
        height: h,
        draw: (final Canvas canvas) {
          canvas.saveLayer(
            rect,
            Paint()
              ..imageFilter = ui.ImageFilter.blur(
                sigmaX: AppEffects.sharpenBlurSigma,
                sigmaY: AppEffects.sharpenBlurSigma,
                tileMode: TileMode.decal,
              ),
          );
          canvas.drawImage(image, Offset.zero, Paint());
          canvas.restore();
        },
      );

      final Uint8List? origPixels = await extractImagePixels(image);
      final Uint8List? blurPixels = await extractImagePixels(blurred);
      if (origPixels == null || blurPixels == null) {
        return image;
      }

      final Uint8List result = Uint8List(origPixels.length);
      for (int i = 0; i < origPixels.length; i += AppMath.bytesPerPixel) {
        for (int c = 0; c < AppEffects.rgbChannelCount; c++) {
          final int original = origPixels[i + c];
          final int blurredChannel = blurPixels[i + c];
          result[i + c] = (original + effectiveAmount * (original - blurredChannel)).round().clamp(
            0,
            AppLimits.rgbChannelMax,
          );
        }
        result[i + AppEffects.alphaChannelIndex] = origPixels[i + AppEffects.alphaChannelIndex];
      }

      return imageFromPixels(result, w, h);
    },
  );
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
}) {
  final int effectiveRange = max(1, (AppEffects.noiseRange * strength).round());
  final int effectiveOffset = effectiveRange ~/ 2;
  final int cellSize = _resolveNoiseCellSize(size);
  final Random rng = random ?? Random();

  return _applyPixelTransform(
    image,
    strength: strength,
    mutate: (final Uint8List pixels) {
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
    },
  );
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
}) {
  return _applyWithStrengthGuard(
    image,
    strength: strength,
    apply: () {
      final double effectiveStrength = (AppEffects.vignetteStrength * strength).clamp(
        AppEffects.minIntensity,
        AppEffects.maxIntensity,
      );
      final int w = image.width;
      final int h = image.height;
      final Rect rect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());

      final Paint vignettePaint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            AppColors.transparent,
            AppColors.black.withValues(alpha: effectiveStrength),
          ],
        ).createShader(rect);

      return renderCanvasImage(
        width: w,
        height: h,
        draw: (final Canvas canvas) {
          canvas.drawImage(image, Offset.zero, Paint());
          canvas.drawRect(rect, vignettePaint);
        },
      );
    },
  );
}

/// Blends [top] over [bottom] at [opacity] (0.0–1.0) and returns the result.
Future<ui.Image> _blendOver(
  final ui.Image bottom,
  final ui.Image top,
  final double opacity,
) {
  final int opacityByte = _opacityToByte(opacity);
  return renderCanvasImage(
    width: bottom.width,
    height: bottom.height,
    draw: (final Canvas canvas) {
      canvas.drawImage(bottom, Offset.zero, Paint());
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
    },
  );
}

/// Adjusts the brightness of [image] by adding a per-channel offset.
///
/// [strength] ranges from 0.0 (no change) to 1.0 (maximum brightening).
Future<ui.Image> applyBrightness(
  final ui.Image image, {
  final double strength = AppEffects.defaultIntensity,
}) {
  final int offset = (AppEffects.brightnessOffset * strength).round();
  return _applyPixelTransform(
    image,
    strength: strength,
    mutate: (final Uint8List pixels) {
      for (int i = 0; i < pixels.length; i += AppMath.bytesPerPixel) {
        for (int c = 0; c < AppEffects.rgbChannelCount; c++) {
          pixels[i + c] = (pixels[i + c] + offset).clamp(0, AppLimits.rgbChannelMax);
        }
      }
    },
  );
}

/// Adjusts the contrast of [image] by scaling each channel around the midpoint.
///
/// [strength] ranges from 0.0 (no change) to 1.0 (maximum contrast boost).
Future<ui.Image> applyContrast(
  final ui.Image image, {
  final double strength = AppEffects.defaultIntensity,
}) {
  final double factor = 1.0 + (AppEffects.contrastMax - 1.0) * strength;
  return _applyPixelTransform(
    image,
    strength: strength,
    mutate: (final Uint8List pixels) {
      for (int i = 0; i < pixels.length; i += AppMath.bytesPerPixel) {
        for (int c = 0; c < AppEffects.rgbChannelCount; c++) {
          final int channelValue = pixels[i + c];
          pixels[i + c] = ((factor * (channelValue - AppEffects.shadowMidtone)) + AppEffects.shadowMidtone)
              .round()
              .clamp(0, AppLimits.rgbChannelMax);
        }
      }
    },
  );
}

/// Rotates the hue of [image] by up to [AppEffects.hueRotationMax] degrees.
///
/// [strength] ranges from 0.0 (no hue shift) to 1.0 (maximum rotation).
Future<ui.Image> applyHueSaturation(
  final ui.Image image, {
  final double strength = AppEffects.defaultIntensity,
}) {
  final double hueShift = AppEffects.hueRotationMax * strength;
  return _applyPixelTransform(
    image,
    strength: strength,
    mutate: (final Uint8List pixels) {
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
    },
  );
}

/// Darkens shadow (dark) regions of [image].
///
/// [strength] ranges from 0.0 (no change) to 1.0 (maximum darkening of shadows).
Future<ui.Image> applyShadow(
  final ui.Image image, {
  final double strength = AppEffects.defaultIntensity,
}) {
  final double darken = AppEffects.shadowDarkening * strength;
  return _applyPixelTransform(
    image,
    strength: strength,
    mutate: (final Uint8List pixels) {
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
    },
  );
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
