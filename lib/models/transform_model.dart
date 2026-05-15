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

  /// Index constants for independently draggable edge midpoint handles.
  static const int topEdgeIndex = 0;
  static const int rightEdgeIndex = 1;
  static const int bottomEdgeIndex = 2;
  static const int leftEdgeIndex = 3;
  static const int edgeHandleCount = 4;

  /// The captured source image from the selection.
  ui.Image? sourceImage;

  /// The original bounds of the selection (source rectangle in canvas coordinates).
  Rect sourceBounds = Rect.zero;

  /// The 4 corner points defining the destination quadrilateral in canvas coordinates.
  /// Order: topLeft, topRight, bottomRight, bottomLeft.
  List<Offset> corners = <Offset>[];

  /// The 4 independently draggable edge midpoint control points.
  /// Order: top, right, bottom, left.
  List<Offset> edgeMidpoints = <Offset>[];

  /// The active interaction mode for the transform overlay.
  TransformInteractionMode interactionMode = TransformInteractionMode.deform;

  /// Which deform handles are currently enabled for fine tuning.
  TransformHandleSet handleSet = TransformHandleSet.corners;

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
    edgeMidpoints = <Offset>[
      bounds.topCenter,
      bounds.centerRight,
      bounds.bottomCenter,
      bounds.centerLeft,
    ];
    handleSet = TransformHandleSet.corners;
    setDeformMode();
    isVisible = true;
  }

  /// Moves a single corner by [delta] in canvas coordinates.
  void moveCorner(final int index, final Offset delta) {
    corners[index] = corners[index] + delta;
  }

  /// Moves one edge midpoint control handle by [delta] in canvas coordinates.
  void moveEdgeHandle(final int index, final Offset delta) {
    edgeMidpoints[index] = edgeMidpoints[index] + delta;
  }

  /// Moves an entire edge by [delta], keeping its two corners and midpoint in sync.
  void moveConnectedEdge(final int index, final Offset delta) {
    final (int, int)? cornerIndices = _cornerIndicesForEdge(index);
    if (cornerIndices == null || index < 0 || index >= edgeMidpoints.length) {
      return;
    }

    final (int firstCornerIndex, int secondCornerIndex) = cornerIndices;
    corners[firstCornerIndex] = corners[firstCornerIndex] + delta;
    corners[secondCornerIndex] = corners[secondCornerIndex] + delta;
    edgeMidpoints[index] = edgeMidpoints[index] + delta;
  }

  /// Moves all corners by [delta] in canvas coordinates (translate).
  void moveAll(final Offset delta) {
    for (int i = 0; i < corners.length; i++) {
      corners[i] = corners[i] + delta;
    }
    for (int i = 0; i < edgeMidpoints.length; i++) {
      edgeMidpoints[i] = edgeMidpoints[i] + delta;
    }
  }

  /// Whether the overlay is currently in deform mode.
  bool get isDeformMode => interactionMode == TransformInteractionMode.deform;

  /// Whether the overlay is currently in rotate mode.
  bool get isRotateMode => interactionMode == TransformInteractionMode.rotate;

  /// Whether the overlay is currently in uniform scale mode.
  bool get isScaleMode => interactionMode == TransformInteractionMode.scale;

  /// Whether the corner handles are currently enabled.
  bool get areCornerHandlesEnabled => handleSet == TransformHandleSet.corners || handleSet == TransformHandleSet.all;

  /// Whether the edge midpoint handles are currently enabled.
  bool get areEdgeHandlesEnabled => handleSet == TransformHandleSet.edges || handleSet == TransformHandleSet.all;

  /// Whether the center move handle is currently enabled.
  bool get isCenterHandleEnabled => handleSet == TransformHandleSet.all;

  /// The edge midpoint controls currently applied to the warp mesh.
  List<Offset> get effectiveEdgeMidpoints {
    if (corners.length != cornerCount) {
      return List<Offset>.from(edgeMidpoints);
    }
    if (areEdgeHandlesEnabled && edgeMidpoints.length == edgeHandleCount) {
      return List<Offset>.from(edgeMidpoints);
    }
    return <Offset>[
      _straightEdgeMidpoint(topLeftIndex, topRightIndex),
      _straightEdgeMidpoint(topRightIndex, bottomRightIndex),
      _straightEdgeMidpoint(bottomRightIndex, bottomLeftIndex),
      _straightEdgeMidpoint(bottomLeftIndex, topLeftIndex),
    ];
  }

  /// Whether a live feedback bubble should be shown.
  bool get isFeedbackVisible => isScaleFeedbackVisible || isRotationFeedbackVisible;

  /// Sets deform mode, resets to corner handles, and clears transient feedback.
  void setDeformMode() {
    handleSet = TransformHandleSet.corners;
    interactionMode = TransformInteractionMode.deform;
    endScaleGesture();
    endRotateGesture();
  }

  /// Cycles the enabled transform handles from corners, to edges, to all controls.
  void cycleHandleSet() {
    switch (handleSet) {
      case TransformHandleSet.corners:
        handleSet = TransformHandleSet.edges;
      case TransformHandleSet.edges:
        handleSet = TransformHandleSet.all;
      case TransformHandleSet.all:
        handleSet = TransformHandleSet.corners;
    }
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
    edgeMidpoints = edgeMidpoints.map((final Offset midpoint) {
      final Offset vector = midpoint - scaleCenter;
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
    edgeMidpoints = edgeMidpoints.map((final Offset midpoint) {
      final Offset vector = midpoint - rotationCenter;
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
    final int? edgeIndex = _edgeIndexForCorners(index1, index2);
    final List<Offset> activeEdgeMidpoints = effectiveEdgeMidpoints;
    if (edgeIndex != null && activeEdgeMidpoints.length == edgeHandleCount) {
      return activeEdgeMidpoints[edgeIndex];
    }
    return _straightEdgeMidpoint(index1, index2);
  }

  /// Returns the ordered boundary control points for the current mesh.
  List<Offset> get boundaryPoints {
    final List<Offset> activeEdgeMidpoints = effectiveEdgeMidpoints;
    if (corners.length != cornerCount || activeEdgeMidpoints.length != edgeHandleCount) {
      return List<Offset>.from(corners);
    }

    return <Offset>[
      corners[topLeftIndex],
      activeEdgeMidpoints[topEdgeIndex],
      corners[topRightIndex],
      activeEdgeMidpoints[rightEdgeIndex],
      corners[bottomRightIndex],
      activeEdgeMidpoints[bottomEdgeIndex],
      corners[bottomLeftIndex],
      activeEdgeMidpoints[leftEdgeIndex],
    ];
  }

  /// Returns the bounding rect of the quad in canvas coordinates.
  Rect get quadBounds {
    if (corners.isEmpty && edgeMidpoints.isEmpty) {
      return Rect.zero;
    }
    final List<Offset> activeEdgeMidpoints = effectiveEdgeMidpoints;
    final List<Offset> controlPoints = <Offset>[
      ...corners,
      ...activeEdgeMidpoints,
    ];
    double minX = controlPoints.first.dx;
    double maxX = controlPoints.first.dx;
    double minY = controlPoints.first.dy;
    double maxY = controlPoints.first.dy;
    for (final Offset point in controlPoints) {
      if (point.dx < minX) {
        minX = point.dx;
      }
      if (point.dx > maxX) {
        maxX = point.dx;
      }
      if (point.dy < minY) {
        minY = point.dy;
      }
      if (point.dy > maxY) {
        maxY = point.dy;
      }
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Maps a corner-pair edge query onto the stored edge midpoint index.
  int? _edgeIndexForCorners(final int index1, final int index2) {
    final Set<int> indices = <int>{index1, index2};
    if (indices.length != AppMath.pair) {
      return null;
    }
    if (indices.contains(topLeftIndex) && indices.contains(topRightIndex)) {
      return topEdgeIndex;
    }
    if (indices.contains(topRightIndex) && indices.contains(bottomRightIndex)) {
      return rightEdgeIndex;
    }
    if (indices.contains(bottomRightIndex) && indices.contains(bottomLeftIndex)) {
      return bottomEdgeIndex;
    }
    if (indices.contains(bottomLeftIndex) && indices.contains(topLeftIndex)) {
      return leftEdgeIndex;
    }
    return null;
  }

  /// Returns the straight midpoint between two corners.
  Offset _straightEdgeMidpoint(final int index1, final int index2) {
    return Offset(
      (corners[index1].dx + corners[index2].dx) / AppMath.pair,
      (corners[index1].dy + corners[index2].dy) / AppMath.pair,
    );
  }

  /// Maps an edge midpoint index onto the two corner indices it connects.
  (int, int)? _cornerIndicesForEdge(final int edgeIndex) {
    switch (edgeIndex) {
      case topEdgeIndex:
        return (topLeftIndex, topRightIndex);
      case rightEdgeIndex:
        return (topRightIndex, bottomRightIndex);
      case bottomEdgeIndex:
        return (bottomRightIndex, bottomLeftIndex);
      case leftEdgeIndex:
        return (bottomLeftIndex, topLeftIndex);
      default:
        return null;
    }
  }

  @override
  void clear() {
    super.clear();
    sourceImage = null;
    sourceBounds = Rect.zero;
    handleSet = TransformHandleSet.corners;
    setDeformMode();
    corners.clear();
    edgeMidpoints.clear();
  }
}

/// Which deform handles are active in the transform overlay.
enum TransformHandleSet {
  corners,
  edges,
  all,
}

/// Interaction modes available in the transform overlay.
enum TransformInteractionMode {
  scale,
  rotate,
  deform,
}
