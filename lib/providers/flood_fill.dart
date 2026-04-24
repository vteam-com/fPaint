// ignore: fcheck_one_class_per_file
import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';

/// Represents a region in an image, defined by its bounding box and a path.
class Region {
  double left = double.infinity;
  double top = double.infinity;

  /// Gets the offset of the region, which is the top-left corner of its bounding box.
  Offset get offset => Offset(left, top);

  /// The path that defines the shape of the region.
  Path path = Path();
}

/// Represents a point in a 2D space with integer coordinates.
class Point {
  Point(this.x, this.y);

  /// The x-coordinate of the point.
  int x;

  /// The y-coordinate of the point.
  int y;
}

/// The number of bytes per pixel in the image data (assumed to be 4 for RGBA).
final int bytesPerPixel = AppMath.bytesPerPixel;

/// Calculates the index of a pixel in a byte array representing image data.
///
/// The index is calculated based on the x and y coordinates of the pixel, as well as the
/// width of the image. The image data is assumed to be in RGBA format, with 4 bytes per pixel.
///
/// Parameters:
///   [x]     The x-coordinate of the pixel.
///   [y]     The y-coordinate of the pixel.
///   [width] The width of the image.
///
/// Returns:
///   The index of the pixel in the byte array.
int index(final int x, final int y, final int width) {
  return (y * width + x) * bytesPerPixel;
}

/// Extracts a region from an image based on color similarity, returning a [Region] object.
///
/// This function starts at the specified coordinates (x, y) in the [image] and identifies a
/// connected region of pixels that are within the specified [tolerance] of the color at the
/// starting point. The identified region is then converted into a [ui.Path] and stored in a
/// [Region] object, along with the region's bounding box.
///
/// Parameters:
///   [image]     The image to extract the region from.
///   [x]         The x-coordinate of the starting point for the region extraction.
///   [y]         The y-coordinate of the starting point for the region extraction.
///   [tolerance] The tolerance (as a percentage) for color matching. A higher tolerance
///               value means that colors further away from the starting color will be included
///               in the extracted region.
///
/// Returns:
///   A [Region] object containing the extracted region's bounding box and path.
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
    final int b = pixels[pixelIndex + AppMath.pair];
    final int a = pixels[pixelIndex + AppMath.triple];

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
  final Matrix4 matrix = Matrix4.translationValues(-bounds.left, -bounds.top, 0);
  region.path = region.path.transform(matrix.storage);

  return region;
}
