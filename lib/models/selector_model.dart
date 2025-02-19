import 'package:flutter/material.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';

// Exports
export 'package:fpaint/helpers/draw_path_helper.dart';

class SelectorModel {
  bool isVisible = false;
  SelectorMode mode = SelectorMode.rectangle;
  SelectorMath math = SelectorMath.replace;

  List<Offset> points = <Offset>[];
  Path path = Path();

  Rect get boundingRect => path.getBounds();

  void clear() {
    this.isVisible = false;
    this.path.reset();
    this.points.clear();
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

  void addP1(final Offset p1) {
    isVisible = true;

    switch (mode) {
      case SelectorMode.rectangle:
        this.points.clear();
        this.points.add(p1);
        path = Path();
        path.addRect(Rect.fromPoints(p1, p1));
        break;

      case SelectorMode.circle:
        this.points.clear();
        this.points.add(p1);
        path = Path();
        path.addOval(Rect.fromPoints(p1, p1));

        break;

      case SelectorMode.lasso:
        points.add(p1);
        break;

      case SelectorMode.wand:
        break;
    }
  }

  void addP2(final Offset p2) {
    if (this.points.isNotEmpty) {
      switch (mode) {
        case SelectorMode.rectangle:
          path = Path();
          path.addRect(Rect.fromPoints(this.points.first, p2));
          break;
        case SelectorMode.circle:
          path = Path();
          path.addOval(Rect.fromPoints(this.points.first, p2));
          break;
        case SelectorMode.lasso:
          points.add(p2);

          path = Path();
          path.moveTo(points.first.dx, points.first.dy);
          for (final Offset point in points.skip(1)) {
            path.lineTo(point.dx, point.dy);
          }
          path.close();
          break;
        case SelectorMode.wand:
          // all handled on the first Touch/Click P1 gesture
          break;
      }
    }
  }
}

enum SelectorMode {
  rectangle,
  circle,
  lasso,
  wand,
}

enum SelectorMath {
  replace,
  add,
  remove,
}
