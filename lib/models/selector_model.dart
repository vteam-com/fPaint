import 'package:flutter/material.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';

// Exports
export 'package:fpaint/helpers/draw_path_helper.dart';

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

  void nindeGridResize(
    final NineGridHandle handle,
    final Offset offset,
  ) {
    this.path = expandPathInDirectionWithOffset(this.path, offset, handle);
  }

  void addP1(Offset p1) {
    isVisible = true;
    path = Path();
    this.p1 = p1;

    if (mode == SelectorMode.rectangle) {
      path.addRect(Rect.fromPoints(p1, p1));
    }
    if (mode == SelectorMode.circle) {
      path.addOval(Rect.fromPoints(p1, p1));
    }
  }

  void addP2(Offset p2) {
    if (p1 != null) {
      path = Path();
      if (mode == SelectorMode.rectangle) {
        path.addRect(Rect.fromPoints(p1!, p2));
      }
      if (mode == SelectorMode.circle) {
        path.addOval(Rect.fromPoints(p1!, p2));
      }
    }
  }
}

enum SelectorMode {
  rectangle,
  circle,
  wand,
}
