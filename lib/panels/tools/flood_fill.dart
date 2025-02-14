import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fpaint/helpers/image_helper.dart';

Future<ui.Image> applyFloodFill({
  required final ui.Image image,
  required final int x,
  required final int y,
  required final int tolerance,
  required final Color newColor,
}) async {
  final Region region = await extractRegionByColorEdgeAndOffset(
    image: image,
    x: x,
    y: y,
    tolerance: 10,
  );

  final ui.Image newImage = await applyColorRegionToImage(
    image: image,
    offset: Offset(region.left, region.top),
    path: region.path,
    newColor: newColor,
  );
  return newImage;
}

Future<ui.Path> extractRegionByColorEdge({
  required final ui.Image image,
  required final int x,
  required final int y,
  required final int tolerance,
}) async {
  final Region r = await extractRegionByColorEdgeAndOffset(
    image: image,
    x: x,
    y: y,
    tolerance: tolerance,
  );
  return r.path;
}

class Region {
  double left = double.infinity;
  double top = double.infinity;
  Offset get offset => Offset(left, top);
  Path path = Path();
}

final int bytesPerPixel = 4;

int index(final int x, final int y, int width) {
  return (y * width + x) * bytesPerPixel;
}

// Function to extract the region as a ui.Path
Future<Region> extractRegionByColorEdgeAndOffset({
  required final ui.Image image,
  required final int x,
  required final int y,
  required final int tolerance,
}) async {
  Region region = Region();

  final Uint8List? pixels = await convertImageToUint8List(image);
  if (pixels == null) {
    return region;
  }

  final int width = image.width;
  final int height = image.height;

  // Check if the starting point is within bounds
  if (x < 0 || x >= width || y < 0 || y >= height) {
    return region;
  }

  // Get the target color at the starting point
  final int targetIndex = index(x, y, width);
  final int targetR = pixels[targetIndex];
  final int targetG = pixels[targetIndex + 1];
  final int targetB = pixels[targetIndex + 2];
  final int targetA = pixels[targetIndex + 3];

  /// Converts the given tolerance percentage to a value out of 255.
  ///
  /// The tolerance is expected to be a percentage (0-100). This value is then
  /// converted to a scale of 0-255, which is commonly used in color calculations.
  ///
  final double tolerance255 = 255 * (tolerance / 100);

  // Visited set and stack for region growing
  final Set<int> visited = {};
  Queue<Point> queue = Queue();
  queue.add(Point(x, y));

  while (queue.isNotEmpty) {
    final Point p = queue.removeLast();
    final int px = p.x;
    final int py = p.y;

    // Check bounds
    if (px < 0 || px >= width || py < 0 || py >= height) {
      continue;
    }

    // Skip if already visited
    final int key = px + py * width;
    if (visited.contains(key)) {
      continue;
    }
    visited.add(key);

    final int pixelIndex = index(px, py, width);
    final int r = pixels[pixelIndex];
    final int g = pixels[pixelIndex + 1];
    final int b = pixels[pixelIndex + 2];
    final int a = pixels[pixelIndex + 3];

    // Skip if the pixel doesn't match the target color within the tolerance
    if ((r - targetR).abs() > tolerance255 ||
        (g - targetG).abs() > tolerance255 ||
        (b - targetB).abs() > tolerance255 ||
        (a - targetA).abs() > tolerance255) {
      continue;
    }

    // Create a small rectangle for the current pixel
    region.left = min(region.left, px.toDouble());
    region.top = min(region.top, py.toDouble());
    final ui.Rect pixel = Rect.fromLTWH(px.toDouble(), py.toDouble(), 1, 1);

    // Move to the starting point if the regionPath is empty
    if (region.path.getBounds().isEmpty) {
      region.path.moveTo(px.toDouble(), py.toDouble());
      region.path.addRect(pixel);
    } else {
      ui.Path pixelPath = ui.Path();
      pixelPath.addRect(pixel);
      // Combine the current pixel's path with the growing region path
      region.path =
          ui.Path.combine(ui.PathOperation.union, region.path, pixelPath);
    }

    // Add 4-connected neighbors pixels to the stack
    queue.add(Point(px + 1, py));
    queue.add(Point(px - 1, py));
    queue.add(Point(px, py + 1));
    queue.add(Point(px, py - 1));
  }

  // Normalize the path
  final Rect bounds = region.path.getBounds();
  final Matrix4 matrix = Matrix4.identity()
    ..translate(-bounds.left, -bounds.top);
  region.path = region.path.transform(matrix.storage);
  return region;
}

// Function to apply color to the extracted path
Future<ui.Image> applyColorRegionToImage({
  required final ui.Image image,
  required final Offset offset,
  required final Path path,
  required final Color newColor,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Draw the original image
  final paint = Paint();
  canvas.drawImage(image, Offset.zero, paint);

  // Apply color to the path
  final fillPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = newColor;

  final shiftedPath = path.shift(offset);
  canvas.drawPath(shiftedPath, fillPaint);

  final ui.Picture picture = recorder.endRecording();

  return await picture.toImage(image.width.toInt(), image.height.toInt());
}

class Point {
  Point(this.x, this.y);
  int x;
  int y;
}

void printPathCoordinates(ui.Path path) {
  final ui.PathMetrics pathMetrics = path.computeMetrics();
  // ignore: avoid_print
  print('---------------------------------');
  List<Offset> positionsSampling = [];

  for (final ui.PathMetric metric in pathMetrics) {
    for (double t = 0.0; t <= 1.0; t += 0.5) {
      // Sample points along the path
      final ui.Offset? position =
          metric.getTangentForOffset(metric.length * t)?.position;
      if (position != null) {
        positionsSampling.add(
          Offset(
            position.dx.floor().toDouble(),
            position.dy.floor().toDouble(),
          ),
        );
      }
    }
  }

  // Reduce redundant values
  List<Offset> reducedPositions = [];
  for (int i = 0; i < positionsSampling.length; i++) {
    if (i == 0 ||
        i == positionsSampling.length - 1 ||
        (positionsSampling[i] != positionsSampling[i - 1] &&
            positionsSampling[i] != positionsSampling[i + 1])) {
      reducedPositions.add(positionsSampling[i]);
    }
  }
  List<String> strings = [];

  for (final position in reducedPositions) {
    strings.add(
      '[${position.dx.toStringAsFixed(0)}|${position.dy.toStringAsFixed(0)}]',
    );
  }
  debugPrint(strings.join());
}
