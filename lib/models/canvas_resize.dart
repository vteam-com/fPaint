import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';

enum CanvasAutoPlacement {
  fit,
  manual,
}

enum CanvasResizePosition {
  topLeft,
  top,
  topRight,
  left,
  center,
  right,
  bottomLeft,
  bottom,
  bottomRight,
}

/// Calculates the offset required to keep the anchor point in the same position after a resize.
///
/// The [anchor] parameter specifies the anchor point to use for the calculation.
Offset anchorFactors(final CanvasResizePosition anchor) {
  switch (anchor) {
    case CanvasResizePosition.topLeft:
      return const Offset(0, 0);
    case CanvasResizePosition.top:
      return const Offset(AppVisual.half, 0);
    case CanvasResizePosition.topRight:
      return const Offset(1, 0);
    case CanvasResizePosition.left:
      return const Offset(0, AppVisual.half);
    case CanvasResizePosition.center:
      return const Offset(AppVisual.half, AppVisual.half);
    case CanvasResizePosition.right:
      return const Offset(1, AppVisual.half);
    case CanvasResizePosition.bottomLeft:
      return const Offset(0, 1);
    case CanvasResizePosition.bottom:
      return const Offset(AppVisual.half, 1);
    case CanvasResizePosition.bottomRight:
      return const Offset(1, 1);
  }
}

/// Calculates the translation offset for the given anchor position.
Offset anchorTranslate(
  final CanvasResizePosition anchor,
  final Size fromSize,
  final Size toSize,
) {
  final Offset factors = anchorFactors(anchor);

  // Special handling for center anchor to maintain visual centering
  if (anchor == CanvasResizePosition.center) {
    final double dx = (toSize.width - fromSize.width) / AppMath.pair;
    final double dy = (toSize.height - fromSize.height) / AppMath.pair;
    return Offset(dx, dy);
  }

  // For other anchors, remove negative sign to fix inverse behavior
  final double dx = (toSize.width - fromSize.width) * factors.dx;
  final double dy = (toSize.height - fromSize.height) * factors.dy;
  return Offset(dx, dy);
}
