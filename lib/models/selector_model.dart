import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';
import 'package:fpaint/helpers/transform_helper.dart';
import 'package:fpaint/models/visible_model.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

// Exports
export 'package:fpaint/helpers/draw_path_helper.dart';

bool _isFiniteOffset(final Offset offset) {
  return offset.isFinite;
}

bool _hasFinitePathBounds(final Path path) {
  final Rect bounds = path.getBounds();
  return bounds.left.isFinite && bounds.top.isFinite && bounds.right.isFinite && bounds.bottom.isFinite;
}

/// A class that represents the selector model.
class SelectorModel extends VisibleModel {
  SelectorMode mode = SelectorMode.rectangle;
  SelectorMath math = SelectorMath.replace;
  bool isDrawing = false;

  List<Offset> points = <Offset>[];
  Path? path1;
  Path? path2; // use when Selector.math is not Selector.replace

  /// Returns the bounding rectangle of the path.
  Rect get boundingRect => path1?.getBounds() ?? Rect.zero;

  /// Clears the selector.
  @override
  void clear() {
    this.isVisible = false;
    this.isDrawing = false;
    this.path1 = null;
    this.path2 = null;
    this.points.clear();
    this.math = SelectorMath.replace;
  }

  /// Inverts the selection.
  void invert(final Rect containerRect) {
    if (path1 != null) {
      final Path outerPath = Path()..addRect(containerRect);
      final Path? invertedPath = _combinePathsSafely(
        PathOperation.difference,
        outerPath,
        path1!,
      );
      if (invertedPath != null) {
        path1 = invertedPath;
      }
    }
  }

  /// Translates the selection.
  void translate(final Offset offset) {
    final Rect bounds = boundingRect;

    if (bounds.width <= 0 || bounds.height <= 0) {
      return; // Prevent invalid transformations
    }

    final Matrix4 matrix = Matrix4.identity()..translateByVector3(Vector3(offset.dx, offset.dy, 0.0));
    path1 = path1!.transform(matrix.storage);
  }

  /// Resizes the selection using a nine grid handle.
  void nindeGridResize(
    final NineGridHandle handle,
    final Offset offset,
  ) {
    if (this.path1 != null) {
      final Rect previousBounds = this.path1!.getBounds();
      this.path1 = expandPathInDirectionWithOffset(this.path1!, offset, handle);
      triggerSquareSnapHaptic(previousBounds, this.path1!.getBounds());
    }
  }

  /// Rotates the selection around its center by [angleRadians].
  void rotate(final double angleRadians) {
    if (this.path1 != null) {
      this.path1 = rotatePathAroundCenter(this.path1!, angleRadians);
      if (this.path2 != null) {
        this.path2 = rotatePathAroundCenter(this.path2!, angleRadians);
      }
    }
  }

  /// Scales the selection uniformly around its center by [factor].
  void scaleUniform(final double factor) {
    if (this.path1 != null) {
      final double clampedFactor = factor.clamp(
        AppInteraction.transformScaleFactorMin,
        AppInteraction.transformScaleFactorMax,
      );
      this.path1 = scalePathAroundCenter(this.path1!, clampedFactor, null);
      if (this.path2 != null) {
        this.path2 = scalePathAroundCenter(this.path2!, clampedFactor, null);
      }
    }
  }

