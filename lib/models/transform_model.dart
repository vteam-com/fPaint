import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/transform_helper.dart';
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

  /// The active interaction mode for the transform overlay.
  TransformInteractionMode interactionMode = TransformInteractionMode.deform;

  /// The cumulative scale percentage for the active scale drag gesture.
  double activeScalePercent = AppMath.percentScale;

  /// Whether the scale percentage feedback should be shown.
  bool isScaleFeedbackVisible = false;

  /// The cumulative rotation delta in degrees for the active rotate drag gesture.
  double activeRotationDegrees = 0;

  /// Whether the rotation feedback should be shown.
  bool isRotationFeedbackVisible = false;

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
    setDeformMode();
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

  /// Whether the overlay is currently in deform mode.
  bool get isDeformMode => interactionMode == TransformInteractionMode.deform;

  /// Whether the overlay is currently in rotate mode.
  bool get isRotateMode => interactionMode == TransformInteractionMode.rotate;

  /// Whether the overlay is currently in uniform scale mode.
  bool get isScaleMode => interactionMode == TransformInteractionMode.scale;

  /// Whether a live feedback bubble should be shown.
  bool get isFeedbackVisible => isScaleFeedbackVisible || isRotationFeedbackVisible;

  /// Sets deform mode and clears any transient scale feedback.
  void setDeformMode() {
    interactionMode = TransformInteractionMode.deform;
    endScaleGesture();
    endRotateGesture();
  }

  /// Sets rotate mode and clears any transient scale feedback.
  void setRotateMode() {
    interactionMode = TransformInteractionMode.rotate;
    endScaleGesture();
    endRotateGesture();
  }

  /// Sets uniform scale mode without starting a drag gesture.
  void setScaleMode() {
    interactionMode = TransformInteractionMode.scale;
    endScaleGesture();
    endRotateGesture();
  }

  /// Starts a scale drag gesture and resets the live scale feedback.
  void beginScaleGesture() {
    interactionMode = TransformInteractionMode.scale;
    activeScalePercent = AppMath.percentScale;
    isScaleFeedbackVisible = true;
    endRotateGesture();
  }

  /// Ends the active scale gesture and hides the live scale feedback.
  void endScaleGesture() {
    activeScalePercent = AppMath.percentScale;
    isScaleFeedbackVisible = false;
  }

  /// Starts a rotate drag gesture and resets the live rotation feedback.
  void beginRotateGesture() {
    interactionMode = TransformInteractionMode.rotate;
    activeRotationDegrees = 0;
    isRotationFeedbackVisible = true;
    endScaleGesture();
  }

  /// Updates the live rotation feedback by [angleRadians].
  void updateRotationFeedback(final double angleRadians) {
    final double previousDegrees = activeRotationDegrees;
    activeRotationDegrees += angleRadians * AppMath.degreesPerHalfTurn / math.pi;
    triggerRotationSnapHaptic(previousDegrees, activeRotationDegrees);
  }

  /// Ends the active rotate gesture and hides the live rotation feedback.
  void endRotateGesture() {
    activeRotationDegrees = 0;
    isRotationFeedbackVisible = false;
  }

  /// Uniformly scales the full quad around its center by [factor].
  void scaleUniform(final double factor) {
    final double clampedFactor = factor.clamp(
      AppInteraction.transformScaleFactorMin,
      AppInteraction.transformScaleFactorMax,
    );
    final Offset scaleCenter = center;

    corners = corners.map((final Offset corner) {
      final Offset vector = corner - scaleCenter;
      return scaleCenter + (vector * clampedFactor);
    }).toList();

    final double previousPercent = activeScalePercent;
    activeScalePercent *= clampedFactor;
    triggerScaleSnapHaptic(previousPercent, activeScalePercent);
  }

  /// Rotates the full quad around its center by [angleRadians].
  void rotate(final double angleRadians) {
    final Offset rotationCenter = center;
    final double cosine = math.cos(angleRadians);
    final double sine = math.sin(angleRadians);

    corners = corners.map((final Offset corner) {
      final Offset vector = corner - rotationCenter;
      return Offset(
        rotationCenter.dx + (vector.dx * cosine) - (vector.dy * sine),
        rotationCenter.dy + (vector.dx * sine) + (vector.dy * cosine),
      );
    }).toList();
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
    setDeformMode();
    corners.clear();
  }
}

/// Interaction modes available in the transform overlay.
enum TransformInteractionMode {
  scale,
  rotate,
  deform,
}
