import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

const int _topLeftCornerIndex = 0;
const int _topRightCornerIndex = 1;
const int _bottomRightCornerIndex = 2;
const int _bottomLeftCornerIndex = 3;

const int _topEdgeMidpointIndex = 0;
const int _rightEdgeMidpointIndex = 1;
const int _bottomEdgeMidpointIndex = 2;
const int _leftEdgeMidpointIndex = 3;

/// Renders a perspective-warped image by subdividing the destination quad
/// into a grid of triangles mapped with texture coordinates from the source image.
///
/// [canvas] The canvas to draw on.
/// [image] The source image to warp.
/// [corners] The 4 destination corners in order: topLeft, topRight, bottomRight, bottomLeft.
/// [subdivisions] The number of grid subdivisions for rendering quality.
void drawPerspectiveImage(
  final Canvas canvas,
  final ui.Image image,
  final List<Offset> corners,
  final int subdivisions, {
  final List<Offset>? edgeMidpoints,
}) {
  final double imageWidth = image.width.toDouble();
  final double imageHeight = image.height.toDouble();

  final int gridSize = subdivisions + 1;
  final int vertexCount = gridSize * gridSize;
  const int trianglesPerCell = 2;
  const int verticesPerTriangle = 3;
  final int indexCount = subdivisions * subdivisions * trianglesPerCell * verticesPerTriangle;

  final Float32List positions = Float32List(vertexCount * AppMath.pair);
  final Float32List texCoords = Float32List(vertexCount * AppMath.pair);
  final Uint16List indices = Uint16List(indexCount);

  // Generate grid vertices via bilinear interpolation
  int posIndex = 0;
  for (int j = 0; j <= subdivisions; j++) {
    for (int i = 0; i <= subdivisions; i++) {
      final double u = i / subdivisions;
      final double v = j / subdivisions;
      final Offset destinationPoint = edgeMidpoints == null || edgeMidpoints.length != AppMath.four
          ? _interpolateBilinear(corners: corners, u: u, v: v)
          : _interpolateCoonsPatch(corners: corners, edgeMidpoints: edgeMidpoints, u: u, v: v);

      positions[posIndex] = destinationPoint.dx;
      positions[posIndex + 1] = destinationPoint.dy;

      texCoords[posIndex] = u * imageWidth;
      texCoords[posIndex + 1] = v * imageHeight;

      posIndex += AppMath.pair;
    }
  }

  // Generate triangle indices (2 triangles per grid cell)
  int idxOffset = 0;
  for (int j = 0; j < subdivisions; j++) {
    for (int i = 0; i < subdivisions; i++) {
      final int tl = j * gridSize + i;
      final int tr = tl + 1;
      final int bl = (j + 1) * gridSize + i;
      final int br = bl + 1;

      indices[idxOffset++] = tl;
      indices[idxOffset++] = tr;
      indices[idxOffset++] = br;
      indices[idxOffset++] = tl;
      indices[idxOffset++] = br;
      indices[idxOffset++] = bl;
    }
  }

  final ui.Vertices vertices = ui.Vertices.raw(
    VertexMode.triangles,
    positions,
    textureCoordinates: texCoords,
    indices: indices,
  );

  final Paint paint = Paint()
    ..shader = ImageShader(
      image,
      TileMode.clamp,
      TileMode.clamp,
      Matrix4.identity().storage,
    );

  canvas.drawVertices(vertices, BlendMode.srcOver, paint);
}

/// Renders a perspective-warped image to a [ui.Image] with the quad
/// positioned at the origin of the output.
///
/// [sourceImage] The source image to warp.
/// [corners] The 4 destination corners in canvas coordinates.
/// [subdivisions] The number of grid subdivisions for rendering quality.
Future<ui.Image> renderTransformedImage(
  final ui.Image sourceImage,
  final List<Offset> corners,
  final int subdivisions, {
  final List<Offset>? edgeMidpoints,
}) async {
  final List<Offset> controlPoints = <Offset>[
    ...corners,
    ...?edgeMidpoints,
  ];
  double minX = controlPoints[0].dx;
  double maxX = controlPoints[0].dx;
  double minY = controlPoints[0].dy;
  double maxY = controlPoints[0].dy;
  for (final Offset point in controlPoints) {
    minX = min(minX, point.dx);
    maxX = max(maxX, point.dx);
    minY = min(minY, point.dy);
    maxY = max(maxY, point.dy);
  }

  final double width = maxX - minX;
  final double height = maxY - minY;

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);

  // Translate so the quad's top-left is at (0,0)
  canvas.translate(-minX, -minY);

  drawPerspectiveImage(
    canvas,
    sourceImage,
    corners,
    subdivisions,
    edgeMidpoints: edgeMidpoints,
  );

  return recorder.endRecording().toImage(
    max(1, width.ceil()),
    max(1, height.ceil()),
  );
}