  /// Adds the first point to the selection.
  void addP1(final Offset p1) {
    if (!_isFiniteOffset(p1)) {
      return;
    }

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

      case SelectorMode.line:
        break;

      case SelectorMode.lasso:
        points.add(p1);

        break;

      case SelectorMode.wand:
        break;
    }
  }

  /// Adds the second point to the selection.
  void addP2(final Offset p2) {
    if (!_isFiniteOffset(p2) || points.any((final Offset point) => !_isFiniteOffset(point))) {
      return;
    }

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

        case SelectorMode.line:
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

  /// Applies the math operation to the selection.
  void applyMath() {
    if (path1 == null) {
      return;
    }

    if (!_hasFinitePathBounds(path1!)) {
      clear();
      return;
    }

    switch (math) {
      case SelectorMath.replace:
        // this should already have been take care by addP2() function
        break;
      case SelectorMath.add:
        if (path2 != null) {
          final Path? combinedPath = _combinePathsSafely(
            PathOperation.union,
            path1!,
            path2!,
          );
          if (combinedPath != null) {
            path1 = combinedPath;
          }
          path2 = null;
        }
        break;
      case SelectorMath.remove:
        if (path2 != null) {
          final Path? combinedPath = _combinePathsSafely(
            PathOperation.difference,
            path1!,
            path2!,
          );
          if (combinedPath != null) {
            path1 = combinedPath;
          }
          path2 = null;
        }
        break;
    }
    this.points.clear();
  }

  /// Attempts to combine two paths and ignores invalid geometry results.
  Path? _combinePathsSafely(
    final PathOperation operation,
    final Path firstPath,
    final Path secondPath,
  ) {
    if (!_hasFinitePathBounds(firstPath) || !_hasFinitePathBounds(secondPath)) {
      return null;
    }

    try {
      final Path combinedPath = combinePaths(operation, firstPath, secondPath);
      if (!_hasFinitePathBounds(combinedPath)) {
        return null;
      }
      return combinedPath;
    } on StateError {
      return null;
    }
  }

  @visibleForTesting
  /// Combines two paths using the provided [operation].
  Path combinePaths(
    final PathOperation operation,
    final Path firstPath,
    final Path secondPath,
  ) {
    return Path.combine(operation, firstPath, secondPath);
  }

  /// Adds a vertex to the straight-line region selection.
  ///
  /// Returns `true` when the new point closes the polygon back to the first
  /// vertex and the selection can be committed.
  bool addStraightLineRegionPoint(
    final Offset position, {
    required final double closeDistance,
  }) {
    if (!_isFiniteOffset(position)) {
      return false;
    }

    isVisible = true;

    if (points.isEmpty) {
      points.add(position);
      _setWorkingPath(_buildStraightLineRegionPath());
      return false;
    }

    if (_isClosingStraightLineRegion(position, closeDistance: closeDistance)) {
      _setWorkingPath(_buildStraightLineRegionPath(closePath: true));
      return true;
    }

    points.add(position);
    _setWorkingPath(_buildStraightLineRegionPath());
    return false;
  }

  /// Updates the preview edge for the straight-line region selection.
  void updateStraightLineRegionPreview(
    final Offset position, {
    required final double closeDistance,
  }) {
    if (points.isEmpty || !_isFiniteOffset(position)) {
      return;
    }

    final bool closePath = _isClosingStraightLineRegion(position, closeDistance: closeDistance);
    _setWorkingPath(
      _buildStraightLineRegionPath(
        previewPoint: closePath ? null : position,
        closePath: closePath,
      ),
    );
  }

  void _setWorkingPath(final Path path) {
    if (math == SelectorMath.replace) {
      path1 = path;
      path2 = null;
      return;
    }

    path2 = path;
  }

  bool _isClosingStraightLineRegion(
    final Offset position, {
    required final double closeDistance,
  }) {
    return points.length >= AppMath.triple && (position - points.first).distance <= closeDistance;
  }

  /// Builds the current straight-line region path from committed vertices plus
  /// an optional preview edge, closing the polygon only when requested.
  Path _buildStraightLineRegionPath({
    final Offset? previewPoint,
    final bool closePath = false,
  }) {
    if (points.isEmpty) {
      return Path();
    }

    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final Offset point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    if (previewPoint != null) {
      path.lineTo(previewPoint.dx, previewPoint.dy);
    }
    if (closePath) {
      path.close();
    }
    return path;
  }
}

/// Enum that represents the selector mode.
enum SelectorMode {
  rectangle,
  circle,
  line,
  lasso,
  wand,
}

/// Enum that represents the selector math.
enum SelectorMath {
  replace,
  add,
  remove,
}
