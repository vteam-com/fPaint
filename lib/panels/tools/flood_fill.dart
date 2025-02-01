import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

Future<ui.Image> applyFloodFill({
  required ui.Image image,
  required int x,
  required int y,
  required Color newColor,
}) async {
  ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  if (byteData == null) {
    return image;
  }

  Uint8List pixels = byteData.buffer.asUint8List();
  int width = image.width;
  int height = image.height;
  int bytesPerPixel = 4; // RGBA format

  int index(int x, int y) {
    return (y * width + x) * bytesPerPixel;
  }

  // Check bounds
  if (x < 0 || x >= width || y < 0 || y >= height) {
    return image;
  }

  // Extract target color
  int targetIndex = index(x, y);
  int targetR = pixels[targetIndex];
  int targetG = pixels[targetIndex + 1];
  int targetB = pixels[targetIndex + 2];
  int targetA = pixels[targetIndex + 3];

  // Extract new color
  // ignore: deprecated_member_use
  int fillR = newColor.red;
  // ignore: deprecated_member_use
  int fillG = newColor.green;
  // ignore: deprecated_member_use
  int fillB = newColor.blue;
  // ignore: deprecated_member_use
  int fillA = newColor.alpha;

  // Avoid unnecessary fill
  if (targetR == fillR &&
      targetG == fillG &&
      targetB == fillB &&
      targetA == fillA) {
    return image;
  }

  // Stack-based flood fill with visited tracking
  Set<String> visited = {};
  List<Point> stack = [Point(x, y)];

  while (stack.isNotEmpty) {
    Point p = stack.removeLast();
    int px = p.x;
    int py = p.y;

    // Skip if out of bounds
    if (px < 0 || px >= width || py < 0 || py >= height) {
      continue;
    }

    // Skip if already visited
    String key = '$px,$py';
    if (visited.contains(key)) {
      continue;
    }
    visited.add(key);

    int pixelIndex = index(px, py);
    int r = pixels[pixelIndex];
    int g = pixels[pixelIndex + 1];
    int b = pixels[pixelIndex + 2];
    int a = pixels[pixelIndex + 3];

    // Skip if color doesn't match target
    if (r != targetR || g != targetG || b != targetB || a != targetA) {
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
  required Uint8List pixels,
  required int width,
  required int height,
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
