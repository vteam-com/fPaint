import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';
import 'package:fpaint/helpers/transform_helper.dart';
import 'package:fpaint/models/visible_model.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

// Exports
export 'package:fpaint/helpers/draw_path_helper.dart';

bool _isFiniteOffset(Offset offset) {
  return offset.isFinite;
}

bool _hasFinitePathBounds(Path path) {
  final Rect bounds = path.getBounds();
  return bounds.left.isFinite && bounds.top.isFinite && bounds.right.isFinite && bounds.bottom.isFinite;
}

/// A restorable copy of a [SelectorModel]'s selection state; see
/// [SelectorModel.snapshot] and [SelectorModel.restore].
typedef SelectionStateSnapshot = ({
  bool isVisible,
  bool isDrawing,
  Path? path1,
  Path? path2,
  List<Offset> points,
  SelectorMath math,
});

/// A class that represents the selector model.
class SelectorModel extends VisibleModel {
  SelectorMode mode = SelectorMode.rectangle;
  SelectorMath math = SelectorMath.replace;
  bool isDrawing = false;

  /// Sticky "All layers" scope: the wand samples the merged visible composite
  /// and transform/cut/copy act on every visible, unlocked layer instead of
  /// only the selected one. Like [mode], it survives [clear].
  bool allLayers = false;

  List<Offset> points = <Offset>[];

  /// Width, in canvas pixels, of the band a [SelectorMode.brush] stroke paints.
  double brushWidth = AppDefaults.brushSize;

  Path? path1;
  Path? path2; // use when Selector.math is not Selector.replace

  /// The selection path that clips edits, or null when no selection is shown.
  ///
  /// Shared by reference; use [copyActiveClipPath] when the caller keeps it
  /// beyond later selection edits.
  Path? get activeClipPath => isVisible ? path1 : null;

  /// An independent copy of [activeClipPath], or null when no selection clips.
  Path? copyActiveClipPath() {
    final Path? clip = activeClipPath;
    return clip == null ? null : Path.from(clip);
  }

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

  /// Replaces the selection with the single committed [path]: visible, not
  /// drawing, no pending math operand or points, and math reset to replace.
  void replacePath(Path path) {
    this.isVisible = true;
    this.isDrawing = false;
    this.path1 = path;
    this.path2 = null;
    this.points.clear();
    this.math = SelectorMath.replace;
  }

  /// Captures the current selection state, copying paths and points so later
  /// edits cannot alter the snapshot.
  SelectionStateSnapshot snapshot() {
    return (
      isVisible: isVisible,
      isDrawing: isDrawing,
      path1: path1 == null ? null : Path.from(path1!),
      path2: path2 == null ? null : Path.from(path2!),
      points: List<Offset>.from(points),
      math: math,
    );
  }

  /// Restores a state captured by [snapshot], copying its paths so the
  /// snapshot stays reusable.
  void restore(SelectionStateSnapshot state) {
    this.isVisible = state.isVisible;
    this.isDrawing = state.isDrawing;
    this.path1 = state.path1 == null ? null : Path.from(state.path1!);
    this.path2 = state.path2 == null ? null : Path.from(state.path2!);
    this.points
      ..clear()
      ..addAll(state.points);
    this.math = state.math;
  }

  /// Inverts the selection.
  void invert(Rect containerRect) {
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
  void translate(Offset offset) {
    final Rect bounds = boundingRect;

    if (bounds.width <= 0 || bounds.height <= 0) {
      return; // Prevent invalid transformations
    }

    final Matrix4 matrix = Matrix4.identity()..translateByVector3(Vector3(offset.dx, offset.dy, 0.0));
    path1 = path1!.transform(matrix.storage);
  }

  /// Resizes the selection using a nine grid handle.
  void nindeGridResize(
    NineGridHandle handle,
    Offset offset,
  ) {
    if (this.path1 != null) {
      final Rect previousBounds = this.path1!.getBounds();
      this.path1 = expandPathInDirectionWithOffset(this.path1!, offset, handle);
      triggerSquareSnapHaptic(previousBounds, this.path1!.getBounds());
    }
  }

  /// Rotates the selection around its center by [angleRadians].
  void rotate(double angleRadians) {
    _transformPaths((Path path) => rotatePathAroundCenter(path, angleRadians));
  }

  /// Scales the selection uniformly around its center by [factor].
  void scaleUniform(double factor) {
    final double clampedFactor = factor.clamp(
      AppInteraction.transformScaleFactorMin,
      AppInteraction.transformScaleFactorMax,
    );
    _transformPaths((Path path) => scalePathAroundCenter(path, clampedFactor, null));
  }

  /// Replaces the selection path (and any pending math operand) with its
  /// [transform]ed copy; a no-op without a selection.
  void _transformPaths(Path Function(Path) transform) {
    final Path? selection = path1;
    if (selection == null) {
      return;
    }
    path1 = transform(selection);
    final Path? operand = path2;
    if (operand != null) {
      path2 = transform(operand);
    }
  }

  /// Adds the first point to the selection.
  void addP1(Offset p1) {
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

      case SelectorMode.brush:
        points
          ..clear()
          ..add(p1);
        _setWorkingPath(Path()..addOval(Rect.fromCircle(center: p1, radius: _brushRadius)));
        break;

      case SelectorMode.wand:
        break;
    }
  }

