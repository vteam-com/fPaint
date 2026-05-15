// ignore: fcheck_one_class_per_file
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

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
const int bytesPerPixel = AppMath.bytesPerPixel;

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

/// Work package passed to the flood-fill isolate worker.
class _FloodFillTaskInput {
  const _FloodFillTaskInput({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.tolerance,
    required this.pixelData,
  });

  final int x;
  final int y;
  final int width;
  final int height;
  final int tolerance;
  final TransferableTypedData pixelData;
}

/// Compact flood-fill worker output containing horizontal runs.
class _FloodFillTaskOutput {
  const _FloodFillTaskOutput({
    required this.runs,
    required this.left,
    required this.top,
    required this.hasRegion,
  });

  final Int32List runs;
  final int left;
  final int top;
  final bool hasRegion;
}

class _SpanStack {
  _SpanStack() : _capacity = AppFloodFill.initialSpanStackCapacity {
    _x = Int32List(_capacity);
    _y = Int32List(_capacity);
  }

  late Int32List _x;
  late Int32List _y;
  int _size = AppMath.zero;
  int _capacity;

  /// Returns true when no spans remain to process.
  bool get isEmpty => _size == AppMath.zero;

  /// Pushes a candidate pixel coordinate onto the span stack.
  void push(final int x, final int y) {
    if (_size >= _capacity) {
      _grow();
    }
    _x[_size] = x;
    _y[_size] = y;
    _size += AppMath.one;
  }

  /// Pops the most recently pushed candidate coordinate.
  Point pop() {
    _size -= AppMath.one;
    return Point(_x[_size], _y[_size]);
  }

  /// Doubles stack capacity while preserving existing span entries.
  void _grow() {
    final int nextCapacity = _capacity * AppMath.pair;
    final Int32List nextX = Int32List(nextCapacity);
    final Int32List nextY = Int32List(nextCapacity);
    nextX.setRange(AppMath.zero, _capacity, _x);
    nextY.setRange(AppMath.zero, _capacity, _y);
    _x = nextX;
    _y = nextY;
    _capacity = nextCapacity;
  }
}

class _RunBuffer {
  _RunBuffer() : _capacity = AppFloodFill.initialRunCapacity {
    _runs = Int32List(_capacity * AppFloodFill.runStride);
  }

  late Int32List _runs;
  int _size = AppMath.zero;
  int _capacity;

  /// Appends one horizontal run triple: y, startX, endX.
  void add(final int y, final int startX, final int endX) {
    if (_size >= _capacity) {
      _grow();
    }

    final int base = _size * AppFloodFill.runStride;
    _runs[base] = y;
    _runs[base + AppMath.rgbChannelGreen] = startX;
    _runs[base + AppMath.rgbChannelBlue] = endX;
    _size += AppMath.rgbChannelGreen;
  }

  /// Returns a tightly-sized run list containing only populated entries.
  Int32List toTrimmedList() {
    return Int32List.fromList(
      _runs.sublist(AppMath.zero, _size * AppFloodFill.runStride),
    );
  }

  /// Doubles run capacity while preserving existing run triples.
  void _grow() {
    final int nextCapacity = _capacity * AppMath.pair;
    final Int32List next = Int32List(nextCapacity * AppFloodFill.runStride);
    next.setRange(
      AppMath.zero,
      _capacity * AppFloodFill.runStride,
      _runs,
    );
    _runs = next;
    _capacity = nextCapacity;
  }
}