/// Bilinearly interpolates a point inside the quad defined by [corners].
Offset _interpolateBilinear({
  required final List<Offset> corners,
  required final double u,
  required final double v,
}) {
  final double topX =
      corners[_topLeftCornerIndex].dx + (corners[_topRightCornerIndex].dx - corners[_topLeftCornerIndex].dx) * u;
  final double topY =
      corners[_topLeftCornerIndex].dy + (corners[_topRightCornerIndex].dy - corners[_topLeftCornerIndex].dy) * u;
  final double bottomX =
      corners[_bottomLeftCornerIndex].dx +
      (corners[_bottomRightCornerIndex].dx - corners[_bottomLeftCornerIndex].dx) * u;
  final double bottomY =
      corners[_bottomLeftCornerIndex].dy +
      (corners[_bottomRightCornerIndex].dy - corners[_bottomLeftCornerIndex].dy) * u;

  return Offset(
    topX + (bottomX - topX) * v,
    topY + (bottomY - topY) * v,
  );
}

/// Blends the four corner points with the four draggable edge midpoints.
///
/// This uses a Coons patch so the interior follows the independently dragged
/// top, right, bottom, and left edge controls instead of collapsing them back
/// to straight corner-to-corner edges.
Offset _interpolateCoonsPatch({
  required final List<Offset> corners,
  required final List<Offset> edgeMidpoints,
  required final double u,
  required final double v,
}) {
  final Offset topPoint = _interpolatePiecewiseLinear(
    start: corners[_topLeftCornerIndex],
    midpoint: edgeMidpoints[_topEdgeMidpointIndex],
    end: corners[_topRightCornerIndex],
    t: u,
  );
  final Offset bottomPoint = _interpolatePiecewiseLinear(
    start: corners[_bottomLeftCornerIndex],
    midpoint: edgeMidpoints[_bottomEdgeMidpointIndex],
    end: corners[_bottomRightCornerIndex],
    t: u,
  );
  final Offset leftPoint = _interpolatePiecewiseLinear(
    start: corners[_topLeftCornerIndex],
    midpoint: edgeMidpoints[_leftEdgeMidpointIndex],
    end: corners[_bottomLeftCornerIndex],
    t: v,
  );
  final Offset rightPoint = _interpolatePiecewiseLinear(
    start: corners[_topRightCornerIndex],
    midpoint: edgeMidpoints[_rightEdgeMidpointIndex],
    end: corners[_bottomRightCornerIndex],
    t: v,
  );

  final Offset blendedBoundary = (topPoint * (1 - v)) + (bottomPoint * v) + (leftPoint * (1 - u)) + (rightPoint * u);
  final Offset bilinearCorners =
      (corners[_topLeftCornerIndex] * ((1 - u) * (1 - v))) +
      (corners[_topRightCornerIndex] * (u * (1 - v))) +
      (corners[_bottomLeftCornerIndex] * ((1 - u) * v)) +
      (corners[_bottomRightCornerIndex] * (u * v));

  return blendedBoundary - bilinearCorners;
}

/// Interpolates along one boundary segment split into start-midpoint-end spans.
Offset _interpolatePiecewiseLinear({
  required final Offset start,
  required final Offset midpoint,
  required final Offset end,
  required final double t,
}) {
  if (t <= AppVisual.half) {
    return Offset.lerp(start, midpoint, t / AppVisual.half)!;
  }
  return Offset.lerp(midpoint, end, (t - AppVisual.half) / AppVisual.half)!;
}

/// Platform channel for macOS trackpad haptic feedback.
const MethodChannel _hapticChannel = MethodChannel('com.vteam.fpaint/haptic');

/// Fires haptic feedback when the cumulative rotation crosses any multiple
/// of [AppMath.rotationSnapInterval] degrees.
///
/// [previousDegrees] is the rotation before the latest delta was applied.
/// [currentDegrees] is the rotation after.
void triggerRotationSnapHaptic(
  final double previousDegrees,
  final double currentDegrees,
) {
  const double interval = AppMath.rotationSnapInterval;

  // Which snap bucket each value falls in (floor towards −∞).
  final int prevSlot = (previousDegrees / interval).floor();
  final int currSlot = (currentDegrees / interval).floor();

  if (prevSlot != currSlot) {
    _performHaptic();
  }
}

/// Fires haptic feedback when the cumulative scale crosses any multiple
/// of [AppMath.scaleSnapInterval] percent.
///
/// [previousPercent] is the scale percentage before the latest factor was applied.
/// [currentPercent] is the scale percentage after.
void triggerScaleSnapHaptic(
  final double previousPercent,
  final double currentPercent,
) {
  const double interval = AppMath.scaleSnapInterval;

  // Which snap bucket each value falls in (floor towards −∞).
  final int prevSlot = (previousPercent / interval).floor();
  final int currSlot = (currentPercent / interval).floor();

  if (prevSlot != currSlot) {
    _performHaptic();
  }
}

/// Fires haptic feedback when the selection crosses the perfect-square
/// boundary (width == height).
///
/// Triggers when the sign of `width − height` changes between
/// [previousBounds] and [currentBounds].
void triggerSquareSnapHaptic(
  final Rect previousBounds,
  final Rect currentBounds,
) {
  final double prevDiff = previousBounds.width - previousBounds.height;
  final double currDiff = currentBounds.width - currentBounds.height;

  // Crossed zero in either direction, or just arrived at zero.
  if ((prevDiff > 0 && currDiff <= 0) || (prevDiff < 0 && currDiff >= 0)) {
    _performHaptic();
  }
}

/// Triggers a platform-appropriate haptic tick.
void _performHaptic() {
  if (Platform.isMacOS) {
    _hapticChannel.invokeMethod<void>('hapticAlignment');
  } else {
    HapticFeedback.mediumImpact();
  }
}
