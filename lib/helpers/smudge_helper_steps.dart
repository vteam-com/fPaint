part of 'smudge_helper.dart';

// ---------------------------------------------------------------------------
// Per-step pixel operations
// ---------------------------------------------------------------------------

/// Applies one incremental smudge step: samples pixels at [fromCenter] offset
/// and blends them into [toCenter] position within [radius].
///
/// Returns `true` when at least one pixel was modified.
bool _applySmudgeStep({
  required final Uint8List pixels,
  required final int imageWidth,
  required final int imageHeight,
  required final Offset fromCenter,
  required final Offset toCenter,
  required final double radius,
  required final double intensity,
  required final Uint8List? clipMask,
}) {
  final double radiusSquared = radius * radius;
  final int integerRadius = radius.ceil() + AppInteraction.smudgeBoundsPadding;
  final int left = math.max(
    AppMath.zero,
    math.min(fromCenter.dx, toCenter.dx).floor() - integerRadius,
  );
  final int top = math.max(
    AppMath.zero,
    math.min(fromCenter.dy, toCenter.dy).floor() - integerRadius,
  );
  final int right = math.min(
    imageWidth - AppMath.one,
    math.max(fromCenter.dx, toCenter.dx).ceil() + integerRadius,
  );
  final int bottom = math.min(
    imageHeight - AppMath.one,
    math.max(fromCenter.dy, toCenter.dy).ceil() + integerRadius,
  );

  if (right < left || bottom < top) {
    return false;
  }

  // Source position for destination (x, y): sourceX = fromCenter.dx + (x − toCenter.dx).
  // For destinations in [left, right] the sources span [left + d, right + d] where
  // d = fromCenter − toCenter.  When |d| > 0 that range extends outside [left, right],
  // so the snapshot must cover the union of both to keep all indices in-bounds.
  final double displacementX = fromCenter.dx - toCenter.dx;
  final double displacementY = fromCenter.dy - toCenter.dy;
  final int snapshotLeft = math.max(AppMath.zero, math.min(left, (left + displacementX).floor()));
  final int snapshotTop = math.max(AppMath.zero, math.min(top, (top + displacementY).floor()));
  final int snapshotRight = math.min(imageWidth - AppMath.one, math.max(right, (right + displacementX).ceil()));
  final int snapshotBottom = math.min(imageHeight - AppMath.one, math.max(bottom, (bottom + displacementY).ceil()));
  final int snapshotWidth = snapshotRight - snapshotLeft + AppMath.one;
  final int snapshotHeight = snapshotBottom - snapshotTop + AppMath.one;

  // Snapshot the expanded region *before* modification so every pixel in this
  // step samples from a consistent pre-step state.
  final Uint8List snapshot = _copyPixelRect(
    pixels: pixels,
    imageWidth: imageWidth,
    left: snapshotLeft,
    top: snapshotTop,
    width: snapshotWidth,
    height: snapshotHeight,
  );

  bool anyChanged = false;

  for (int y = top; y <= bottom; y++) {
    for (int x = left; x <= right; x++) {
      if (!_isMaskVisible(clipMask, imageWidth, x, y)) {
        continue;
      }

      final double centerOffsetX = x + AppVisual.half - toCenter.dx;
      final double centerOffsetY = y + AppVisual.half - toCenter.dy;
      final double distanceSquared = centerOffsetX * centerOffsetX + centerOffsetY * centerOffsetY;
      if (distanceSquared > radiusSquared) {
        continue;
      }

      final double sampleOffsetX = x.toDouble() - toCenter.dx;
      final double sampleOffsetY = y.toDouble() - toCenter.dy;
      final int sourceX = _clampPixel((fromCenter.dx + sampleOffsetX).round(), imageWidth);
      final int sourceY = _clampPixel((fromCenter.dy + sampleOffsetY).round(), imageHeight);
      if (!_isMaskVisible(clipMask, imageWidth, sourceX, sourceY)) {
        continue;
      }

      final int destinationSnapshotIndex = _pixelIndex(
        width: snapshotWidth,
        x: x - snapshotLeft,
        y: y - snapshotTop,
      );
      final int sourceSnapshotIndex = _pixelIndex(
        width: snapshotWidth,
        x: sourceX - snapshotLeft,
        y: sourceY - snapshotTop,
      );
      final int destinationIndex = _pixelIndex(
        width: imageWidth,
        x: x,
        y: y,
      );

      final int srcAlpha = snapshot[sourceSnapshotIndex + AppMath.rgbChannelAlpha];
      final int dstAlpha = snapshot[destinationSnapshotIndex + AppMath.rgbChannelAlpha];
      if (srcAlpha == AppMath.zero && dstAlpha == AppMath.zero) {
        continue;
      }

      final double feather = (AppVisual.full - math.sqrt(distanceSquared) / radius).clamp(
        AppMath.zero.toDouble(),
        AppVisual.full,
      );
      // Smoothstep (feather²·(3−2·feather)) rather than a bare feather². A bare
      // feather² peaks with a corner at the tip centre, so at the CPU path's dab
      // spacing each dab's peak shows through as periodic washboard ridges along
      // the stroke. Smoothstep is flat-sloped at both the centre and the edge, so
      // overlapping dabs sum smoothly. Still only multiplies — no per-pixel pow.
      final double radialFalloff = feather * feather * (3.0 - (2.0 * feather));
      final double blend = (AppInteraction.smudgeBlendStrength * intensity * radialFalloff).clamp(
        AppMath.zero.toDouble(),
        AppVisual.full,
      );
      if (blend <= AppMath.zero.toDouble()) {
        continue;
      }

      // Blend in *premultiplied* space so a transparent pixel's (meaningless)
      // RGB — e.g. the white of an opaque backdrop showing through an alpha-0
      // hole — cannot bleed into the smear as the alpha grows. Straight-RGBA
      // blending here produced a white smear front over a white background.
      if (_blendPremultipliedSample(
        pixels: pixels,
        snapshot: snapshot,
        destinationIndex: destinationIndex,
        destinationSnapshotIndex: destinationSnapshotIndex,
        sourceSnapshotIndex: sourceSnapshotIndex,
        blend: blend,
      )) {
        anyChanged = true;
      }
    }
  }

  return anyChanged;
}

