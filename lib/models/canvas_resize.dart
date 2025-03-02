import 'package:flutter/material.dart';

enum CanvasAutoPlacement {
  center,
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

Offset anchorTranslate(
  final CanvasResizePosition anchor,
  final Size source,
  final Size destination,
) {
  // Calculate the offset adjustment based on resize position
  Offset offset = Offset.zero;

  final double dx = (destination.width - source.width).toDouble();
  final double dy = (destination.height - source.height).toDouble();

  switch (anchor) {
    case CanvasResizePosition.topLeft:
      offset = Offset.zero;
      break;
    case CanvasResizePosition.top:
      offset = Offset(dx / 2, 0);
      break;
    case CanvasResizePosition.topRight:
      offset = Offset(dx, 0);
      break;
    case CanvasResizePosition.left:
      offset = Offset(0, dy / 2);
      break;
    case CanvasResizePosition.center:
      offset = Offset(dx / 2, dy / 2);
      break;
    case CanvasResizePosition.right:
      offset = Offset(dx, dy / 2);
      break;
    case CanvasResizePosition.bottomLeft:
      offset = Offset(0, dy);
      break;
    case CanvasResizePosition.bottom:
      offset = Offset(dx / 2, dy);
      break;
    case CanvasResizePosition.bottomRight:
      offset = Offset(dx, dy);
      break;
  }

  return offset;
}
