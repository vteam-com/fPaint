import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

Future<ui.Image> applyFloodFill({
  required final ui.Image image,
  required final int x,
  required final int y,
  required final Color newColor,
  required final int tolerance,
}) async {
  final ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  if (byteData == null) {
    return image;
  }

  final Uint8List pixels = byteData.buffer.asUint8List();
  final int width = image.width;
  final int height = image.height;
  final int bytesPerPixel = 4; // RGBA format

  int index(final int x, final int y) {
    return (y * width + x) * bytesPerPixel;
  }

  // Check bounds
  if (x < 0 || x >= width || y < 0 || y >= height) {
    return image;
  }

  // Extract target color
  final int targetIndex = index(x, y);
  final int targetR = pixels[targetIndex];
  final int targetG = pixels[targetIndex + 1];
  final int targetB = pixels[targetIndex + 2];
  final int targetA = pixels[targetIndex + 3];

  // Extract new color
  // ignore: deprecated_member_use
  final int fillR = newColor.red;
  // ignore: deprecated_member_use
  final int fillG = newColor.green;
  // ignore: deprecated_member_use
  final int fillB = newColor.blue;
  // ignore: deprecated_member_use
  final int fillA = newColor.alpha;

  // Avoid unnecessary fill
  if (targetR == fillR &&
      targetG == fillG &&
      targetB == fillB &&
      targetA == fillA) {
    return image;
  }

  // Stack-based flood fill with visited tracking
  final Set<String> visited = {};
  final List<Point> stack = [Point(x, y)];

  while (stack.isNotEmpty) {
    final Point p = stack.removeLast();
    final int px = p.x;
    final int py = p.y;

    // Skip if out of bounds
    if (px < 0 || px >= width || py < 0 || py >= height) {
      continue;
    }

    // Skip if already visited
    final String key = '$px,$py';
    if (visited.contains(key)) {
      continue;
    }
    visited.add(key);

    final int pixelIndex = index(px, py);
    final int r = pixels[pixelIndex];
    final int g = pixels[pixelIndex + 1];
    final int b = pixels[pixelIndex + 2];
    final int a = pixels[pixelIndex + 3];

    /// Converts the given tolerance percentage to a value out of 255.
    ///
    /// The tolerance is expected to be a percentage (0-100). This value is then
    /// converted to a scale of 0-255, which is commonly used in color calculations.
    ///
    final double tolerance255 = 255 * (tolerance / 100);

    // Skip if color doesn't match target within tolerance
    if ((r - targetR).abs() > tolerance255 ||
        (g - targetG).abs() > tolerance255 ||
        (b - targetB).abs() > tolerance255 ||
        (a - targetA).abs() > tolerance255) {
      continue;
    }

    // Set new color
    pixels[pixelIndex] = fillR;
    pixels[pixelIndex + 1] = fillG;
    pixels[pixelIndex + 2] = fillB;
    pixels[pixelIndex + 3] = fillA;

    // Push neighboring pixels
    stack.add(Point(px + 1, py));
    stack.add(Point(px - 1, py));
    stack.add(Point(px, py + 1));
    stack.add(Point(px, py - 1));
  }

  // Convert back to ui.Image
  return await _createImageFromPixels(
    pixels: pixels,
    width: width,
    height: height,
  );
}

Future<ui.Image> _createImageFromPixels({
  required final Uint8List pixels,
  required final int width,
  required final int height,
}) async {
  final Completer<ui.Image> completer = Completer();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    (ui.Image img) {
      completer.complete(img);
    },
  );
  return completer.future;
}

class Point {
  Point(this.x, this.y);
  final int x, y;
}