/// Blends the destination pixel toward the source pixel in *premultiplied* space
/// and writes the result to [pixels] at [destinationIndex]. Both samples are read
/// from [snapshot] (the pre-step state) via their snapshot indices, so a
/// transparent pixel's undefined RGB cannot bleed in as the alpha grows and
/// overlapping dabs stay consistent. Returns whether any byte actually changed.
///
/// Shared by the directional smudge step and the radial press dab.
bool _blendPremultipliedSample({
  required final Uint8List pixels,
  required final Uint8List snapshot,
  required final int destinationIndex,
  required final int destinationSnapshotIndex,
  required final int sourceSnapshotIndex,
  required final double blend,
}) {
  final int srcAlpha = snapshot[sourceSnapshotIndex + AppMath.rgbChannelAlpha];
  final int dstAlpha = snapshot[destinationSnapshotIndex + AppMath.rgbChannelAlpha];
  final double inverseBlend = AppVisual.full - blend;
  final double newAlpha = (dstAlpha * inverseBlend) + (srcAlpha * blend);
  bool anyChanged = false;
  for (int channel = AppMath.zero; channel < AppMath.rgbChannelAlpha; channel++) {
    final double dstPremul = snapshot[destinationSnapshotIndex + channel] * dstAlpha.toDouble();
    final double srcPremul = snapshot[sourceSnapshotIndex + channel] * srcAlpha.toDouble();
    final double newPremul = (dstPremul * inverseBlend) + (srcPremul * blend);
    final int newValue = newAlpha > AppMath.zero
        ? (newPremul / newAlpha).round().clamp(AppMath.zero, AppLimits.rgbChannelMax)
        : AppMath.zero;
    if (newValue != pixels[destinationIndex + channel]) {
      anyChanged = true;
      pixels[destinationIndex + channel] = newValue;
    }
  }
  final int newAlphaByte = newAlpha.round().clamp(AppMath.zero, AppLimits.rgbChannelMax);
  if (newAlphaByte != pixels[destinationIndex + AppMath.rgbChannelAlpha]) {
    anyChanged = true;
    pixels[destinationIndex + AppMath.rgbChannelAlpha] = newAlphaByte;
  }
  return anyChanged;
}