/// Executes scan line flood-fill and returns compact horizontal run output.
_FloodFillTaskOutput _runFloodFillTask(final _FloodFillTaskInput input) {
  final Uint8List pixels = input.pixelData.materialize().asUint8List();
  final int width = input.width;
  final int height = input.height;
  final int x = input.x;
  final int y = input.y;

  if (x < AppMath.zero || x >= width || y < AppMath.zero || y >= height) {
    return _FloodFillTaskOutput(
      runs: Int32List(0),
      left: AppMath.zero,
      top: AppMath.zero,
      hasRegion: false,
    );
  }

  final int targetIndex = index(x, y, width);
  final int targetR = pixels[targetIndex + AppMath.rgbChannelRed];
  final int targetG = pixels[targetIndex + AppMath.rgbChannelGreen];
  final int targetB = pixels[targetIndex + AppMath.rgbChannelBlue];
  final int targetA = pixels[targetIndex + AppMath.rgbChannelAlpha];
  final int tolerance255 = (AppLimits.rgbChannelMax * input.tolerance) ~/ AppFloodFill.toleranceDenominatorPercent;

  final Uint8List visited = Uint8List(width * height);
  final _SpanStack spanStack = _SpanStack();
  final _RunBuffer runBuffer = _RunBuffer();

  int minX = width;
  int minY = height;
  bool hasRegion = false;

  spanStack.push(x, y);

  while (!spanStack.isEmpty) {
    final Point point = spanStack.pop();
    final int py = point.y;
    final int px = point.x;

    if (py < AppMath.zero || py >= height || px < AppMath.zero || px >= width) {
      continue;
    }

    final int rowBase = py * width;
    final int rowKey = rowBase + px;
    if (visited[rowKey] == AppFloodFill.visitedMarker) {
      continue;
    }

    // Inline tolerance check for the starting pixel
    final int testIndex = rowKey * bytesPerPixel;
    final int r = pixels[testIndex + AppMath.rgbChannelRed];
    final int g = pixels[testIndex + AppMath.rgbChannelGreen];
    final int b = pixels[testIndex + AppMath.rgbChannelBlue];
    final int a = pixels[testIndex + AppMath.rgbChannelAlpha];

    if ((r - targetR).abs() > tolerance255 ||
        (g - targetG).abs() > tolerance255 ||
        (b - targetB).abs() > tolerance255 ||
        (a - targetA).abs() > tolerance255) {
      visited[rowKey] = AppFloodFill.visitedMarker;
      continue;
    }

    // Expand left
    int left = px;
    while (left > AppMath.zero) {
      final int candidate = left - AppMath.rgbChannelGreen;
      final int candidateKey = rowBase + candidate;
      if (visited[candidateKey] == AppFloodFill.visitedMarker) {
        break;
      }
      final int candidateIndex = candidateKey * bytesPerPixel;
      final int cr = pixels[candidateIndex + AppMath.rgbChannelRed];
      final int cg = pixels[candidateIndex + AppMath.rgbChannelGreen];
      final int cb = pixels[candidateIndex + AppMath.rgbChannelBlue];
      final int ca = pixels[candidateIndex + AppMath.rgbChannelAlpha];
      if ((cr - targetR).abs() > tolerance255 ||
          (cg - targetG).abs() > tolerance255 ||
          (cb - targetB).abs() > tolerance255 ||
          (ca - targetA).abs() > tolerance255) {
        break;
      }
      left = candidate;
    }

    // Expand right
    int right = px;
    while (right < width - AppMath.rgbChannelGreen) {
      final int candidate = right + AppMath.rgbChannelGreen;
      final int candidateKey = rowBase + candidate;
      if (visited[candidateKey] == AppFloodFill.visitedMarker) {
        break;
      }
      final int candidateIndex = candidateKey * bytesPerPixel;
      final int cr = pixels[candidateIndex + AppMath.rgbChannelRed];
      final int cg = pixels[candidateIndex + AppMath.rgbChannelGreen];
      final int cb = pixels[candidateIndex + AppMath.rgbChannelBlue];
      final int ca = pixels[candidateIndex + AppMath.rgbChannelAlpha];
      if ((cr - targetR).abs() > tolerance255 ||
          (cg - targetG).abs() > tolerance255 ||
          (cb - targetB).abs() > tolerance255 ||
          (ca - targetA).abs() > tolerance255) {
        break;
      }
      right = candidate;
    }

    // Mark entire run as visited
    for (int xIndex = left; xIndex <= right; xIndex += AppMath.rgbChannelGreen) {
      visited[rowBase + xIndex] = AppFloodFill.visitedMarker;
    }

    if (py < minY) {
      minY = py;
    }
    if (left < minX) {
      minX = left;
    }
    hasRegion = true;
    runBuffer.add(py, left, right);

    // Push spans from row above
    final int rowAbove = py - AppMath.rgbChannelGreen;
    if (rowAbove >= AppMath.zero) {
      int scanX = left;
      while (scanX <= right) {
        final int key = rowAbove * width + scanX;
        if (visited[key] != AppFloodFill.visitedMarker) {
          final int pixelIndex = key * bytesPerPixel;
          final int cr = pixels[pixelIndex + AppMath.rgbChannelRed];
          final int cg = pixels[pixelIndex + AppMath.rgbChannelGreen];
          final int cb = pixels[pixelIndex + AppMath.rgbChannelBlue];
          final int ca = pixels[pixelIndex + AppMath.rgbChannelAlpha];
          if ((cr - targetR).abs() <= tolerance255 &&
              (cg - targetG).abs() <= tolerance255 &&
              (cb - targetB).abs() <= tolerance255 &&
              (ca - targetA).abs() <= tolerance255) {
            spanStack.push(scanX, rowAbove);
            scanX += AppMath.rgbChannelGreen;
            while (scanX <= right) {
              final int contiguousKey = rowAbove * width + scanX;
              if (visited[contiguousKey] == AppFloodFill.visitedMarker) {
                break;
              }
              final int contiguousPixelIndex = contiguousKey * bytesPerPixel;
              final int ccr = pixels[contiguousPixelIndex + AppMath.rgbChannelRed];
              final int ccg = pixels[contiguousPixelIndex + AppMath.rgbChannelGreen];
              final int ccb = pixels[contiguousPixelIndex + AppMath.rgbChannelBlue];
              final int cca = pixels[contiguousPixelIndex + AppMath.rgbChannelAlpha];
              if ((ccr - targetR).abs() > tolerance255 ||
                  (ccg - targetG).abs() > tolerance255 ||
                  (ccb - targetB).abs() > tolerance255 ||
                  (cca - targetA).abs() > tolerance255) {
                break;
              }
              scanX += AppMath.rgbChannelGreen;
            }
          }
        }
        scanX += AppMath.rgbChannelGreen;
      }
    }

    // Push spans from row below
    final int rowBelow = py + AppMath.rgbChannelGreen;
    if (rowBelow < height) {
      int scanX = left;
      while (scanX <= right) {
        final int key = rowBelow * width + scanX;
        if (visited[key] != AppFloodFill.visitedMarker) {
          final int pixelIndex = key * bytesPerPixel;
          final int cr = pixels[pixelIndex + AppMath.rgbChannelRed];
          final int cg = pixels[pixelIndex + AppMath.rgbChannelGreen];
          final int cb = pixels[pixelIndex + AppMath.rgbChannelBlue];
          final int ca = pixels[pixelIndex + AppMath.rgbChannelAlpha];
          if ((cr - targetR).abs() <= tolerance255 &&
              (cg - targetG).abs() <= tolerance255 &&
              (cb - targetB).abs() <= tolerance255 &&
              (ca - targetA).abs() <= tolerance255) {
            spanStack.push(scanX, rowBelow);
            scanX += AppMath.rgbChannelGreen;
            while (scanX <= right) {
              final int contiguousKey = rowBelow * width + scanX;
              if (visited[contiguousKey] == AppFloodFill.visitedMarker) {
                break;
              }
              final int contiguousPixelIndex = contiguousKey * bytesPerPixel;
              final int ccr = pixels[contiguousPixelIndex];
              final int ccg = pixels[contiguousPixelIndex + AppMath.rgbChannelGreen];
              final int ccb = pixels[contiguousPixelIndex + AppMath.rgbChannelBlue];
              final int cca = pixels[contiguousPixelIndex + AppMath.rgbChannelAlpha];
              if ((ccr - targetR).abs() > tolerance255 ||
                  (ccg - targetG).abs() > tolerance255 ||
                  (ccb - targetB).abs() > tolerance255 ||
                  (cca - targetA).abs() > tolerance255) {
                break;
              }
              scanX += AppMath.rgbChannelGreen;
            }
          }
        }
        scanX += AppMath.rgbChannelGreen;
      }
    }
  }

  if (!hasRegion) {
    return _FloodFillTaskOutput(
      runs: Int32List(0),
      left: AppMath.zero,
      top: AppMath.zero,
      hasRegion: false,
    );
  }

  return _FloodFillTaskOutput(
    runs: runBuffer.toTrimmedList(),
    left: minX,
    top: minY,
    hasRegion: true,
  );
}

