import 'package:flutter/material.dart';

enum SelectorHandlePosition {
  topLeft,
  topRight,
  //
  bottomLeft,
  bottomRight,
  //
  left,
  right,
  //
  top,
  bottom,
}

class SelectorModel {
  bool isVisible = false;
  Path path = Path();
  bool isMoving = false;

  Rect get boundingRect => path.getBounds();

  void translate(final Offset offset) {
    final Rect bounds = path.getBounds();

    if (bounds.width <= 0 || bounds.height <= 0) {
      return; // Prevent invalid transformations
    }

    final Matrix4 matrix = Matrix4.identity()..translate(offset.dx, offset.dy);
    path = path.transform(matrix.storage);
  }

  void inflate(
    final SelectorHandlePosition handle,
    final Offset offset,
  ) {
    final Rect bounds = path.getBounds();
    late Rect newBounds;

    switch (handle) {
      case SelectorHandlePosition.topLeft:
        newBounds = Rect.fromLTRB(
          bounds.left + offset.dx,
          bounds.top + offset.dy,
          bounds.right,
          bounds.bottom,
        );
        break;
      case SelectorHandlePosition.top:
        newBounds = Rect.fromLTRB(
          bounds.left,
          bounds.top + offset.dy,
          bounds.right,
          bounds.bottom,
        );
        break;
      case SelectorHandlePosition.topRight:
        newBounds = Rect.fromLTRB(
          bounds.left,
          bounds.top + offset.dy,
          bounds.right + offset.dx,
          bounds.bottom,
        );
        break;
      case SelectorHandlePosition.right:
        newBounds = Rect.fromLTRB(
          bounds.left,
          bounds.top,
          bounds.right + offset.dx,
          bounds.bottom,
        );
        break;
      case SelectorHandlePosition.bottomRight:
        newBounds = Rect.fromLTRB(
          bounds.left,
          bounds.top,
          bounds.right + offset.dx,
          bounds.bottom + offset.dy,
        );
        break;
      case SelectorHandlePosition.bottom:
        newBounds = Rect.fromLTRB(
          bounds.left,
          bounds.top,
          bounds.right,
          bounds.bottom + offset.dy,
        );
        break;
      case SelectorHandlePosition.bottomLeft:
        newBounds = Rect.fromLTRB(
          bounds.left + offset.dx,
          bounds.top,
          bounds.right,
          bounds.bottom + offset.dy,
        );
        break;
      case SelectorHandlePosition.left:
        newBounds = Rect.fromLTRB(
          bounds.left + offset.dx,
          bounds.top,
          bounds.right,
          bounds.bottom,
        );
        break;
    }

    // Ensure the width and height remain positive
    if (newBounds.width > 0 && newBounds.height > 0) {
      path = Path()..addRect(newBounds);
    }
  }

  void addPosition(final Offset position) {
    isVisible = true;
    if (isMoving) {
      // debugPrint('Selector isMoving - addPosition ${path.getBounds().topLeft}');
      final r = Rect.fromPoints(path.getBounds().topLeft, position);
      path = Path();
      path.addRect(r);
    } else {
      // debugPrint('Selector start from $position');
      path = Path();
      path.addRect(Rect.fromPoints(position, position));
      isMoving = true;
    }
  }

  Rect getAdjustedRect(
    double topLeftTranslated,
    double topTopTranslated,
    double scale,
  ) {
    final Rect bounds = this.boundingRect;
    final double scaledFactor = scale * scale;

    final double left = topLeftTranslated + bounds.left * scaledFactor;
    final double top = topTopTranslated + bounds.top * scaledFactor;
    final double right = topLeftTranslated + bounds.right * scaledFactor;
    final double bottom = topTopTranslated + bounds.bottom * scaledFactor;

    // Normalize the rectangle
    final double normalizedLeft = left < right ? left : right;
    final double normalizedRight = left > right ? left : right;
    final double normalizedTop = top < bottom ? top : bottom;
    final double normalizedBottom = top > bottom ? top : bottom;

    return Rect.fromLTRB(
      normalizedLeft,
      normalizedTop,
      normalizedRight,
      normalizedBottom,
    );
  }
}