/// Applies one radial "press" dab centred at [center]: ink is pushed outward
/// from the centre, like pressing a round stamp into wet paint. Used for a
/// smudge single tap, which has no drag direction to smear along.
///
/// Each pixel samples from a point pulled toward the centre — a fold-free bloat
/// warp: the sampled radius rises monotonically with distance and reaches the
/// pixel itself at the rim, so inner ink surfaces further out while the boundary
/// stays untouched and the dab melts into the layer. The sampled colour is then
/// blended in premultiplied space. Returns `true` when at least one pixel was
/// modified.
bool _applyPressStep({
  required final Uint8List pixels,
  required final int imageWidth,
  required final int imageHeight,
  required final Offset center,
  required final double radius,
  required final double intensity,
  required final Uint8List? clipMask,
}) {
  final double radiusSquared = radius * radius;
  final int integerRadius = radius.ceil() + AppInteraction.smudgeBoundsPadding;
  final int left = math.max(AppMath.zero, center.dx.floor() - integerRadius);
  final int top = math.max(AppMath.zero, center.dy.floor() - integerRadius);
  final int right = math.min(imageWidth - AppMath.one, center.dx.ceil() + integerRadius);
  final int bottom = math.min(imageHeight - AppMath.one, center.dy.ceil() + integerRadius);

  if (right < left || bottom < top) {
    return false;
  }

  final int rectWidth = right - left + AppMath.one;
  final int rectHeight = bottom - top + AppMath.one;
  // Snapshot the disc before modification so every destination samples a
  // consistent pre-press state (the bloat source is always inside this disc).
  final Uint8List snapshot = _copyPixelRect(
    pixels: pixels,
    imageWidth: imageWidth,
    left: left,
    top: top,
    width: rectWidth,
    height: rectHeight,
  );

  // Outward push as a fraction of the radius, clamped so the sampled radius
  // stays a monotonic (fold-free) function of distance.
  final double push = (AppInteraction.smudgePressPushFraction * intensity).clamp(
    AppMath.zero.toDouble(),
    AppInteraction.smudgePressMaxPush,
  );

  bool anyChanged = false;
  for (int y = top; y <= bottom; y++) {
    for (int x = left; x <= right; x++) {
      if (!_isMaskVisible(clipMask, imageWidth, x, y)) {
        continue;
      }

      final double offsetX = x + AppVisual.half - center.dx;
      final double offsetY = y + AppVisual.half - center.dy;
      final double distanceSquared = (offsetX * offsetX) + (offsetY * offsetY);
      if (distanceSquared > radiusSquared) {
        continue;
      }
      final double distance = math.sqrt(distanceSquared);
      if (distance <= AppMath.zero) {
        // The exact centre has no radial direction; nothing to pull inward.
        continue;
      }

      final double feather = (AppVisual.full - distance / radius).clamp(
        AppMath.zero.toDouble(),
        AppVisual.full,
      );
      // Sample from a smaller radius (pulled toward the centre) so inner ink
      // surfaces here — pushed outward. The pull peaks in the interior and
      // vanishes at the rim (feather → 0), leaving the boundary seamless.
      final double sourceDistance = math.max(AppMath.zero.toDouble(), distance - (radius * push * feather));
      final double sampleScale = sourceDistance / distance;
      final int sourceX = (center.dx + offsetX * sampleScale).round().clamp(left, right);
      final int sourceY = (center.dy + offsetY * sampleScale).round().clamp(top, bottom);
      if (!_isMaskVisible(clipMask, imageWidth, sourceX, sourceY)) {
        continue;
      }

      final int destinationSnapshotIndex = _pixelIndex(width: rectWidth, x: x - left, y: y - top);
      final int sourceSnapshotIndex = _pixelIndex(width: rectWidth, x: sourceX - left, y: sourceY - top);
      final int destinationIndex = _pixelIndex(width: imageWidth, x: x, y: y);

      final int srcAlpha = snapshot[sourceSnapshotIndex + AppMath.rgbChannelAlpha];
      final int dstAlpha = snapshot[destinationSnapshotIndex + AppMath.rgbChannelAlpha];
      if (srcAlpha == AppMath.zero && dstAlpha == AppMath.zero) {
        continue;
      }

      final double radialFalloff = feather * feather * (3.0 - (2.0 * feather));
      final double blend = (AppInteraction.smudgeBlendStrength * intensity * radialFalloff).clamp(
        AppMath.zero.toDouble(),
        AppVisual.full,
      );
      if (blend <= AppMath.zero.toDouble()) {
        continue;
      }

      if (_blendPremultipliedSample(
        pixels: pixels,
        snapshot: snapshot,
        destinationIndex: destinationIndex,
        destinationSnapshotIndex: destinationSnapshotIndex,
        sourceSnapshotIndex: sourceSnapshotIndex,
        blend: blend,
      )) {
        anyChanged = true;
      }
    }
  }

  return anyChanged;
}

