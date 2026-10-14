part of 'smudge_helper.dart';

// ---------------------------------------------------------------------------
// Per-step pixel operations
// ---------------------------------------------------------------------------

/// Applies one incremental smudge step: samples pixels at [fromCenter] offset
/// and blends them into [toCenter] position within [radius].
///
/// Returns `true` when at least one pixel was modified.
bool _applySmudgeStep({
  required Uint8List pixels,
  required int imageWidth,
  required int imageHeight,
  required Offset fromCenter,
  required Offset toCenter,
  required double radius,
  required double intensity,
  required Uint8List? clipMask,
}) {
  final double radiusSquared = radius * radius;
  final _DabBounds? bounds = _clampedDabBounds(
    minX: math.min(fromCenter.dx, toCenter.dx),
    minY: math.min(fromCenter.dy, toCenter.dy),
    maxX: math.max(fromCenter.dx, toCenter.dx),
    maxY: math.max(fromCenter.dy, toCenter.dy),
    padding: resolvePixelBrushPadding(radius),
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );
  if (bounds == null) {
    return false;
  }
  final int left = bounds.left;
  final int top = bounds.top;
  final int right = bounds.right;
  final int bottom = bounds.bottom;

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
  final Uint8List snapshot = copyRgbaRect(
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

      final double feather = _discFeather(math.sqrt(distanceSquared), radius);
      final double blend = _dabBlend(AppInteraction.smudgeBlendStrength, intensity, _smoothstep(feather));
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
  required Uint8List pixels,
  required Uint8List snapshot,
  required int destinationIndex,
  required int destinationSnapshotIndex,
  required int sourceSnapshotIndex,
  required double blend,
}) {
  return _writePremultipliedBlend(
    pixels: pixels,
    destinationIndex: destinationIndex,
    dstRed: snapshot[destinationSnapshotIndex + AppMath.rgbChannelRed],
    dstGreen: snapshot[destinationSnapshotIndex + AppMath.rgbChannelGreen],
    dstBlue: snapshot[destinationSnapshotIndex + AppMath.rgbChannelBlue],
    dstAlpha: snapshot[destinationSnapshotIndex + AppMath.rgbChannelAlpha],
    srcRed: snapshot[sourceSnapshotIndex + AppMath.rgbChannelRed],
    srcGreen: snapshot[sourceSnapshotIndex + AppMath.rgbChannelGreen],
    srcBlue: snapshot[sourceSnapshotIndex + AppMath.rgbChannelBlue],
    srcAlpha: snapshot[sourceSnapshotIndex + AppMath.rgbChannelAlpha],
    blend: blend,
  );
}

/// Blends the straight-RGBA destination sample toward the straight-RGBA source
/// sample by [blend] in *premultiplied* space and writes the straight result
/// into [pixels] at [destinationIndex]. Returns whether any byte changed.
///
/// Shared by the smudge/press sample blend and the blur neighbourhood blend.
bool _writePremultipliedBlend({
  required Uint8List pixels,
  required int destinationIndex,
  required int dstRed,
  required int dstGreen,
  required int dstBlue,
  required int dstAlpha,
  required int srcRed,
  required int srcGreen,
  required int srcBlue,
  required int srcAlpha,
  required double blend,
}) {
  final double inverseBlend = AppVisual.full - blend;
  final double newAlpha = (dstAlpha * inverseBlend) + (srcAlpha * blend);
  final int newRed = _blendPremultipliedChannel(dstRed, dstAlpha, srcRed, srcAlpha, inverseBlend, blend, newAlpha);
  final int newGreen = _blendPremultipliedChannel(
    dstGreen,
    dstAlpha,
    srcGreen,
    srcAlpha,
    inverseBlend,
    blend,
    newAlpha,
  );
  final int newBlue = _blendPremultipliedChannel(dstBlue, dstAlpha, srcBlue, srcAlpha, inverseBlend, blend, newAlpha);
  final int newAlphaByte = newAlpha.round().clamp(AppMath.zero, AppLimits.rgbChannelMax);
  if (newRed == pixels[destinationIndex + AppMath.rgbChannelRed] &&
      newGreen == pixels[destinationIndex + AppMath.rgbChannelGreen] &&
      newBlue == pixels[destinationIndex + AppMath.rgbChannelBlue] &&
      newAlphaByte == pixels[destinationIndex + AppMath.rgbChannelAlpha]) {
    return false;
  }
  pixels[destinationIndex + AppMath.rgbChannelRed] = newRed;
  pixels[destinationIndex + AppMath.rgbChannelGreen] = newGreen;
  pixels[destinationIndex + AppMath.rgbChannelBlue] = newBlue;
  pixels[destinationIndex + AppMath.rgbChannelAlpha] = newAlphaByte;
  return true;
}

