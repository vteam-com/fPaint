import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/visible_model.dart';

/// Holds the state for a perspective/skew transform operation on a selected region.
class TransformModel extends VisibleModel {
  /// Index constants for the corners list.
  static const int topLeftIndex = 0;
  static const int topRightIndex = 1;
  static const int bottomRightIndex = 2;
  static const int bottomLeftIndex = 3;
  static const int cornerCount = 4;

  /// The captured source image from the selection.
  ui.Image? sourceImage;

  /// The original bounds of the selection (source rectangle in canvas coordinates).
  Rect sourceBounds = Rect.zero;

  /// The 4 corner points defining the destination quadrilateral in canvas coordinates.
  /// Order: topLeft, topRight, bottomRight, bottomLeft.
  List<Offset> corners = <Offset>[];

  /// Begins a transform operation with the given [image] captured from the selection
  /// at the given [bounds].
  void start({
    required final ui.Image image,
    required final Rect bounds,
  }) {
    sourceImage = image;
    sourceBounds = bounds;
    corners = <Offset>[
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomRight,
      bounds.bottomLeft,
    ];
    isVisible = true;
  }

  /// Moves a single corner by [delta] in canvas coordinates.
  void moveCorner(final int index, final Offset delta) {
    corners[index] = corners[index] + delta;
  }

  /// Moves two corners on an edge by [delta] in canvas coordinates.
  void moveEdge(final int index1, final int index2, final Offset delta) {
    corners[index1] = corners[index1] + delta;
    corners[index2] = corners[index2] + delta;
  }

  /// Moves all corners by [delta] in canvas coordinates (translate).
  void moveAll(final Offset delta) {
    for (int i = 0; i < corners.length; i++) {
      corners[i] = corners[i] + delta;
    }
  }

  /// Returns the center of the quad.
  Offset get center {
    return Offset(
      (corners[topLeftIndex].dx +
              corners[topRightIndex].dx +
              corners[bottomRightIndex].dx +
              corners[bottomLeftIndex].dx) /
          cornerCount,
      (corners[topLeftIndex].dy +
              corners[topRightIndex].dy +
              corners[bottomRightIndex].dy +
              corners[bottomLeftIndex].dy) /
          cornerCount,
    );
  }

  /// Returns the midpoint of an edge between two corners.
  Offset edgeMidpoint(final int index1, final int index2) {
    return Offset(
      (corners[index1].dx + corners[index2].dx) / AppMath.pair,
      (corners[index1].dy + corners[index2].dy) / AppMath.pair,
    );
  }

  /// Returns the bounding rect of the quad in canvas coordinates.
  Rect get quadBounds {
    if (corners.isEmpty) {
      return Rect.zero;
    }
    double minX = corners[0].dx;
    double maxX = corners[0].dx;
    double minY = corners[0].dy;
    double maxY = corners[0].dy;
    for (final Offset corner in corners) {
      if (corner.dx < minX) {
        minX = corner.dx;
      }
      if (corner.dx > maxX) {
        maxX = corner.dx;
      }
      if (corner.dy < minY) {
        minY = corner.dy;
      }
      if (corner.dy > maxY) {
        maxY = corner.dy;
      }
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  @override
  void clear() {
    super.clear();
    sourceImage = null;
    sourceBounds = Rect.zero;
    corners.clear();
  }
}