/// Applies one blur step: box-blurs the pixels within [radius] around [center].
///
/// Uses a small kernel average sampled from the current [pixels] buffer.
/// Returns `true` when at least one pixel was modified.
bool _applyBlurStep({
  required final Uint8List pixels,
  required final int imageWidth,
  required final int imageHeight,
  required final Offset center,
  required final double radius,
  required final double intensity,
  required final Uint8List? clipMask,
}) {
  final double radiusSquared = radius * radius;
  final int intRadius = radius.ceil();
  final int left = math.max(AppMath.zero, center.dx.floor() - intRadius);
  final int top = math.max(AppMath.zero, center.dy.floor() - intRadius);
  final int right = math.min(imageWidth - AppMath.one, center.dx.ceil() + intRadius);
  final int bottom = math.min(imageHeight - AppMath.one, center.dy.ceil() + intRadius);

  if (right < left || bottom < top) {
    return false;
  }

  final int rectWidth = right - left + AppMath.one;
  final int rectHeight = bottom - top + AppMath.one;
  // Snapshot so every destination pixel reads unmodified source values.
  final Uint8List snapshot = _copyPixelRect(
    pixels: pixels,
    imageWidth: imageWidth,
    left: left,
    top: top,
    width: rectWidth,
    height: rectHeight,
  );

  final int kernelHalf =
      AppInteraction.blurBrushKernelHalf + (intensity * AppInteraction.blurBrushKernelHalfRange).round();
  bool anyChanged = false;

  for (int y = top; y <= bottom; y++) {
    for (int x = left; x <= right; x++) {
      if (!_isMaskVisible(clipMask, imageWidth, x, y)) {
        continue;
      }

      final double centerOffsetX = x + AppVisual.half - center.dx;
      final double centerOffsetY = y + AppVisual.half - center.dy;
      final double distanceSquared = centerOffsetX * centerOffsetX + centerOffsetY * centerOffsetY;
      if (distanceSquared > radiusSquared) {
        continue;
      }

      final double feather = (AppVisual.full - math.sqrt(distanceSquared) / radius).clamp(
        AppMath.zero.toDouble(),
        AppVisual.full,
      );
      // blurBrushEdgeFalloffExponent is 2.0 — a multiply is far cheaper than
      // math.pow() called once per pixel across the brush disc.
      final double radialFalloff = feather * feather;
      final double blend = (AppInteraction.blurBrushStrength * intensity * radialFalloff).clamp(
        AppMath.zero.toDouble(),
        AppVisual.full,
      );
      if (blend <= AppMath.zero.toDouble()) {
        continue;
      }

      // Accumulate an alpha-weighted neighborhood average. The source pixels are
      // straight (un-premultiplied) RGBA, so a plain channel average would pull
      // the undefined RGB of fully/partly transparent neighbours into the
      // result and darken the layer's edges into a halo. Weighting each colour
      // sample by its alpha — and dividing the colour sums by the summed alpha
      // rather than the sample count — recovers the correct straight colour,
      // matching the premultiplied handling the GPU path gets from
      // ui.ImageFilter.blur. Alpha itself is still a plain count average.
      int weightedR = AppMath.zero;
      int weightedG = AppMath.zero;
      int weightedB = AppMath.zero;
      int sumA = AppMath.zero;
      int count = AppMath.zero;

      for (int ky = -kernelHalf; ky <= kernelHalf; ky++) {
        for (int kx = -kernelHalf; kx <= kernelHalf; kx++) {
          final int sx = _clampPixel(x + kx - left, rectWidth);
          final int sy = _clampPixel(y + ky - top, rectHeight);
          final int si = _pixelIndex(width: rectWidth, x: sx, y: sy);
          final int sampleAlpha = snapshot[si + AppMath.rgbChannelAlpha];
          weightedR += snapshot[si + AppMath.rgbChannelRed] * sampleAlpha;
          weightedG += snapshot[si + AppMath.rgbChannelGreen] * sampleAlpha;
          weightedB += snapshot[si + AppMath.rgbChannelBlue] * sampleAlpha;
          sumA += sampleAlpha;
          count++;
        }
      }

      final int avgA = sumA ~/ count;
      // When every neighbour is fully transparent the colour is undefined; fall
      // back to zero so nothing bleeds in.
      final int avgR = sumA > AppMath.zero ? weightedR ~/ sumA : AppMath.zero;
      final int avgG = sumA > AppMath.zero ? weightedG ~/ sumA : AppMath.zero;
      final int avgB = sumA > AppMath.zero ? weightedB ~/ sumA : AppMath.zero;

      final int di = _pixelIndex(width: imageWidth, x: x, y: y);
      final int snapshotI = _pixelIndex(width: rectWidth, x: x - left, y: y - top);

      // Blend the original pixel toward the neighbourhood average in
      // premultiplied space, so a transparent original's undefined RGB (e.g. the
      // white backdrop behind an alpha-0 hole) can't bleed in as alpha rises.
      // `avgR/G/B` are alpha-corrected straight colours and `avgA` their mean
      // alpha, so `avg*·avgA` is the premultiplied average sample.
      final double inverseBlend = AppVisual.full - blend;
      final int origR = snapshot[snapshotI + AppMath.rgbChannelRed];
      final int origG = snapshot[snapshotI + AppMath.rgbChannelGreen];
      final int origB = snapshot[snapshotI + AppMath.rgbChannelBlue];
      final int origA = snapshot[snapshotI + AppMath.rgbChannelAlpha];
      final double newAlphaD = (origA * inverseBlend) + (avgA * blend);
      final int newA = newAlphaD.round().clamp(AppMath.zero, AppLimits.rgbChannelMax);
      final int newR = newAlphaD > AppMath.zero
          ? (((origR * origA) * inverseBlend + (avgR * avgA) * blend) / newAlphaD).round().clamp(
              AppMath.zero,
              AppLimits.rgbChannelMax,
            )
          : AppMath.zero;
      final int newG = newAlphaD > AppMath.zero
          ? (((origG * origA) * inverseBlend + (avgG * avgA) * blend) / newAlphaD).round().clamp(
              AppMath.zero,
              AppLimits.rgbChannelMax,
            )
          : AppMath.zero;
      final int newB = newAlphaD > AppMath.zero
          ? (((origB * origA) * inverseBlend + (avgB * avgA) * blend) / newAlphaD).round().clamp(
              AppMath.zero,
              AppLimits.rgbChannelMax,
            )
          : AppMath.zero;

      if (newR != snapshot[snapshotI + AppMath.rgbChannelRed] ||
          newG != snapshot[snapshotI + AppMath.rgbChannelGreen] ||
          newB != snapshot[snapshotI + AppMath.rgbChannelBlue] ||
          newA != snapshot[snapshotI + AppMath.rgbChannelAlpha]) {
        anyChanged = true;
        pixels[di + AppMath.rgbChannelRed] = newR;
        pixels[di + AppMath.rgbChannelGreen] = newG;
        pixels[di + AppMath.rgbChannelBlue] = newB;
        pixels[di + AppMath.rgbChannelAlpha] = newA;
      }
    }
  }

  return anyChanged;
}

