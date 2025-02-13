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

enum SelectorMode {
  rectangle,
  circle,
  wand,
}

class SelectorModel {
  bool isVisible = false;
  SelectorMode mode = SelectorMode.rectangle;
  Path path = Path();
  bool userIsCreatingTheSelector = false;

  Rect get boundingRect => path.getBounds();

  Offset? p1;

  void clear() {
    this.isVisible = false;
    this.path.reset();
    this.userIsCreatingTheSelector = false;
  }

  void translate(final Offset offset) {
    final Rect bounds = path.getBounds();

    if (bounds.width <= 0 || bounds.height <= 0) {
      return; // Prevent invalid transformations
    }

    final Matrix4 matrix = Matrix4.identity()..translate(offset.dx, offset.dy);
    path = path.transform(matrix.storage);
  }

  void resizeFromSides(
    final SelectorHandlePosition handle,
    final Offset offset,
  ) {
    final Rect bounds = path.getBounds();
    late Rect newBounds;

    switch (handle) {
      case SelectorHandlePosition.topLeft:
        newBounds = Rect.fromLTRB(
          (bounds.left + offset.dx)
              .clamp(double.negativeInfinity, bounds.right),
          (bounds.top + offset.dy)
              .clamp(double.negativeInfinity, bounds.bottom),
          bounds.right,
          bounds.bottom,
        );
        break;
      case SelectorHandlePosition.top:
        newBounds = Rect.fromLTRB(
          bounds.left,
          (bounds.top + offset.dy)
              .clamp(double.negativeInfinity, bounds.bottom),
          bounds.right,
          bounds.bottom,
        );
        break;
      case SelectorHandlePosition.topRight:
        newBounds = Rect.fromLTRB(
          bounds.left,
          (bounds.top + offset.dy)
              .clamp(double.negativeInfinity, bounds.bottom),
          (bounds.right + offset.dx).clamp(bounds.left, double.infinity),
          bounds.bottom,
        );
        break;
      case SelectorHandlePosition.right:
        newBounds = Rect.fromLTRB(
          bounds.left,
          bounds.top,
          (bounds.right + offset.dx).clamp(bounds.left, double.infinity),
          bounds.bottom,
        );
        break;
      case SelectorHandlePosition.bottomRight:
        newBounds = Rect.fromLTRB(
          bounds.left,
          bounds.top,
          (bounds.right + offset.dx).clamp(bounds.left, double.infinity),
          (bounds.bottom + offset.dy).clamp(bounds.top, double.infinity),
        );
        break;
      case SelectorHandlePosition.bottom:
        newBounds = Rect.fromLTRB(
          bounds.left,
          bounds.top,
          bounds.right,
          (bounds.bottom + offset.dy).clamp(bounds.top, double.infinity),
        );
        break;
      case SelectorHandlePosition.bottomLeft:
        newBounds = Rect.fromLTRB(
          (bounds.left + offset.dx)
              .clamp(double.negativeInfinity, bounds.right),
          bounds.top,
          bounds.right,
          (bounds.bottom + offset.dy).clamp(bounds.top, double.infinity),
        );
        break;
      case SelectorHandlePosition.left:
        newBounds = Rect.fromLTRB(
          (bounds.left + offset.dx)
              .clamp(double.negativeInfinity, bounds.right),
          bounds.top,
          bounds.right,
          bounds.bottom,
        );
        break;
    }

    // Ensure the width and height remain positive
    if (newBounds.width > 0 && newBounds.height > 0) {
      path = Path()..addRect(newBounds);
    } else {
      // Flip the rectangle if it goes beyond the bounds
      final double left =
          newBounds.left < newBounds.right ? newBounds.left : newBounds.right;
      final double right =
          newBounds.left > newBounds.right ? newBounds.left : newBounds.right;
      final double top =
          newBounds.top < newBounds.bottom ? newBounds.top : newBounds.bottom;
      final double bottom =
          newBounds.top > newBounds.bottom ? newBounds.top : newBounds.bottom;

      path = Path()..addRect(Rect.fromLTRB(left, top, right, bottom));
    }
  }

  void addP1(Offset p1) {
    isVisible = true;
    path = Path();
    this.p1 = p1;
    path.addRect(Rect.fromPoints(p1, p1));
  }

  void addP2(Offset p2) {
    if (p1 != null) {
      path = Path();
      path.addRect(Rect.fromPoints(p1!, p2));
    }
  }
}