/// Builds a normalized unified path from horizontal run triples.
Path _buildPathFromRuns({
  required final Int32List runs,
  required final int left,
  required final int top,
}) {
  const int batchSize = 16;
  Path unifiedPath = Path();
  final List<Path> batchedPaths = <Path>[];

  int i = AppMath.zero;
  while (i < runs.length) {
    final Path batchPath = Path();

    // Add up to batchSize rectangles to this batch
    final int batchEnd = (i + (batchSize * AppFloodFill.runStride)).clamp(
      AppMath.zero,
      runs.length,
    );

    while (i < batchEnd) {
      final int y = runs[i] - top;
      final int startX = runs[i + AppMath.rgbChannelGreen] - left;
      final int endX = runs[i + AppMath.rgbChannelBlue] - left;

      final int runWidth = endX - startX + AppMath.rgbChannelGreen;
      if (runWidth > AppMath.zero) {
        batchPath.addRect(
          Rect.fromLTWH(
            startX.toDouble(),
            y.toDouble(),
            runWidth.toDouble(),
            AppFloodFill.rowPixelHeight.toDouble(),
          ),
        );
      }

      i += AppFloodFill.runStride;
    }

    batchedPaths.add(batchPath);
  }

  // Sequentially union all batches
  if (batchedPaths.isNotEmpty) {
    unifiedPath = batchedPaths[AppMath.zero];
    for (int k = AppMath.one; k < batchedPaths.length; k++) {
      try {
        unifiedPath = Path.combine(
          PathOperation.union,
          unifiedPath,
          batchedPaths[k],
        );
      } catch (_) {
        // If combine fails, continue to next batch
        // This prevents crashes on edge cases with invalid path geometry
      }
    }
  }

  return unifiedPath;
}

/// Extracts a region from raw RGBA [pixels] using scan line flood fill.
Future<Region> extractRegionByColorEdgeAndOffsetFromPixels({
  required final Uint8List pixels,
  required final int width,
  required final int height,
  required final int x,
  required final int y,
  required final int tolerance,
}) async {
  final Region region = Region();

  if (x < AppMath.zero || x >= width || y < AppMath.zero || y >= height) {
    return region;
  }

  final _FloodFillTaskOutput output = await Isolate.run<_FloodFillTaskOutput>(
    () => _runFloodFillTask(
      _FloodFillTaskInput(
        x: x,
        y: y,
        width: width,
        height: height,
        tolerance: tolerance,
        pixelData: TransferableTypedData.fromList(<Uint8List>[pixels]),
      ),
    ),
  );

  if (!output.hasRegion || output.runs.isEmpty) {
    return region;
  }

  region.left = output.left.toDouble();
  region.top = output.top.toDouble();
  region.path = _buildPathFromRuns(
    runs: output.runs,
    left: output.left,
    top: output.top,
  );

  return region;
}