/// Blends one colour channel in premultiplied space and divides it back out
/// by [newAlpha], returning the straight byte (zero when fully transparent).
int _blendPremultipliedChannel(
  int dst,
  int dstAlpha,
  int src,
  int srcAlpha,
  double inverseBlend,
  double blend,
  double newAlpha,
) {
  if (newAlpha <= AppMath.zero) {
    return AppMath.zero;
  }
  final double newPremul = ((dst * dstAlpha) * inverseBlend) + ((src * srcAlpha) * blend);
  return (newPremul / newAlpha).round().clamp(AppMath.zero, AppLimits.rgbChannelMax);
}

/// Inclusive pixel bounds of a dab footprint, clamped to the image.
typedef _DabBounds = ({int left, int top, int right, int bottom});

/// Returns the inclusive pixel bounds covering the box [minX]..[maxX] ×
/// [minY]..[maxY] grown by [padding], clamped to the image; `null` when the
/// clamped box is empty.
_DabBounds? _clampedDabBounds({
  required double minX,
  required double minY,
  required double maxX,
  required double maxY,
  required int padding,
  required int imageWidth,
  required int imageHeight,
}) {
  final int left = math.max(AppMath.zero, minX.floor() - padding);
  final int top = math.max(AppMath.zero, minY.floor() - padding);
  final int right = math.min(imageWidth - AppMath.one, maxX.ceil() + padding);
  final int bottom = math.min(imageHeight - AppMath.one, maxY.ceil() + padding);
  if (right < left || bottom < top) {
    return null;
  }
  return (left: left, top: top, right: right, bottom: bottom);
}

/// Linear disc feather: 1 at the centre, 0 at [radius] and beyond.
double _discFeather(double distance, double radius) {
  return (AppVisual.full - distance / radius).clamp(AppMath.zero.toDouble(), AppVisual.full);
}

/// Cubic smoothstep of [feather]: `feather²·(3 − 2·feather)`.
///
/// Used rather than a bare feather², which peaks with a corner at the tip
/// centre so that at the CPU path's dab spacing each dab's peak shows through
/// as periodic washboard ridges along the stroke. Smoothstep is flat-sloped at
/// both the centre and the edge, so overlapping dabs sum smoothly. Still only
/// multiplies — no per-pixel pow.
double _smoothstep(double feather) {
  return feather * feather * (AppMath.smoothstepEdgeWeight - (AppMath.smoothstepSlopeWeight * feather));
}

