import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/prepared_smudge_stroke_source.dart';

part 'smudge_helper_patch.dart';
part 'smudge_helper_profiler.dart';
part 'smudge_helper_worker.dart';

/// The pixel-manipulation mode applied by the brush.
enum PixelBrushMode {
  /// Smudges pixels directionally along the stroke.
  smudge,

  /// Blurs pixels in-place under the brush tip.
  blur,
}

/// The result of rasterizing one incremental segment of a pixel-brush stroke.
///
/// [pixels] is the full RGBA image buffer with the new segment's effect
/// merged in. Feed it back as [livePixels] on the next segment call so effects
/// accumulate progressively along the stroke.
///
/// [width] × [height] match the source image dimensions.
class PixelBrushSegmentResult {
  const PixelBrushSegmentResult({
    required this.pixels,
    required this.width,
    required this.height,
  });

  final Uint8List pixels;
  final int width;
  final int height;
}

// ---------------------------------------------------------------------------
// Isolate task structs
// ---------------------------------------------------------------------------

/// Input bundle passed to the pixel-brush isolate worker.
class _PixelBrushIsolateInput {
  const _PixelBrushIsolateInput({
    required this.livePixelData,
    required this.clipMaskData,
    required this.imageWidth,
    required this.imageHeight,
    required this.segmentPoints,
    required this.brushSize,
    required this.intensity,
    required this.mode,
  });

  final TransferableTypedData livePixelData;
  final TransferableTypedData? clipMaskData;
  final int imageWidth;
  final int imageHeight;

  /// Only the new points not yet processed by a previous segment call.
  final List<Offset> segmentPoints;
  final double brushSize;
  final double intensity;
  final PixelBrushMode mode;
}

/// Output bundle returned by the pixel-brush isolate worker.
class _PixelBrushIsolateOutput {
  const _PixelBrushIsolateOutput({
    required this.resultData,
    required this.imageWidth,
    required this.imageHeight,
    required this.hasChanges,
  });

  final TransferableTypedData resultData;
  final int imageWidth;
  final int imageHeight;
  final bool hasChanges;
}

/// Plain result used by both the native isolate worker and the web fallback.
class _PixelBrushComputationResult {
  const _PixelBrushComputationResult({
    required this.pixels,
    required this.imageWidth,
    required this.imageHeight,
    required this.hasChanges,
  });

