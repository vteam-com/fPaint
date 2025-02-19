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

class Point {
  Point(this.x, this.y);
  int x;
  int y;
}

final int bytesPerPixel = 4;

int index(final int x, final int y, final int width) {
  return (y * width + x) * bytesPerPixel;
}

// Function to extract the region as a ui.Path
Future<Region> extractRegionByColorEdgeAndOffset({
  required final ui.Image image,
  required final int x,
  required final int y,
  required final int tolerance,
}) async {
  final Region region = Region();

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

  // Visited set and queue for region growing
  final Set<int> visited = <int>{};
  final Queue<Point> queue = Queue<Point>();
  queue.add(Point(x, y));

  // Accumulate all points in the region
  final List<Point> points = <Point>[];

  // Track the region's bounds
  region.left = x.toDouble();
  region.top = y.toDouble();

  while (queue.isNotEmpty) {
    final Point p = queue.removeFirst();
    final int px = p.x;
    final int py = p.y;

    // Check bounds
    if (px < 0 || px >= width || py < 0 || py >= height) {
      continue;
    }

    // Skip if already visited
    final int key = px + py * width;
    if (!visited.add(key)) {
      continue;
    }

    // Get the pixel color
    final int pixelIndex = index(px, py, width);
    final int r = pixels[pixelIndex];
    final int g = pixels[pixelIndex + 1];
    final int b = pixels[pixelIndex + 2];
    final int a = pixels[pixelIndex + 3];

    // Check color tolerance
    if ((r - targetR).abs() > tolerance255 ||
        (g - targetG).abs() > tolerance255 ||
        (b - targetB).abs() > tolerance255 ||
        (a - targetA).abs() > tolerance255) {
      continue;
    }

    // Add the point to the region
    points.add(p);

    // Track the region bounds
    region.left = min(region.left, px.toDouble());
    region.top = min(region.top, py.toDouble());

    // Add 4-connected neighbors
    queue.add(Point(px + 1, py));
    queue.add(Point(px - 1, py));
    queue.add(Point(px, py + 1));
    queue.add(Point(px, py - 1));
  } // main detection loop

  //------------------------------------------------------------------
  // Optimize and combine the points(pixels)
  //
  final ui.Path linePaths = Path();

  final Map<int, List<Point>> rows = <int, List<Point>>{};

  // Group points by rows
  for (final Point p in points) {
    rows.putIfAbsent(p.y, () => <Point>[]).add(p);
  }

  // Sort each row by X to detect runs
  for (final int y in rows.keys) {
    final List<Point> rowPoints = rows[y] ?? <Point>[];
    rowPoints.sort((final Point a, final Point b) => a.x.compareTo(b.x));

    int startX = rowPoints[0].x;
    int endX = rowPoints[0].x;

    for (int i = 1; i < rowPoints.length; i++) {
      final int currentX = rowPoints[i].x;

      if (currentX == endX + 1) {
        // Continue the current run
        endX = currentX;
      } else {
        // Close the current run and start a new one
        linePaths.addRect(
          Rect.fromLTWH(
            startX.toDouble(),
            y.toDouble(),
            (endX - startX + 1).toDouble(),
            1,
          ),
        );
        startX = currentX;
        endX = currentX;
      }
    }

    // Add the last run for the row
    linePaths.addRect(
      Rect.fromLTWH(
        startX.toDouble(),
        y.toDouble(),
        (endX - startX + 1).toDouble(),
        1,
      ),
    );
  }

  region.path = ui.Path.combine(ui.PathOperation.union, region.path, linePaths);

  //------------------------------------------------------------------
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
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = Canvas(recorder);

  // Draw the original image
  final ui.Paint paint = Paint();
  canvas.drawImage(image, Offset.zero, paint);

  // Apply color to the path
  final ui.Paint fillPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = newColor;

  final ui.Path shiftedPath = path.shift(offset);
  canvas.drawPath(shiftedPath, fillPaint);

  final ui.Picture picture = recorder.endRecording();

  return await picture.toImage(image.width.toInt(), image.height.toInt());
}

void printPathCoordinates(final ui.Path path) {
  final ui.PathMetrics pathMetrics = path.computeMetrics();
  // ignore: avoid_print
  print('---------------------------------');
  final List<Offset> positionsSampling = <ui.Offset>[];

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
  final List<Offset> reducedPositions = <ui.Offset>[];
  for (int i = 0; i < positionsSampling.length; i++) {
    if (i == 0 ||
        i == positionsSampling.length - 1 ||
        (positionsSampling[i] != positionsSampling[i - 1] &&
            positionsSampling[i] != positionsSampling[i + 1])) {
      reducedPositions.add(positionsSampling[i]);
    }
  }
  final List<String> strings = <String>[];

  for (final ui.Offset position in reducedPositions) {
    strings.add(
      '[${position.dx.toStringAsFixed(0)}|${position.dy.toStringAsFixed(0)}]',
    );
  }
  debugPrint(strings.join());
}