/// Creates a binary alpha mask for [clipPath] that matches the source image size.
Future<Uint8List?> createPixelBrushClipMask({
  required final int width,
  required final int height,
  required final ui.Path? clipPath,
}) async {
  if (clipPath == null) {
    return null;
  }

  final ui.Image maskImage = await renderCanvasImage(
    width: width,
    height: height,
    draw: (final ui.Canvas canvas) {
      canvas.drawPath(
        clipPath,
        ui.Paint()..color = AppColors.white,
      );
    },
  );
  return extractImagePixels(maskImage);
}

/// Copies a rectangular subset of [pixels] into a packed RGBA byte array.
Uint8List _copyPixelRect({
  required final Uint8List pixels,
  required final int imageWidth,
  required final int left,
  required final int top,
  required final int width,
  required final int height,
}) {
  final Uint8List result = Uint8List(width * height * AppMath.bytesPerPixel);
  final int rowByteCount = width * AppMath.bytesPerPixel;

  for (int row = AppMath.zero; row < height; row++) {
    final int sourceOffset = _pixelIndex(
      width: imageWidth,
      x: left,
      y: top + row,
    );
    final int destinationOffset = row * rowByteCount;
    result.setRange(
      destinationOffset,
      destinationOffset + rowByteCount,
      pixels,
      sourceOffset,
    );
  }

  return result;
}