  /// Adds the second point to the selection.
  void addP2(Offset p2) {
    if (!_isFiniteOffset(p2) || points.any((Offset point) => !_isFiniteOffset(point))) {
      return;
    }

    if (points.isNotEmpty) {
      switch (mode) {
        case SelectorMode.rectangle:
          // We only need 2 points for the rectangle
          _setWorkingPath(Path()..addRect(Rect.fromPoints(points.first, p2)));
          break;

        case SelectorMode.circle:
          // We only need 2 points for the ellipse's bounding box
          _setWorkingPath(Path()..addOval(Rect.fromPoints(points.first, p2)));
          break;

        case SelectorMode.line:
          break;

        case SelectorMode.lasso:
          points.add(p2);
          _setWorkingPath(_buildStraightLineRegionPath(closePath: true));
          break;

        case SelectorMode.brush:
          _extendBrushStroke(p2);
          break;

        case SelectorMode.wand:
          break;
      }
    }
  }

  double get _brushRadius => brushWidth / AppMath.pair;

  /// Paints the brush band on to [point]: unions one round-ended segment from
  /// the last sample into the working path. Samples closer than a fraction of
  /// the radius are skipped, bounding the path-boolean work per stroke.
  void _extendBrushStroke(Offset point) {
    final Offset last = points.last;
    if ((point - last).distance < _brushRadius * AppInteraction.selectionBrushSampleSpacing) {
      return;
    }
    points.add(point);

    final Path segment = _roundedSegmentPath(last, point, _brushRadius);
    final Path? working = math == SelectorMath.replace ? path1 : path2;
    final Path? merged = working == null ? segment : _combinePathsSafely(PathOperation.union, working, segment);
    if (merged != null) {
      _setWorkingPath(merged);
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

    // Replace needs no combine: addP2() already wrote the working path.
    final PathOperation? operation = switch (math) {
      SelectorMath.replace => null,
      SelectorMath.add => PathOperation.union,
      SelectorMath.remove => PathOperation.difference,
      SelectorMath.intersect => PathOperation.intersect,
    };
    final Path? operand = path2;
    if (operation != null && operand != null) {
      final Path? combinedPath = _combinePathsSafely(operation, path1!, operand);
      if (combinedPath != null) {
        path1 = combinedPath;
      }
      path2 = null;
    }
    this.points.clear();
  }

  /// Attempts to combine two paths and ignores invalid geometry results.
  Path? _combinePathsSafely(
    PathOperation operation,
    Path firstPath,
    Path secondPath,
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
    PathOperation operation,
    Path firstPath,
    Path secondPath,
  ) {
    return Path.combine(operation, firstPath, secondPath);
  }

  /// Adds a vertex to the straight-line region selection.
  ///
  /// Returns `true` when the new point closes the polygon back to the first
  /// vertex and the selection can be committed.
  bool addStraightLineRegionPoint(
    Offset position, {
    required double closeDistance,
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
    Offset position, {
    required double closeDistance,
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

  void _setWorkingPath(Path path) {
    if (math == SelectorMath.replace) {
      path1 = path;
      path2 = null;
      return;
    }

    path2 = path;
  }

  bool _isClosingStraightLineRegion(
    Offset position, {
    required double closeDistance,
  }) {
    return points.length >= AppMath.triple && (position - points.first).distance <= closeDistance;
  }

  /// Closes the in-progress straight-line region without requiring a tap near
  /// the first vertex.
  bool closeStraightLineRegion() {
    if (points.length < AppMath.triple) {
      return false;
    }

    _setWorkingPath(_buildStraightLineRegionPath(closePath: true));
    return true;
  }

  /// Builds the current straight-line region path from committed vertices plus
  /// an optional preview edge, closing the polygon only when requested.
  Path _buildStraightLineRegionPath({
    Offset? previewPoint,
    bool closePath = false,
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

/// One closed outline of a [radius]-wide band from [start] to [end] with round
/// ends (a stadium). A single contour, so it never self-overlaps the way a
/// rectangle plus end circles would, and unions cleanly into a selection.
Path _roundedSegmentPath(Offset start, Offset end, double radius) {
  final Offset delta = end - start;
  final Offset direction = delta / delta.distance;
  // Left-hand normal: the direction rotated a quarter turn.
  final Offset normal = Offset(-direction.dy, direction.dx) * radius;
  final double normalAngle = math.atan2(normal.dy, normal.dx);

  return Path()
    ..moveTo(start.dx + normal.dx, start.dy + normal.dy)
    ..lineTo(end.dx + normal.dx, end.dy + normal.dy)
    // Half turns sweeping back through the travel direction (then its reverse)
    // bulge each cap outward, away from the band.
    ..arcTo(Rect.fromCircle(center: end, radius: radius), normalAngle, -math.pi, false)
    ..lineTo(start.dx - normal.dx, start.dy - normal.dy)
    ..arcTo(Rect.fromCircle(center: start, radius: radius), normalAngle + math.pi, -math.pi, false)
    ..close();
}

/// Enum that represents the selector mode.
enum SelectorMode {
  rectangle,
  circle,
  line,
  lasso,

  /// Paint the selection: the swept band of a brush-sized stroke is selected.
  brush,
  wand,
}

/// Enum that represents the selector math.
enum SelectorMath {
  replace,
  add,
  remove,
  intersect,
}