  final Uint8List pixels;
  final int imageWidth;
  final int imageHeight;
  final bool hasChanges;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Resolves the spacing between resampled pixel-brush points for [brushSize].
double resolvePixelBrushStepSpacing(final double brushSize) {
  final double radius = math.max(
    AppInteraction.smudgeMinimumRadius,
    brushSize * AppInteraction.smudgeBrushRadiusFactor,
  );
  // Dab spacing must scale with the radius: a fixed ~2px cap forced a large
  // brush to apply hundreds of full-disc dabs per stroke (O(strokeLength/2)),
  // each blending tens of thousands of pixels — the source of multi-second
  // lag. radius * 0.35 keeps ~80% disc overlap (smooth) while cutting dab count
  // by an order of magnitude for big brushes. The lower bound keeps small
  // brushes crisp.
  return math.max(
    AppInteraction.smudgeInputPointSpacing,
    radius * AppInteraction.smudgeStepSpacingFactor,
  );
}

/// Prepares source pixel data and an optional clip mask for a pixel-brush stroke.
Future<PreparedSmudgeStrokeSource?> preparePixelBrushSource({
  required final ui.Image sourceImage,
  final ui.Path? clipPath,
}) async {
  final Uint8List? sourcePixels = await extractImagePixels(
    sourceImage,
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  if (sourcePixels == null) {
    return null;
  }

  return PreparedSmudgeStrokeSource(
    image: sourceImage,
    pixels: sourcePixels,
    clipMask: await _createClipMask(
      width: sourceImage.width,
      height: sourceImage.height,
      clipPath: clipPath,
    ),
  );
}

/// Applies [mode] to [livePixels] along [segmentPoints] and returns the
/// updated full-image pixel buffer.
///
/// [livePixels] represents the current visual state of the layer (already
/// containing any prior segment effects from this stroke). Only
/// [segmentPoints] – the points not yet processed – are applied; the caller
/// must advance its "last processed" index after each call.
///
/// Returns `null` when the segment cannot produce a visible change (fewer
/// than two points, no affected pixels, etc.).
///
/// The CPU work runs in a separate [Isolate] on native platforms and falls
/// back to synchronous execution on web where `dart:isolate` transfer APIs are
/// unavailable.
Future<PixelBrushSegmentResult?> rasterizePixelBrushSegment({
  required final Uint8List livePixels,
  required final int imageWidth,
  required final int imageHeight,
  required final List<Offset> segmentPoints,
  required final double brushSize,
  final double intensity = AppInteraction.pixelBrushDefaultIntensity,
  required final PixelBrushMode mode,
  final Uint8List? clipMask,
  final bool preferSynchronous = false,
}) async {
  if (segmentPoints.length < AppMath.pair) {
    return null;
  }

  if (kIsWeb || preferSynchronous) {
    final _PixelBrushComputationResult webResult = _runPixelBrushComputation(
      livePixels: livePixels,
      clipMask: clipMask,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      segmentPoints: segmentPoints,
      brushSize: brushSize,
      intensity: intensity,
      mode: mode,
    );

    if (!webResult.hasChanges) {
      return null;
    }

    return PixelBrushSegmentResult(
      pixels: webResult.pixels,
      width: webResult.imageWidth,
      height: webResult.imageHeight,
    );
  }

  // Extract values into locals before the isolate closure to avoid
  // capturing non-sendable objects.
  final TransferableTypedData livePixelData = TransferableTypedData.fromList(<Uint8List>[livePixels]);
  final TransferableTypedData? clipMaskData = clipMask == null
      ? null
      : TransferableTypedData.fromList(<Uint8List>[clipMask]);

  final _PixelBrushIsolateOutput output = await Isolate.run<_PixelBrushIsolateOutput>(
    () => _runPixelBrushTask(
      _PixelBrushIsolateInput(
        livePixelData: livePixelData,
        clipMaskData: clipMaskData,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        segmentPoints: segmentPoints,
        brushSize: brushSize,
        intensity: intensity,
        mode: mode,
      ),
    ),
  );

  if (!output.hasChanges) {
    return null;
  }

  return PixelBrushSegmentResult(
    pixels: output.resultData.materialize().asUint8List(),
    width: output.imageWidth,
    height: output.imageHeight,
  );
}

// ---------------------------------------------------------------------------
// Isolate entry point
// ---------------------------------------------------------------------------

/// Runs the pixel-brush effect along [input.segmentPoints] and returns the
/// updated full-image pixel buffer.
///
/// The caller is responsible for passing only the *new* segment points that
/// have not yet been processed (i.e. the tail of the stroke since the last
/// call). This keeps each isolate invocation O(segment) instead of
/// O(full-stroke) and ensures effects accumulate correctly.
_PixelBrushIsolateOutput _runPixelBrushTask(final _PixelBrushIsolateInput input) {
  final _PixelBrushComputationResult result = _runPixelBrushComputation(
    livePixels: input.livePixelData.materialize().asUint8List(),
    clipMask: input.clipMaskData?.materialize().asUint8List(),
    imageWidth: input.imageWidth,
    imageHeight: input.imageHeight,
    segmentPoints: input.segmentPoints,
    brushSize: input.brushSize,
    intensity: input.intensity,
    mode: input.mode,
  );

  return _PixelBrushIsolateOutput(
    resultData: TransferableTypedData.fromList(<Uint8List>[result.pixels]),
    imageWidth: result.imageWidth,
    imageHeight: result.imageHeight,
    hasChanges: result.hasChanges,
  );
}

/// Applies one pixel-brush segment on a working buffer and returns the updated
/// full image pixels plus a change flag.
_PixelBrushComputationResult _runPixelBrushComputation({
  required final Uint8List livePixels,
  required final Uint8List? clipMask,
  required final int imageWidth,
  required final int imageHeight,
  required final List<Offset> segmentPoints,
  required final double brushSize,
  required final double intensity,
  required final PixelBrushMode mode,
}) {
  // Start from the caller's current live pixel state.
  final Uint8List pixels = livePixels;
  final double clampedIntensity = intensity.clamp(AppEffects.minIntensity, AppEffects.maxIntensity);
  final double appliedIntensity = clampedIntensity * AppInteraction.pixelBrushIntensityAppliedScale;

  final double radius = math.max(
    AppInteraction.smudgeMinimumRadius,
    brushSize * AppInteraction.smudgeBrushRadiusFactor,
  );
  final double stepSpacing = resolvePixelBrushStepSpacing(brushSize);

  // Compute the bounding box of the segment so we work only on affected rows.
  final int padding = radius.ceil() + AppInteraction.smudgeBoundsPadding;
  double minX = segmentPoints.first.dx;
  double minY = segmentPoints.first.dy;
  double maxX = segmentPoints.first.dx;
  double maxY = segmentPoints.first.dy;
  for (final Offset p in segmentPoints.skip(AppMath.one)) {
    if (p.dx < minX) {
      minX = p.dx;
    }
    if (p.dy < minY) {
      minY = p.dy;
    }
    if (p.dx > maxX) {
      maxX = p.dx;
    }
    if (p.dy > maxY) {
      maxY = p.dy;
    }
  }
  final int workingLeft = math.max(AppMath.zero, minX.floor() - padding);
  final int workingTop = math.max(AppMath.zero, minY.floor() - padding);
  final int workingRight = math.min(imageWidth - AppMath.one, maxX.ceil() + padding);
  final int workingBottom = math.min(imageHeight - AppMath.one, maxY.ceil() + padding);
  final int workingWidth = workingRight - workingLeft + AppMath.one;
  final int workingHeight = workingBottom - workingTop + AppMath.one;

  if (workingWidth <= AppMath.zero || workingHeight <= AppMath.zero) {
    return _PixelBrushComputationResult(
      pixels: pixels,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      hasChanges: false,
    );
  }

  // Extract a working sub-buffer so inner loops index cheaply.
  final Uint8List workingPixels = _copyPixelRect(
    pixels: pixels,
    imageWidth: imageWidth,
    left: workingLeft,
    top: workingTop,
    width: workingWidth,
    height: workingHeight,
  );
  final Uint8List? workingClipMask = clipMask == null
      ? null
      : _copyPixelRect(
          pixels: clipMask,
          imageWidth: imageWidth,
          left: workingLeft,
          top: workingTop,
          width: workingWidth,
          height: workingHeight,
        );

  bool anyChanges = false;
  final ui.Offset origin = ui.Offset(workingLeft.toDouble(), workingTop.toDouble());

  for (int idx = AppMath.one; idx < segmentPoints.length; idx++) {
    final Offset segStart = segmentPoints[idx - AppMath.one] - origin;
    final Offset segEnd = segmentPoints[idx] - origin;
    final double dist = (segEnd - segStart).distance;
    final int steps = math.max(AppMath.one, (dist / stepSpacing).ceil());
    Offset prevCenter = segStart;

    for (int step = AppMath.one; step <= steps; step++) {
      final double t = step / steps;
      final Offset curCenter = Offset.lerp(segStart, segEnd, t) ?? segEnd;

      final bool stepChanged;
      switch (mode) {
        case PixelBrushMode.smudge:
          stepChanged = _applySmudgeStep(
            pixels: workingPixels,
            imageWidth: workingWidth,
            imageHeight: workingHeight,
            fromCenter: prevCenter,
            toCenter: curCenter,
            radius: radius,
            intensity: appliedIntensity,
            clipMask: workingClipMask,
          );
        case PixelBrushMode.blur:
          stepChanged = _applyBlurStep(
            pixels: workingPixels,
            imageWidth: workingWidth,
            imageHeight: workingHeight,
            center: curCenter,
            radius: radius,
            intensity: appliedIntensity,
            clipMask: workingClipMask,
          );
      }

      if (stepChanged) {
        anyChanges = true;
      }
      prevCenter = curCenter;
    }
  }

  if (!anyChanges) {
    return _PixelBrushComputationResult(
      pixels: pixels,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      hasChanges: false,
    );
  }

  // Write the modified sub-buffer back into the full pixel array.
  _writePixelRect(
    source: workingPixels,
    destination: pixels,
    imageWidth: imageWidth,
    left: workingLeft,
    top: workingTop,
    width: workingWidth,
    height: workingHeight,
  );

  return _PixelBrushComputationResult(
    pixels: pixels,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    hasChanges: true,
  );
}

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
      // smudgeEdgeFalloffExponent is 2.0 — a multiply is far cheaper than
      // math.pow() called once per pixel across the brush disc.
      final double radialFalloff = feather * feather;
      final double blend = (AppInteraction.smudgeBlendStrength * intensity * radialFalloff).clamp(
        AppMath.zero.toDouble(),
        AppVisual.full,
      );
      if (blend <= AppMath.zero.toDouble()) {
        continue;
      }

      for (int channel = AppMath.zero; channel < AppMath.bytesPerPixel; channel++) {
        final int oldValue = snapshot[destinationSnapshotIndex + channel];
        final int newValue = ((oldValue * (AppVisual.full - blend)) + (snapshot[sourceSnapshotIndex + channel] * blend))
            .round()
            .clamp(AppMath.zero, AppLimits.rgbChannelMax);
        if (newValue != oldValue) {
          anyChanged = true;
          pixels[destinationIndex + channel] = newValue;
        }
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

      // Accumulate the neighborhood average.
      int sumR = AppMath.zero;
      int sumG = AppMath.zero;
      int sumB = AppMath.zero;
      int sumA = AppMath.zero;
      int count = AppMath.zero;

      for (int ky = -kernelHalf; ky <= kernelHalf; ky++) {
        for (int kx = -kernelHalf; kx <= kernelHalf; kx++) {
          final int sx = _clampPixel(x + kx - left, rectWidth);
          final int sy = _clampPixel(y + ky - top, rectHeight);
          final int si = _pixelIndex(width: rectWidth, x: sx, y: sy);
          sumR += snapshot[si + AppMath.rgbChannelRed];
          sumG += snapshot[si + AppMath.rgbChannelGreen];
          sumB += snapshot[si + AppMath.rgbChannelBlue];
          sumA += snapshot[si + AppMath.rgbChannelAlpha];
          count++;
        }
      }

      final int avgR = sumR ~/ count;
      final int avgG = sumG ~/ count;
      final int avgB = sumB ~/ count;
      final int avgA = sumA ~/ count;

      final int di = _pixelIndex(width: imageWidth, x: x, y: y);
      final int snapshotI = _pixelIndex(width: rectWidth, x: x - left, y: y - top);

      final int newR = (snapshot[snapshotI + AppMath.rgbChannelRed] * (AppVisual.full - blend) + avgR * blend)
          .round()
          .clamp(AppMath.zero, AppLimits.rgbChannelMax);
      final int newG = (snapshot[snapshotI + AppMath.rgbChannelGreen] * (AppVisual.full - blend) + avgG * blend)
          .round()
          .clamp(AppMath.zero, AppLimits.rgbChannelMax);
      final int newB = (snapshot[snapshotI + AppMath.rgbChannelBlue] * (AppVisual.full - blend) + avgB * blend)
          .round()
          .clamp(AppMath.zero, AppLimits.rgbChannelMax);
      final int newA = (snapshot[snapshotI + AppMath.rgbChannelAlpha] * (AppVisual.full - blend) + avgA * blend)
          .round()
          .clamp(AppMath.zero, AppLimits.rgbChannelMax);

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
Future<Uint8List?> _createClipMask({
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