/// Writes a rectangular sub-buffer back into [destination] at [left]/[top].
void _writePixelRect({
  required final Uint8List source,
  required final Uint8List destination,
  required final int imageWidth,
  required final int left,
  required final int top,
  required final int width,
  required final int height,
}) {
  final int rowByteCount = width * AppMath.bytesPerPixel;
  for (int row = AppMath.zero; row < height; row++) {
    final int destinationOffset = _pixelIndex(
      width: imageWidth,
      x: left,
      y: top + row,
    );
    final int sourceOffset = row * rowByteCount;
    destination.setRange(
      destinationOffset,
      destinationOffset + rowByteCount,
      source,
      sourceOffset,
    );
  }
}

/// Returns whether [clipMask] includes the given pixel coordinate.
bool _isMaskVisible(
  final Uint8List? clipMask,
  final int imageWidth,
  final int x,
  final int y,
) {
  if (clipMask == null) {
    return true;
  }
  return clipMask[_pixelIndex(width: imageWidth, x: x, y: y) + AppMath.rgbChannelAlpha] > AppMath.zero;
}

/// Clamps [value] into the valid pixel range for an image extent.
int _clampPixel(final int value, final int extent) {
  return value.clamp(AppMath.zero, extent - AppMath.one);
}

/// Computes the byte offset for an RGBA pixel in a row-major image buffer.
int _pixelIndex({
  required final int width,
  required final int x,
  required final int y,
}) {
  return ((y * width) + x) * AppMath.bytesPerPixel;
}
