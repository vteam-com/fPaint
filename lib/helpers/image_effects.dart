import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';

/// Runs [apply] only when [strength] is above the minimum effect intensity.
Future<ui.Image> _applyWithStrengthGuard(
  ui.Image image, {
  required double strength,
  required Future<ui.Image> Function() apply,
}) async {
  // Skip only at exactly zero (no change). Negative strength is meaningful for
  // bipolar effects (darken, reduce contrast, reverse hue), so it applies.
  if (strength == AppEffects.minIntensity) {
    return image;
  }
  return apply();
}

/// Mutates raw RGBA pixels and rebuilds an image from the result.
Future<ui.Image> _applyPixelTransform(
  ui.Image image, {
  required double strength,
  required void Function(Uint8List) mutate,
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
      return imageFromPixelsDecode(pixels, image.width, image.height);
    },
  );
}

/// Applies a 4x5 [ColorFilter.matrix] to [image] entirely on the GPU.
///
/// Preferred over [_applyPixelTransform] whenever the effect is expressible as
/// an affine per-channel transform: it avoids the GPU->CPU readback, the
/// main-isolate per-pixel loop, and the texture re-upload.
Future<ui.Image> _applyColorMatrix(
  ui.Image image, {
  required double strength,
  required List<double> matrix,
}) {
  return _applyWithStrengthGuard(
    image,
    strength: strength,
    apply: () => renderCanvasImage(
      width: image.width,
      height: image.height,
      draw: (Canvas canvas) {
        canvas.drawImage(
          image,
          Offset.zero,
          Paint()..colorFilter = ColorFilter.matrix(matrix),
        );
      },
    ),
  );
}

/// Converts normalized opacity values to the 0-255 byte range.
int _opacityToByte(double opacity) {
  return (opacity.clamp(AppEffects.minIntensity, AppEffects.maxIntensity) * AppLimits.rgbChannelMax).round();
}

