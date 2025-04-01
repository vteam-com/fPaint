import 'dart:math';

import 'package:flutter/material.dart';

/// Possition for anchor
enum NineGridHandle {
  left,
  right,
  top,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  center,
}

/// Expands the given [path] in the direction specified by [anchorPosition]
/// by the amount specified in [expansionOffset].
///
/// The [anchorPosition] determines which point of the path's bounding box
/// is used as the anchor for the expansion.
///
/// The [expansionOffset] specifies the amount to expand the path in the x and y directions.
Path expandPathInDirectionWithOffset(
  final Path path,
  final Offset expansionOffset,
  final NineGridHandle anchorPosition,
) {
  final Rect bounds = path.getBounds();

  final Matrix4 transformMatrix = Matrix4.identity();
  final Matrix4 scaleMatrix = Matrix4.identity();

  switch (anchorPosition) {
    case NineGridHandle.left:
      scaleMatrix
        ..translate(bounds.right, 0.0)
        ..scale((bounds.width - expansionOffset.dx) / bounds.width, 1.0)
        ..translate(-bounds.right, 0.0);
      break;

    case NineGridHandle.right:
      scaleMatrix
        ..translate(bounds.left, 0.0)
        ..scale((bounds.width + expansionOffset.dx) / bounds.width, 1.0)
        ..translate(-bounds.left, 0.0);
      break;

    case NineGridHandle.top:
      scaleMatrix
        ..translate(0.0, bounds.bottom)
        ..scale(1.0, (bounds.height - expansionOffset.dy) / bounds.height)
        ..translate(0.0, -bounds.bottom);
      break;

    case NineGridHandle.bottom:
      scaleMatrix
        ..translate(0.0, bounds.top)
        ..scale(1.0, (bounds.height + expansionOffset.dy) / bounds.height)
        ..translate(0.0, -bounds.top);
      break;

    case NineGridHandle.topLeft:
      scaleMatrix
        ..translate(bounds.right, bounds.bottom)
        ..scale(
          (bounds.width - expansionOffset.dx) / bounds.width,
          (bounds.height - expansionOffset.dy) / bounds.height,
        )
        ..translate(-bounds.right, -bounds.bottom);
      break;

    case NineGridHandle.topRight:
      scaleMatrix
        ..translate(bounds.left, bounds.bottom)
        ..scale(
          (bounds.width + expansionOffset.dx) / bounds.width,
          (bounds.height - expansionOffset.dy) / bounds.height,
        )
        ..translate(-bounds.left, -bounds.bottom);
      break;

    case NineGridHandle.bottomLeft:
      scaleMatrix
        ..translate(bounds.right, bounds.top)
        ..scale(
          (bounds.width - expansionOffset.dx) / bounds.width,
          (bounds.height + expansionOffset.dy) / bounds.height,
        )
        ..translate(-bounds.right, -bounds.top);
      break;

    case NineGridHandle.bottomRight:
      scaleMatrix
        ..translate(bounds.left, bounds.top)
        ..scale(
          (bounds.width + expansionOffset.dx) / bounds.width,
          (bounds.height + expansionOffset.dy) / bounds.height,
        )
        ..translate(-bounds.left, -bounds.top);
      break;

    case NineGridHandle.center:
      // TO DO
      break;
  }

  // Apply translation and scaling
  final Path adjustedPath = path.transform(transformMatrix.storage);
  return adjustedPath.transform(scaleMatrix.storage);
}

/// Scales the [inputSize] to fit within the specified [maxWith] and [maxHeight],
/// while maintaining the aspect ratio.
///
/// If both [maxWith] and [maxHeight] are null, the original [inputSize] is returned.
/// If only one of [maxWith] or [maxHeight] is provided, the size is scaled to fit within that dimension while maintaining aspect ratio.
Size scaleSizeTo(
  final Size inputSize, {
  final double? maxWith,
  final double? maxHeight,
}) {
  if (maxWith == null && maxHeight == null) {
    return inputSize;
  }

  double scaleWidth = 1.0;
  double scaleHeight = 1.0;

  if (maxWith != null) {
    scaleWidth = maxWith / inputSize.width;
  }

  if (maxHeight != null) {
    scaleHeight = maxHeight / inputSize.height;
  }

  // Use the smaller scale to maintain aspect ratio
  final double scale = min(scaleWidth, scaleHeight);

  return Size(
    inputSize.width * scale,
    inputSize.height * scale,
  );
}
