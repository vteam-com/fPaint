import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/prepared_smudge_stroke_source.dart';

/// The rasterized replacement region produced by a smudge stroke.
class SmudgeStrokeRasterResult {
  const SmudgeStrokeRasterResult({
    required this.image,
    required this.bounds,
  });

  final ui.Image image;
  final ui.Rect bounds;
}

/// Resolves the spacing between resampled smudge points for [brushSize].
double resolveSmudgeStepSpacing(final double brushSize) {
  final double radius = math.max(
    AppInteraction.smudgeMinimumRadius,
    brushSize * AppInteraction.smudgeBrushRadiusFactor,
  );
  return math.max(
    AppInteraction.smudgeInputPointSpacing,
    radius * AppInteraction.smudgeStepSpacingFactor,
  );
}

/// Prepares source pixel data and an optional clip mask for a smudge stroke.
Future<PreparedSmudgeStrokeSource?> prepareSmudgeStrokeSource({
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

/// Rasterizes a smudge stroke against [sourceImage] and returns the changed area.
Future<SmudgeStrokeRasterResult?> rasterizeSmudgeStroke({
  required final ui.Image sourceImage,
  required final List<Offset> strokePoints,
  required final double brushSize,
  final ui.Path? clipPath,
  final PreparedSmudgeStrokeSource? preparedSource,
}) async {
  if (strokePoints.length < AppMath.pair) {
    return null;
  }

  final PreparedSmudgeStrokeSource? activeSource =
      preparedSource ??
      await prepareSmudgeStrokeSource(
        sourceImage: sourceImage,
        clipPath: clipPath,
      );
  if (activeSource == null) {
    return null;
  }

  final ui.Image activeImage = activeSource.image;
  final Uint8List? clipMask = activeSource.clipMask;

  final double radius = math.max(
    AppInteraction.smudgeMinimumRadius,
    brushSize * AppInteraction.smudgeBrushRadiusFactor,
  );
  final double stepSpacing = resolveSmudgeStepSpacing(brushSize);
  final ui.Rect workingBounds = _resolveWorkingBounds(
    strokePoints: strokePoints,
    imageWidth: activeImage.width,
    imageHeight: activeImage.height,
    radius: radius,
  );
  final int workingLeft = workingBounds.left.floor();
  final int workingTop = workingBounds.top.floor();
  final int workingWidth = workingBounds.width.ceil();
  final int workingHeight = workingBounds.height.ceil();
  final Uint8List workingPixels = _copyPixelRect(
    pixels: activeSource.pixels,
    imageWidth: activeImage.width,
    left: workingLeft,
    top: workingTop,
    width: workingWidth,
    height: workingHeight,
  );
  final Uint8List? workingClipMask = clipMask == null
      ? null
      : _copyPixelRect(
          pixels: clipMask,
          imageWidth: activeImage.width,
          left: workingLeft,
          top: workingTop,
          width: workingWidth,
          height: workingHeight,
        );

  int dirtyLeft = workingWidth;
  int dirtyTop = workingHeight;
  int dirtyRight = -AppMath.one;
  int dirtyBottom = -AppMath.one;

  for (int index = AppMath.one; index < strokePoints.length; index++) {
    final Offset segmentStart = strokePoints[index - AppMath.one] - workingBounds.topLeft;
    final Offset segmentEnd = strokePoints[index] - workingBounds.topLeft;
    final double distance = (segmentEnd - segmentStart).distance;
    final int stepCount = math.max(AppMath.one, (distance / stepSpacing).ceil());
    Offset previousCenter = segmentStart;

    for (int step = AppMath.one; step <= stepCount; step++) {
      final double progress = step / stepCount;
      final Offset currentCenter = Offset.lerp(segmentStart, segmentEnd, progress) ?? segmentEnd;
      final ui.Rect? dirtyRect = _applySmudgeStep(
        pixels: workingPixels,
        imageWidth: workingWidth,
        imageHeight: workingHeight,
        fromCenter: previousCenter,
        toCenter: currentCenter,
        radius: radius,
        clipMask: workingClipMask,
      );

      if (dirtyRect != null) {
        dirtyLeft = math.min(dirtyLeft, dirtyRect.left.floor());
        dirtyTop = math.min(dirtyTop, dirtyRect.top.floor());
        dirtyRight = math.max(dirtyRight, dirtyRect.right.ceil() - AppMath.one);
        dirtyBottom = math.max(dirtyBottom, dirtyRect.bottom.ceil() - AppMath.one);
      }

      previousCenter = currentCenter;
    }
  }

  if (dirtyRight < dirtyLeft || dirtyBottom < dirtyTop) {
    return null;
  }

  final int cropWidth = dirtyRight - dirtyLeft + AppMath.one;
  final int cropHeight = dirtyBottom - dirtyTop + AppMath.one;
  final Uint8List croppedPixels = _copyPixelRect(
    pixels: workingPixels,
    imageWidth: workingWidth,
    left: dirtyLeft,
    top: dirtyTop,
    width: cropWidth,
    height: cropHeight,
  );

  return SmudgeStrokeRasterResult(
    image: await imageFromPixels(croppedPixels, cropWidth, cropHeight),
    bounds: ui.Rect.fromLTWH(
      workingBounds.left + dirtyLeft,
      workingBounds.top + dirtyTop,
      cropWidth.toDouble(),
      cropHeight.toDouble(),
    ),
  );
}

/// Resolves the stroke-bounded working region that needs pixel processing.
ui.Rect _resolveWorkingBounds({
  required final List<Offset> strokePoints,
  required final int imageWidth,
  required final int imageHeight,
  required final double radius,
}) {
  final int padding = radius.ceil() + AppInteraction.smudgeBoundsPadding;
  double minX = strokePoints.first.dx;
  double minY = strokePoints.first.dy;
  double maxX = strokePoints.first.dx;
  double maxY = strokePoints.first.dy;

  for (final Offset point in strokePoints.skip(AppMath.one)) {
    minX = math.min(minX, point.dx);
    minY = math.min(minY, point.dy);
    maxX = math.max(maxX, point.dx);
    maxY = math.max(maxY, point.dy);
  }

  final int left = math.max(AppMath.zero, minX.floor() - padding);
  final int top = math.max(AppMath.zero, minY.floor() - padding);
  final int right = math.min(imageWidth - AppMath.one, maxX.ceil() + padding);
  final int bottom = math.min(imageHeight - AppMath.one, maxY.ceil() + padding);

  return ui.Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    (right + AppMath.one).toDouble(),
    (bottom + AppMath.one).toDouble(),
  );
}

/// Applies one incremental smudge step and returns the modified destination bounds.
ui.Rect? _applySmudgeStep({
  required final Uint8List pixels,
  required final int imageWidth,
  required final int imageHeight,
  required final Offset fromCenter,
  required final Offset toCenter,
  required final double radius,
  required final Uint8List? clipMask,
}) {
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
    return null;
  }

  final int rectWidth = right - left + AppMath.one;
  final int rectHeight = bottom - top + AppMath.one;
  final Uint8List snapshot = _copyPixelRect(
    pixels: pixels,
    imageWidth: imageWidth,
    left: left,
    top: top,
    width: rectWidth,
    height: rectHeight,
  );

  int dirtyLeft = imageWidth;
  int dirtyTop = imageHeight;
  int dirtyRight = -AppMath.one;
  int dirtyBottom = -AppMath.one;

  for (int y = top; y <= bottom; y++) {
    for (int x = left; x <= right; x++) {
      if (!_isMaskVisible(clipMask, imageWidth, x, y)) {
        continue;
      }

      final double centerOffsetX = x + AppVisual.half - toCenter.dx;
      final double centerOffsetY = y + AppVisual.half - toCenter.dy;
      final double distanceSquared = centerOffsetX * centerOffsetX + centerOffsetY * centerOffsetY;
      if (distanceSquared > radius * radius) {
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
        width: rectWidth,
        x: x - left,
        y: y - top,
      );
      final int sourceSnapshotIndex = _pixelIndex(
        width: rectWidth,
        x: sourceX - left,
        y: sourceY - top,
      );
      final int destinationIndex = _pixelIndex(
        width: imageWidth,
        x: x,
        y: y,
      );

      final int sourceAlpha = snapshot[sourceSnapshotIndex + AppMath.rgbChannelAlpha];
      final int destinationAlpha = snapshot[destinationSnapshotIndex + AppMath.rgbChannelAlpha];
      if (sourceAlpha == AppMath.zero && destinationAlpha == AppMath.zero) {
        continue;
      }

      final double feather = AppVisual.full - math.sqrt(distanceSquared) / radius;
      final double blend = AppInteraction.smudgeBlendStrength * feather.clamp(AppMath.zero.toDouble(), AppVisual.full);
      if (blend <= AppMath.zero.toDouble()) {
        continue;
      }

      bool changed = false;
      for (int channel = AppMath.zero; channel < AppMath.bytesPerPixel; channel++) {
        final int oldValue = snapshot[destinationSnapshotIndex + channel];
        final int newValue = ((oldValue * (AppVisual.full - blend)) + (snapshot[sourceSnapshotIndex + channel] * blend))
            .round()
            .clamp(AppMath.zero, AppLimits.rgbChannelMax);
        if (newValue != oldValue) {
          changed = true;
          pixels[destinationIndex + channel] = newValue;
        }
      }

      if (changed) {
        dirtyLeft = math.min(dirtyLeft, x);
        dirtyTop = math.min(dirtyTop, y);
        dirtyRight = math.max(dirtyRight, x);
        dirtyBottom = math.max(dirtyBottom, y);
      }
    }
  }

  if (dirtyRight < dirtyLeft || dirtyBottom < dirtyTop) {
    return null;
  }

  return ui.Rect.fromLTRB(
    dirtyLeft.toDouble(),
    dirtyTop.toDouble(),
    (dirtyRight + AppMath.one).toDouble(),
    (dirtyBottom + AppMath.one).toDouble(),
  );
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
