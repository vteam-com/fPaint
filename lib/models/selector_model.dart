import 'package:flutter/material.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';

// Exports
export 'package:fpaint/helpers/draw_path_helper.dart';

class SelectorModel {
  bool isVisible = false;
  SelectorMode mode = SelectorMode.rectangle;
  SelectorMath math = SelectorMath.replace;

  List<Offset> points = <Offset>[];
  Path? path1;
  Path? path2; // use when Selector.math is not Selector.replace

  Rect get boundingRect => path1?.getBounds() ?? Rect.zero;

  void clear() {
    this.isVisible = false;
    this.path1 = null;
    this.points.clear();
  }

  void invert(final Rect containerRect) {
    if (path1 != null) {
      final Path outerPath = Path()..addRect(containerRect);
      path1 = Path.combine(PathOperation.difference, outerPath, path1!);
    }
  }

  void translate(final Offset offset) {
    final Rect bounds = boundingRect;

    if (bounds.width <= 0 || bounds.height <= 0) {
      return; // Prevent invalid transformations
    }

    final Matrix4 matrix = Matrix4.identity()..translate(offset.dx, offset.dy);
    path1 = path1!.transform(matrix.storage);
  }

  void nindeGridResize(
    final NineGridHandle handle,
    final Offset offset,
  ) {
    if (this.path1 != null) {
      this.path1 = expandPathInDirectionWithOffset(this.path1!, offset, handle);
    }
  }

  void addP1(final Offset p1) {
    isVisible = true;

    switch (mode) {
      case SelectorMode.rectangle:
        points.clear();
        if (math == SelectorMath.replace) {
          path1 = Path()..addRect(Rect.fromPoints(p1, p1));
        }
        points.add(p1);
        break;

      case SelectorMode.circle:
        points.clear();
        if (math == SelectorMath.replace) {
          path1 = Path()..addOval(Rect.fromPoints(p1, p1));
        }
        points.add(p1);
        break;

      case SelectorMode.lasso:
        points.add(p1);

        break;

      case SelectorMode.wand:
        break;
    }
  }

  void addP2(final Offset p2) {
    if (points.isNotEmpty) {
      switch (mode) {
        case SelectorMode.rectangle:
          // We only need 2 points for the rectangle
          if (math == SelectorMath.replace) {
            this.path1 = Path()..addRect(Rect.fromPoints(points.first, p2));
          } else {
            this.path2 = Path()..addRect(Rect.fromPoints(points.first, p2));
          }
          break;

        case SelectorMode.circle:
          // We only need 2 points for the rectangle
          if (math == SelectorMath.replace) {
            this.path1 = Path()..addOval(Rect.fromPoints(points.first, p2));
          } else {
            this.path2 = Path()..addOval(Rect.fromPoints(points.first, p2));
          }
          break;

        case SelectorMode.lasso:
          points.add(p2);
          if (math == SelectorMath.replace) {
            this.path1 = Path();
            path1!.moveTo(points.first.dx, points.first.dy);
            for (final Offset point in points.skip(1)) {
              path1!.lineTo(point.dx, point.dy);
            }
            path1!.close();
          } else {
            this.path2 = Path();
            path2!.moveTo(points.first.dx, points.first.dy);
            for (final Offset point in points.skip(1)) {
              path2!.lineTo(point.dx, point.dy);
            }
            path2!.close();
          }
          break;

        case SelectorMode.wand:
          break;
      }
    }
  }

  void applyMath() {
    if (path1 == null) {
      return;
    }

    switch (math) {
      case SelectorMath.replace:
        // this should already have been take care by addP2() function
        break;
      case SelectorMath.add:
        if (path2 != null) {
          path1 = Path.combine(PathOperation.union, this.path1!, this.path2!);
          path2 = null;
        }
        break;
      case SelectorMath.remove:
        if (path2 != null) {
          path1 = Path.combine(PathOperation.difference, this.path1!, path2!);
          path2 = null;
        }
        break;
    }
    this.points.clear();
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
