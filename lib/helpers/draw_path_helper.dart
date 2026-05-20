import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// Position for anchor
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

  final bool needsHorizontalScale = switch (anchorPosition) {
    NineGridHandle.left ||
    NineGridHandle.right ||
    NineGridHandle.topLeft ||
    NineGridHandle.topRight ||
    NineGridHandle.bottomLeft ||
    NineGridHandle.bottomRight => true,
    NineGridHandle.top || NineGridHandle.bottom || NineGridHandle.center => false,
  };
  final bool needsVerticalScale = switch (anchorPosition) {
    NineGridHandle.top ||
    NineGridHandle.bottom ||
    NineGridHandle.topLeft ||
    NineGridHandle.topRight ||
    NineGridHandle.bottomLeft ||
    NineGridHandle.bottomRight => true,
    NineGridHandle.left || NineGridHandle.right || NineGridHandle.center => false,
  };

  if ((needsHorizontalScale && !_isResizableExtent(bounds.width)) ||
      (needsVerticalScale && !_isResizableExtent(bounds.height))) {
    return path;
  }

  double anchorX = 0.0;
  double anchorY = 0.0;
  double scaleX = 1.0;
  double scaleY = 1.0;

  switch (anchorPosition) {
    case NineGridHandle.left:
      anchorX = bounds.right;
      scaleX = (bounds.width - expansionOffset.dx) / bounds.width;
      break;

    case NineGridHandle.right:
      anchorX = bounds.left;
      scaleX = (bounds.width + expansionOffset.dx) / bounds.width;
      break;

    case NineGridHandle.top:
      anchorY = bounds.bottom;
      scaleY = (bounds.height - expansionOffset.dy) / bounds.height;
      break;

    case NineGridHandle.bottom:
      anchorY = bounds.top;
      scaleY = (bounds.height + expansionOffset.dy) / bounds.height;
      break;

    case NineGridHandle.topLeft:
      anchorX = bounds.right;
      anchorY = bounds.bottom;
      scaleX = (bounds.width - expansionOffset.dx) / bounds.width;
      scaleY = (bounds.height - expansionOffset.dy) / bounds.height;
      break;

    case NineGridHandle.topRight:
      anchorX = bounds.left;
      anchorY = bounds.bottom;
      scaleX = (bounds.width + expansionOffset.dx) / bounds.width;
      scaleY = (bounds.height - expansionOffset.dy) / bounds.height;
      break;

    case NineGridHandle.bottomLeft:
      anchorX = bounds.right;
      anchorY = bounds.top;
      scaleX = (bounds.width - expansionOffset.dx) / bounds.width;
      scaleY = (bounds.height + expansionOffset.dy) / bounds.height;
      break;

    case NineGridHandle.bottomRight:
      anchorX = bounds.left;
      anchorY = bounds.top;
      scaleX = (bounds.width + expansionOffset.dx) / bounds.width;
      scaleY = (bounds.height + expansionOffset.dy) / bounds.height;
      break;

    case NineGridHandle.center:
      return path;
  }

  if (!scaleX.isFinite || !scaleY.isFinite) {
    return path;
  }

  final Matrix4 scaleMatrix = Matrix4.identity()
    ..translateByVector3(vm.Vector3(anchorX, anchorY, 0.0))
    ..scaleByVector3(vm.Vector3(scaleX, scaleY, 1.0))
    ..translateByVector3(vm.Vector3(-anchorX, -anchorY, 0.0));

  return path.transform(scaleMatrix.storage);
}

bool _isResizableExtent(final double extent) {
  return extent.isFinite && extent > 0.0;
}

/// Rotates the given [path] around its bounding-box center by [angleRadians].
Path rotatePathAroundCenter(final Path path, final double angleRadians) {
  final Rect bounds = path.getBounds();
  final double cx = bounds.center.dx;
  final double cy = bounds.center.dy;

  final Matrix4 matrix = Matrix4.identity()
    ..translateByVector3(vm.Vector3(cx, cy, 0))
    ..rotateZ(angleRadians)
    ..translateByVector3(vm.Vector3(-cx, -cy, 0));

  return path.transform(matrix.storage);
}

/// Scales the given [path] around its bounding-box center.
Path scalePathAroundCenter(
  final Path path,
  final double scaleX,
  final double? scaleY,
) {
  final Rect bounds = path.getBounds();
  final double cx = bounds.center.dx;
  final double cy = bounds.center.dy;
  final double effectiveScaleY = scaleY ?? scaleX;

  final Matrix4 matrix = Matrix4.identity()
    ..translateByVector3(vm.Vector3(cx, cy, 0))
    ..scaleByVector3(vm.Vector3(scaleX, effectiveScaleY, 1.0))
    ..translateByVector3(vm.Vector3(-cx, -cy, 0));

  return path.transform(matrix.storage);
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