/// Applies a Gaussian blur with the given [sigma] to [image], scaled by [strength].
///
/// [strength] ranges from 0.0 (no blur) to 1.0 (full blur at the authored [sigma]).
///
/// [pixelScale] scales pixel-space parameters so a downscaled proxy renders the
/// same apparent result as the full-resolution image.
Future<ui.Image> applyGaussianBlur(
  ui.Image image,
  double sigma, {
  double strength = AppEffects.defaultIntensity,
  double pixelScale = AppEffects.defaultPixelScale,
}) {
  return _applyWithStrengthGuard(
    image,
    strength: strength,
    apply: () {
      final double effectiveSigma = sigma * strength * pixelScale;
      return renderCanvasImage(
        width: image.width,
        height: image.height,
        draw: (Canvas canvas) {
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
///
/// [pixelScale] scales the block size so a downscaled proxy renders the same
/// apparent result as the full-resolution image.
Future<ui.Image> applyPixelate(
  ui.Image image, {
  double strength = AppEffects.defaultIntensity,
  double size = AppEffects.pixelateDefaultSize,
  double pixelScale = AppEffects.defaultPixelScale,
}) async {
  return _applyWithStrengthGuard(
    image,
    strength: strength,
    apply: () async {
      final int w = image.width;
      final int h = image.height;
      final int blockSize = max(1, (_resolvePixelateBlockSize(size) * pixelScale).round());
      final int smallW = max(1, w ~/ blockSize);
      final int smallH = max(1, h ~/ blockSize);

      final ui.Image small = await renderCanvasImage(
        width: smallW,
        height: smallH,
        draw: (Canvas canvas) {
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
            Rect.fromLTWH(0, 0, smallW.toDouble(), smallH.toDouble()),
            Paint(),
          );
        },
      );

      // Upscale and blend in one pass: materializing a full-size pixelated
      // intermediate and blending it separately costs two extra full-resolution
      // textures, which is what exhausts VRAM on very large canvases.
      final bool isFullStrength = strength >= AppEffects.maxIntensity;
      final ui.Image result = await renderCanvasImage(
        width: w,
        height: h,
        draw: (Canvas canvas) {
          if (!isFullStrength) {
            canvas.drawImage(image, Offset.zero, Paint());
          }
          final Paint blockPaint = Paint()..filterQuality = FilterQuality.none;
          if (!isFullStrength) {
            blockPaint.color = Color.fromARGB(
              _opacityToByte(strength),
              AppLimits.rgbChannelMax,
              AppLimits.rgbChannelMax,
              AppLimits.rgbChannelMax,
            );
          }
          canvas.drawImageRect(
            small,
            Rect.fromLTWH(0, 0, smallW.toDouble(), smallH.toDouble()),
            Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
            blockPaint,
          );
        },
      );
      small.dispose();
      return result;
    },
  );
}

/// Converts the image to grayscale using a color matrix filter.
///
/// [strength] blends the grayscale result over the original: 0.0 = unchanged,
/// 1.0 = fully desaturated.
Future<ui.Image> applyGrayscale(
  ui.Image image, {
  double strength = AppEffects.defaultIntensity,
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
        draw: (Canvas canvas) {
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
  ui.Image image, {
  double strength = AppEffects.defaultIntensity,
  double pixelScale = AppEffects.defaultPixelScale,
}) async {
  return _applyWithStrengthGuard(
    image,
    strength: strength,
    apply: () async {
      final double effectiveAmount = AppEffects.sharpenAmount * strength;
      final double effectiveSigma = AppEffects.sharpenBlurSigma * pixelScale;
      final int w = image.width;
      final int h = image.height;
      final Rect rect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());

      void drawBlurred(Canvas canvas) {
        canvas.saveLayer(
          rect,
          Paint()
            ..imageFilter = ui.ImageFilter.blur(
              sigmaX: effectiveSigma,
              sigmaY: effectiveSigma,
              tileMode: TileMode.decal,
            ),
        );
        canvas.drawImage(image, Offset.zero, Paint());
        canvas.restore();
      }

      // The original and its blurred copy are stacked vertically into one image
      // so a single readback covers both planes. An unsharp mask needs unclamped
      // intermediates, so the blend itself cannot run in an 8-bit render target;
      // halving the GPU->CPU syncs is the win available here.
      final bool canStack = h * AppMath.pair <= AppLimits.maxRenderTargetDimension;
      final int planeLength = w * h * AppMath.bytesPerPixel;

      final Uint8List? origPixels;
      final Uint8List? blurPixels;
      final int blurOffset;
      if (canStack) {
        final ui.Image atlas = await renderCanvasImage(
          width: w,
          height: h * AppMath.pair,
          draw: (Canvas canvas) {
            canvas.drawImage(image, Offset.zero, Paint());
            canvas.save();
            canvas.translate(0, h.toDouble());
            canvas.clipRect(rect);
            drawBlurred(canvas);
            canvas.restore();
          },
        );
        origPixels = await extractImagePixels(atlas);
        blurPixels = origPixels;
        blurOffset = planeLength;
        atlas.dispose();
      } else {
        final ui.Image blurred = await renderCanvasImage(
          width: w,
          height: h,
          draw: drawBlurred,
        );
        origPixels = await extractImagePixels(image);
        blurPixels = await extractImagePixels(blurred);
        blurOffset = 0;
        blurred.dispose();
      }

      if (origPixels == null || blurPixels == null) {
        return image;
      }

      final Uint8List result = Uint8List(planeLength);
      for (int i = 0; i < planeLength; i += AppMath.bytesPerPixel) {
        for (int c = 0; c < AppEffects.rgbChannelCount; c++) {
          final int original = origPixels[i + c];
          final int blurredChannel = blurPixels[blurOffset + i + c];
          result[i + c] = (original + effectiveAmount * (original - blurredChannel)).round().clamp(
            0,
            AppLimits.rgbChannelMax,
          );
        }
        result[i + AppEffects.alphaChannelIndex] = origPixels[i + AppEffects.alphaChannelIndex];
      }

      return imageFromPixelsDecode(result, w, h);
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
  ui.Image image, {
  double strength = AppEffects.defaultIntensity,
  double size = AppEffects.noiseDefaultSize,
  double pixelScale = AppEffects.defaultPixelScale,
  Random? random,
}) {
  final int effectiveRange = max(1, (AppEffects.noiseRange * strength).round());
  final int effectiveOffset = effectiveRange ~/ 2;
  final int cellSize = max(1, (_resolveNoiseCellSize(size) * pixelScale).round());
  final Random rng = random ?? Random();

  return _applyPixelTransform(
    image,
    strength: strength,
    mutate: (Uint8List pixels) {
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

int _resolvePixelateBlockSize(double size) {
  final double clampedSize = size.clamp(AppEffects.minSize, AppEffects.maxSize);
  final double blockSpan = (AppEffects.pixelateMaxBlockSize - AppEffects.pixelateMinBlockSize).toDouble();
  return AppEffects.pixelateMinBlockSize + (blockSpan * clampedSize).round();
}

int _resolveNoiseCellSize(double size) {
  final double clampedSize = size.clamp(AppEffects.minSize, AppEffects.maxSize);
  final double cellSpan = (AppEffects.noiseMaxCellSize - AppEffects.noiseMinCellSize).toDouble();
  return AppEffects.noiseMinCellSize + (cellSpan * clampedSize).round();
}

/// Applies a vignette effect — darkening the edges while keeping the center bright.
///
/// [strength] scales the edge-darkening: 0.0 = no vignette,
/// 1.0 = full authored strength.
Future<ui.Image> applyVignette(
  ui.Image image, {
  double strength = AppEffects.defaultIntensity,
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
        draw: (Canvas canvas) {
          canvas.drawImage(image, Offset.zero, Paint());
          canvas.drawRect(rect, vignettePaint);
        },
      );
    },
  );
}

/// Adjusts the brightness of [image] by adding a per-channel offset.
///
/// [strength] ranges from 0.0 (no change) to 1.0 (maximum brightening).
Future<ui.Image> applyBrightness(
  ui.Image image, {
  double strength = AppEffects.defaultIntensity,
}) {
  final double offset = AppEffects.brightnessOffset * strength;
  return _applyColorMatrix(
    image,
    strength: strength,
    matrix: <double>[
      1, 0, 0, 0, offset, //
      0, 1, 0, 0, offset, //
      0, 0, 1, 0, offset, //
      0, 0, 0, 1, 0, //
    ],
  );
}

/// Adjusts the contrast of [image] by scaling each channel around the midpoint.
///
/// [strength] ranges from 0.0 (no change) to 1.0 (maximum contrast boost).
Future<ui.Image> applyContrast(
  ui.Image image, {
  double strength = AppEffects.defaultIntensity,
}) {
  final double factor = 1.0 + (AppEffects.contrastMax - 1.0) * strength;
  // c' = factor * (c - midtone) + midtone, expanded into scale + translate.
  final double translate = AppEffects.shadowMidtone * (1.0 - factor);
  return _applyColorMatrix(
    image,
    strength: strength,
    matrix: <double>[
      factor, 0, 0, 0, translate, //
      0, factor, 0, 0, translate, //
      0, 0, factor, 0, translate, //
      0, 0, 0, 1, 0, //
    ],
  );
}

/// Rotates the hue of [image] by up to [AppEffects.hueRotationMax] degrees.
///
/// [strength] ranges from 0.0 (no hue shift) to 1.0 (maximum rotation).
Future<ui.Image> applyHueRotation(
  ui.Image image, {
  double strength = AppEffects.defaultIntensity,
}) {
  final double radians = AppEffects.hueRotationMax * strength * pi / AppMath.degreesPerHalfTurn;
  final double cosine = cos(radians);
  final double sine = sin(radians);

  // Rodrigues rotation about the gray axis (1,1,1): the resulting matrix is
  // circulant, so it needs only a diagonal term and two off-diagonal terms.
  // Every row sums to 1, which leaves neutral grays untouched.
  final double shared = (1.0 - cosine) / AppMath.triple;
  final double swing = sine / sqrt(AppMath.triple.toDouble());
  final double diagonal = cosine + shared;
  final double lagging = shared - swing;
  final double leading = shared + swing;

  return _applyColorMatrix(
    image,
    strength: strength,
    matrix: <double>[
      diagonal, lagging, leading, 0, 0, //
      leading, diagonal, lagging, 0, 0, //
      lagging, leading, diagonal, 0, 0, //
      0, 0, 0, 1, 0, //
    ],
  );
}

/// Scales the chroma of [image] around its luma, entirely on the GPU.
///
/// Each channel is interpolated toward (negative) or away from (positive) its
/// luma: c' = luma + (c - luma) * (1 + strength). Strength -1 is fully gray,
/// 0 is unchanged, positive strengths oversaturate. Rows sum to 1, so neutral
/// grays and alpha are untouched.
///
/// [strength] ranges from -1.0 (fully desaturated) to 1.0 (double chroma).
Future<ui.Image> applySaturation(
  ui.Image image, {
  double strength = AppEffects.defaultIntensity,
}) {
  final double factor = 1.0 + strength;
  final double redTerm = AppEffects.lumaRed * (1.0 - factor);
  final double greenTerm = AppEffects.lumaGreen * (1.0 - factor);
  final double blueTerm = AppEffects.lumaBlue * (1.0 - factor);

  return _applyColorMatrix(
    image,
    strength: strength,
    matrix: <double>[
      factor, greenTerm, blueTerm, 0, 0, //
      redTerm, factor, blueTerm, 0, 0, //
      redTerm, greenTerm, factor, 0, 0, //
      0, 0, 0, 1, 0, //
    ],
  );
}

/// Darkens shadow (dark) regions of [image].
///
/// [strength] ranges from 0.0 (no change) to 1.0 (maximum darkening of shadows).
Future<ui.Image> applyShadow(
  ui.Image image, {
  double strength = AppEffects.defaultIntensity,
}) {
  final double darken = AppEffects.shadowDarkening * strength;
  return _applyPixelTransform(
    image,
    strength: strength,
    mutate: (Uint8List pixels) {
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