/// Per-pixel blend weight: [strength] × [intensity] × [falloff], clamped to 0..1.
double _dabBlend(double strength, double intensity, double falloff) {
  return (strength * intensity * falloff).clamp(AppMath.zero.toDouble(), AppVisual.full);
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
  required Uint8List pixels,
  required int imageWidth,
  required int imageHeight,
  required Offset center,
  required double radius,
  required double intensity,
  required Uint8List? clipMask,
}) {
  final double radiusSquared = radius * radius;
  final _DabBounds? bounds = _clampedDabBounds(
    minX: center.dx,
    minY: center.dy,
    maxX: center.dx,
    maxY: center.dy,
    padding: resolvePixelBrushPadding(radius),
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );
  if (bounds == null) {
    return false;
  }
  final int left = bounds.left;
  final int top = bounds.top;
  final int right = bounds.right;
  final int bottom = bounds.bottom;

  final int rectWidth = right - left + AppMath.one;
  final int rectHeight = bottom - top + AppMath.one;
  // Snapshot the disc before modification so every destination samples a
  // consistent pre-press state (the bloat source is always inside this disc).
  final Uint8List snapshot = copyRgbaRect(
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

      final double feather = _discFeather(distance, radius);
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

      final double blend = _dabBlend(AppInteraction.smudgeBlendStrength, intensity, _smoothstep(feather));
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
  required Uint8List pixels,
  required int imageWidth,
  required int imageHeight,
  required Offset center,
  required double radius,
  required double intensity,
  required Uint8List? clipMask,
}) {
  final double radiusSquared = radius * radius;
  final _DabBounds? bounds = _clampedDabBounds(
    minX: center.dx,
    minY: center.dy,
    maxX: center.dx,
    maxY: center.dy,
    padding: radius.ceil(),
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );
  if (bounds == null) {
    return false;
  }
  final int left = bounds.left;
  final int top = bounds.top;
  final int right = bounds.right;
  final int bottom = bounds.bottom;

  final int rectWidth = right - left + AppMath.one;
  final int rectHeight = bottom - top + AppMath.one;
  // Snapshot so every destination pixel reads unmodified source values.
  final Uint8List snapshot = copyRgbaRect(
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

      final double feather = _discFeather(math.sqrt(distanceSquared), radius);
      // Quadratic edge falloff — a multiply is far cheaper than math.pow()
      // called once per pixel across the brush disc.
      final double blend = _dabBlend(AppInteraction.blurBrushStrength, intensity, feather * feather);
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
      if (_writePremultipliedBlend(
        pixels: pixels,
        destinationIndex: di,
        dstRed: snapshot[snapshotI + AppMath.rgbChannelRed],
        dstGreen: snapshot[snapshotI + AppMath.rgbChannelGreen],
        dstBlue: snapshot[snapshotI + AppMath.rgbChannelBlue],
        dstAlpha: snapshot[snapshotI + AppMath.rgbChannelAlpha],
        srcRed: avgR,
        srcGreen: avgG,
        srcBlue: avgB,
        srcAlpha: avgA,
        blend: blend,
      )) {
        anyChanged = true;
      }
    }
  }

  return anyChanged;
}

/// Creates a binary alpha mask for [clipPath] that matches the source image size.
Future<Uint8List?> createPixelBrushClipMask({
  required int width,
  required int height,
  required ui.Path? clipPath,
}) async {
  if (clipPath == null) {
    return null;
  }

  final ui.Image maskImage = await renderCanvasImage(
    width: width,
    height: height,
    draw: (ui.Canvas canvas) {
      canvas.drawPath(
        clipPath,
        ui.Paint()..color = AppColors.white,
      );
    },
  );
  return extractImagePixels(maskImage);
}

/// Returns whether [clipMask] includes the given pixel coordinate.
bool _isMaskVisible(
  Uint8List? clipMask,
  int imageWidth,
  int x,
  int y,
) {
  if (clipMask == null) {
    return true;
  }
  return clipMask[_pixelIndex(width: imageWidth, x: x, y: y) + AppMath.rgbChannelAlpha] > AppMath.zero;
}

/// Clamps [value] into the valid pixel range for an image extent.
int _clampPixel(int value, int extent) {
  return value.clamp(AppMath.zero, extent - AppMath.one);
}

/// Computes the byte offset for an RGBA pixel in a row-major image buffer.
int _pixelIndex({
  required int width,
  required int x,
  required int y,
}) {
  return ((y * width) + x) * AppMath.bytesPerPixel;
}
