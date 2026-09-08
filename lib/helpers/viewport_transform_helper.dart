import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';

/// The canvas-to-screen viewport transform: pan, zoom and rotation.
///
/// Every mapping between canvas pixels and screen pixels in the app resolves to
/// this one transform, composed as `translate(offset) · rotate(rotation) ·
/// scale(scale)`. That order matters: the offset is a screen-space translation
/// (so panning stays 1:1 with the pointer at any zoom or angle), while rotation
/// and scale act about the canvas origin.
///
/// The inverse is computed once at construction. Screen-to-canvas conversion
/// runs on every pointer event of every stroke, so inverting a [Matrix4] per
/// call would put matrix math on the drawing hot path.
@immutable
class ViewportTransform {
  /// Creates a viewport transform and precomputes its inverse.
  ViewportTransform({
    required this.offset,
    required this.scale,
    required this.rotation,
  }) : _matrix = _compose(offset, scale, rotation) {
    _inverse = Matrix4.inverted(_matrix);
  }

  /// The upright, unit-scale, unrotated transform.
  ViewportTransform.identity() : this(offset: Offset.zero, scale: 1, rotation: 0);

  /// Screen-space translation of the canvas origin.
  final Offset offset;

  /// Canvas zoom factor.
  final double scale;

  /// Viewport rotation in radians, clockwise-positive.
  final double rotation;

  final Matrix4 _matrix;

  late final Matrix4 _inverse;

  static Matrix4 _compose(Offset offset, double scale, double rotation) {
    return Matrix4.identity()
      ..translateByDouble(offset.dx, offset.dy, 0, 1)
      ..rotateZ(rotation)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  /// Whether the viewport is rotated away from its upright orientation.
  bool get isRotated => rotation != 0;

  /// The canvas-to-screen matrix, for applying to a [Canvas].
  Matrix4 get matrix => _matrix;

  /// Maps a canvas point to screen space.
  Offset toScreen(Offset canvasPoint) => MatrixUtils.transformPoint(_matrix, canvasPoint);

  /// Maps a screen point to canvas space.
  Offset toCanvas(Offset screenPoint) => MatrixUtils.transformPoint(_inverse, screenPoint);

  /// Maps a screen-space *delta* (a drag vector) into canvas space.
  ///
  /// A delta carries no position, so it must be rotated and scaled but never
  /// translated — dividing by [scale] alone drifts diagonally once the viewport
  /// is rotated.
  Offset deltaToCanvas(Offset screenDelta) {
    if (rotation == 0) {
      return screenDelta / scale;
    }
    final Offset rotated = rotateOffset(screenDelta, -rotation);
    return rotated / scale;
  }

  /// The axis-aligned canvas-space bounds covering the screen rect [viewport].
  ///
  /// Under rotation the visible canvas region is a rotated quad, so culling must
  /// use the bounding box of its four inverse-mapped corners; scaling the
  /// viewport rect alone would clip visible content away mid-rotation.
  Rect visibleCanvasBounds(Rect viewport) {
    return MatrixUtils.inverseTransformRect(_matrix, viewport);
  }

  /// Returns a copy with the given fields replaced.
  ViewportTransform copyWith({
    Offset? offset,
    double? scale,
    double? rotation,
  }) {
    return ViewportTransform(
      offset: offset ?? this.offset,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ViewportTransform && other.offset == offset && other.scale == scale && other.rotation == rotation;
  }

  @override
  int get hashCode => Object.hash(offset, scale, rotation);
}

/// Rotates [point] about the origin by [radians], clockwise-positive.
Offset rotateOffset(Offset point, double radians) {
  final double cosine = math.cos(radians);
  final double sine = math.sin(radians);
  return Offset(
    point.dx * cosine - point.dy * sine,
    point.dx * sine + point.dy * cosine,
  );
}

/// Normalizes [radians] to the half-open range (-pi, pi].
double normalizeRadians(double radians) {
  const double fullTurn = 2 * math.pi;
  double normalized = radians % fullTurn;
  if (normalized > math.pi) {
    normalized -= fullTurn;
  } else if (normalized <= -math.pi) {
    normalized += fullTurn;
  }
  return normalized;
}

/// Snaps [radians] to the nearest multiple of [snapIntervalDegrees] when it is
/// within [snapToleranceDegrees] of it, otherwise returns it normalized.
///
/// Holding exact cardinal angles is what lets a free-rotation gesture get back
/// to upright (or a clean 90°) by hand.
double snapAngleToInterval(
  double radians, {
  required double snapIntervalDegrees,
  required double snapToleranceDegrees,
}) {
  final double degrees = radiansToDegrees(normalizeRadians(radians));
  final double nearestSnap = (degrees / snapIntervalDegrees).roundToDouble() * snapIntervalDegrees;
  // The epsilon keeps an angle sitting exactly on the tolerance boundary from
  // falling outside it through degree/radian round-trip error.
  if ((degrees - nearestSnap).abs() <= snapToleranceDegrees + _snapBoundaryEpsilonDegrees) {
    return degreesToRadians(nearestSnap);
  }
  return normalizeRadians(radians);
}

/// Absorbs float round-trip error at the snap-tolerance boundary.
const double _snapBoundaryEpsilonDegrees = 1e-9;

/// Converts [radians] to degrees.
double radiansToDegrees(double radians) => radians * AppMath.degreesPerHalfTurn / math.pi;

/// Converts [degrees] to radians.
double degreesToRadians(double degrees) => degrees * math.pi / AppMath.degreesPerHalfTurn;
