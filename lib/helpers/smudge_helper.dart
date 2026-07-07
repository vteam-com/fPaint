import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';

// Low-level per-step pixel operations (smudge / press / blur dabs and the
// shared premultiplied blend + pixel-rect utilities) live in a part file to
// keep this library's orchestration file within the code-size budget.
part 'smudge_helper_steps.dart';

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
  // Dab spacing scales with the radius so large brushes don't emit an absurd
  // dab count. The whole stroke is rasterized once on pointer-up (the drag only
  // draws a marquee), so the spacing is tuned for a smooth trail rather than
  // per-move speed; see [AppInteraction.smudgeStepSpacingFactor]. The lower
  // bound keeps small brushes crisp.
  return math.max(
    AppInteraction.smudgeInputPointSpacing,
    radius * AppInteraction.smudgeStepSpacingFactor,
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
/// A single point is a tap: smudge presses the ink outward from that point
/// (like pressing a stamp into wet paint) and blur softens it — rather than a
/// directional smear.
///
/// Returns `null` when the segment cannot produce a visible change (no points,
/// no affected pixels, etc.).
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
  if (segmentPoints.length < AppMath.one) {
    return null;
  }

  if (kIsWeb || preferSynchronous) {
    final _PixelBrushComputationResult webResult = _runPixelBrushComputationLod(
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
  final _PixelBrushComputationResult result = _runPixelBrushComputationLod(
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

/// Level-of-detail wrapper around [_runPixelBrushComputation].
///
/// The per-dab cost is O(radius²), so a large brush is prohibitively slow at
/// full resolution (a 500 px brush measured ~5–6 s). Smudge and blur are
/// low-frequency effects, so for radii above [AppInteraction.smudgeComputeLodMinRadius]
/// we downscale the region by an integer factor, run the effect on the small
/// buffer (cost drops by factor²), and bilinearly upsample the result. Small
/// brushes run full-resolution unchanged. This is the CPU analog of Krita's
/// "Instant Preview" — the softening is invisible at large brush sizes.
///
/// A single-point dab (a tap) always runs full-resolution regardless of brush
/// size: the upsample regenerates the *whole* region, so the untouched margin
/// around the small dab would come back blurred and — since the commit
/// src-replaces the entire rectangular footprint — stamp a visible square over
/// the crisp layer. One disc is cheap at full res (a drag pays LOD across its
/// hundreds of dabs; a tap does not).
_PixelBrushComputationResult _runPixelBrushComputationLod({
  required final Uint8List livePixels,
  required final Uint8List? clipMask,
  required final int imageWidth,
  required final int imageHeight,
  required final List<Offset> segmentPoints,
  required final double brushSize,
  required final double intensity,
  required final PixelBrushMode mode,
}) {
  final double radius = math.max(
    AppInteraction.smudgeMinimumRadius,
    brushSize * AppInteraction.smudgeBrushRadiusFactor,
  );
  final bool singleDab = segmentPoints.length < AppMath.pair;
  final int factor = (singleDab || radius <= AppInteraction.smudgeComputeLodMinRadius)
      ? AppMath.one
      : (radius / AppInteraction.smudgeComputeLodTargetRadius).round().clamp(
          AppMath.pair,
          AppInteraction.smudgeComputeLodMaxFactor,
        );
  final int lowWidth = imageWidth ~/ factor;
  final int lowHeight = imageHeight ~/ factor;
  if (factor <= AppMath.one || lowWidth < AppMath.pair || lowHeight < AppMath.pair) {
    return _runPixelBrushComputation(
      livePixels: livePixels,
      clipMask: clipMask,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      segmentPoints: segmentPoints,
      brushSize: brushSize,
      intensity: intensity,
      mode: mode,
    );
  }

  final double scaleX = lowWidth / imageWidth;
  final double scaleY = lowHeight / imageHeight;
  final Uint8List lowPixels = downsampleRgbaBox(livePixels, imageWidth, imageHeight, lowWidth, lowHeight);
  final Uint8List? lowMask = clipMask == null
      ? null
      : downsampleRgbaBox(clipMask, imageWidth, imageHeight, lowWidth, lowHeight);
  final List<Offset> lowPoints = <Offset>[
    for (final Offset point in segmentPoints) Offset(point.dx * scaleX, point.dy * scaleY),
  ];

  final _PixelBrushComputationResult low = _runPixelBrushComputation(
    livePixels: lowPixels,
    clipMask: lowMask,
    imageWidth: lowWidth,
    imageHeight: lowHeight,
    segmentPoints: lowPoints,
    brushSize: brushSize * scaleX,
    intensity: intensity,
    mode: mode,
  );

  if (!low.hasChanges) {
    return _PixelBrushComputationResult(
      pixels: livePixels,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      hasChanges: false,
    );
  }

  return _PixelBrushComputationResult(
    pixels: _upsampleRgbaBilinear(low.pixels, lowWidth, lowHeight, imageWidth, imageHeight),
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    hasChanges: true,
  );
}

/// Bilinear upscale of a straight-RGBA buffer.
Uint8List _upsampleRgbaBilinear(
  final Uint8List src,
  final int srcWidth,
  final int srcHeight,
  final int dstWidth,
  final int dstHeight,
) {
  final Uint8List out = Uint8List(dstWidth * dstHeight * AppMath.bytesPerPixel);
  final double fx = srcWidth / dstWidth;
  final double fy = srcHeight / dstHeight;
  for (int dy = AppMath.zero; dy < dstHeight; dy++) {
    double syf = (dy + AppVisual.half) * fy - AppVisual.half;
    if (syf < AppMath.zero) {
      syf = AppMath.zero.toDouble();
    }
    final int sy0 = math.min(syf.floor(), srcHeight - AppMath.one);
    final int sy1 = math.min(sy0 + AppMath.one, srcHeight - AppMath.one);
    final double wy = syf - sy0;
    for (int dx = AppMath.zero; dx < dstWidth; dx++) {
      double sxf = (dx + AppVisual.half) * fx - AppVisual.half;
      if (sxf < AppMath.zero) {
        sxf = AppMath.zero.toDouble();
      }
      final int sx0 = math.min(sxf.floor(), srcWidth - AppMath.one);
      final int sx1 = math.min(sx0 + AppMath.one, srcWidth - AppMath.one);
      final double wx = sxf - sx0;
      final int i00 = ((sy0 * srcWidth) + sx0) * AppMath.bytesPerPixel;
      final int i01 = ((sy0 * srcWidth) + sx1) * AppMath.bytesPerPixel;
      final int i10 = ((sy1 * srcWidth) + sx0) * AppMath.bytesPerPixel;
      final int i11 = ((sy1 * srcWidth) + sx1) * AppMath.bytesPerPixel;
      final int oi = ((dy * dstWidth) + dx) * AppMath.bytesPerPixel;
      for (int c = AppMath.zero; c < AppMath.bytesPerPixel; c++) {
        final double top = src[i00 + c] * (AppMath.one - wx) + src[i01 + c] * wx;
        final double bottom = src[i10 + c] * (AppMath.one - wx) + src[i11 + c] * wx;
        out[oi + c] = (top * (AppMath.one - wy) + bottom * wy).round().clamp(AppMath.zero, AppLimits.rgbChannelMax);
      }
    }
  }
  return out;
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

  if (segmentPoints.length == AppMath.one) {
    // A single tap has no drag direction, so there is no segment to sweep along.
    // Deposit one dab at the tap point: smudge presses the ink radially outward
    // from the centre (like pressing a stamp into wet paint), while blur softens
    // the spot. A drag still smudges/blurs directionally through the loop below.
    final ui.Offset center = segmentPoints.first - origin;
    switch (mode) {
      case PixelBrushMode.smudge:
        anyChanges = _applyPressStep(
          pixels: workingPixels,
          imageWidth: workingWidth,
          imageHeight: workingHeight,
          center: center,
          radius: radius,
          intensity: appliedIntensity,
          clipMask: workingClipMask,
        );
      case PixelBrushMode.blur:
        anyChanges = _applyBlurStep(
          pixels: workingPixels,
          imageWidth: workingWidth,
          imageHeight: workingHeight,
          center: center,
          radius: radius,
          intensity: appliedIntensity,
          clipMask: workingClipMask,
        );
    }
  }

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
