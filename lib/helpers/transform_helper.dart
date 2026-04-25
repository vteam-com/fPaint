import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

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
  final int subdivisions,
) {
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

      // Bilinear interpolation of the 4 corners
      final double topX = corners[0].dx + (corners[1].dx - corners[0].dx) * u;
      final double topY = corners[0].dy + (corners[1].dy - corners[0].dy) * u;
      final double bottomX = corners[3].dx + (corners[2].dx - corners[3].dx) * u;
      final double bottomY = corners[3].dy + (corners[2].dy - corners[3].dy) * u;

      positions[posIndex] = topX + (bottomX - topX) * v;
      positions[posIndex + 1] = topY + (bottomY - topY) * v;

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
  final int subdivisions,
) async {
  double minX = corners[0].dx;
  double maxX = corners[0].dx;
  double minY = corners[0].dy;
  double maxY = corners[0].dy;
  for (final Offset corner in corners) {
    minX = min(minX, corner.dx);
    maxX = max(maxX, corner.dx);
    minY = min(minY, corner.dy);
    maxY = max(maxY, corner.dy);
  }

  final double width = maxX - minX;
  final double height = maxY - minY;

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);

  // Translate so the quad's top-left is at (0,0)
  canvas.translate(-minX, -minY);

  drawPerspectiveImage(canvas, sourceImage, corners, subdivisions);

  return recorder.endRecording().toImage(
    max(1, width.ceil()),
    max(1, height.ceil()),
  );
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
