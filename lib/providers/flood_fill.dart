// ignore: fcheck_one_class_per_file
import 'dart:collection';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
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

/// Immutable run interval for one raster row.
class _RunSegment {
  const _RunSegment({
    required this.startX,
    required this.endXExclusive,
  });

  final int startX;
  final int endXExclusive;
}

/// Integer grid point used while tracing flood-fill contours.
class _GridPoint {
  const _GridPoint(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(final Object other) {
    return other is _GridPoint && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);
}

/// Directed boundary segment for one contour edge.
class _BoundarySegment {
  const _BoundarySegment({
    required this.start,
    required this.end,
  });

  final _GridPoint start;
  final _GridPoint end;
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

/// Builds a normalized contour path from horizontal run triples.
Path _buildPathFromRuns({
  required final Int32List runs,
  required final int left,
  required final int top,
}) {
  final SplayTreeMap<int, List<_RunSegment>> groupedRuns = _groupRunsByRow(runs);
  final List<_BoundarySegment> boundarySegments = _buildBoundarySegments(groupedRuns);
  return _traceBoundaryPath(
    segments: boundarySegments,
    left: left,
    top: top,
  );
}

/// Groups flood-fill runs by row and normalizes them into sorted intervals.
SplayTreeMap<int, List<_RunSegment>> _groupRunsByRow(final Int32List runs) {
  final SplayTreeMap<int, List<_RunSegment>> groupedRuns = SplayTreeMap<int, List<_RunSegment>>();

  int i = AppMath.zero;
  while (i < runs.length) {
    final int y = runs[i];
    final int startX = runs[i + AppMath.rgbChannelGreen];
    final int endXExclusive = runs[i + AppMath.rgbChannelBlue] + AppMath.one;
    groupedRuns
        .putIfAbsent(y, () => <_RunSegment>[])
        .add(
          _RunSegment(
            startX: startX,
            endXExclusive: endXExclusive,
          ),
        );
    i += AppFloodFill.runStride;
  }

  for (final MapEntry<int, List<_RunSegment>> entry in groupedRuns.entries) {
    entry.value.sort((final _RunSegment a, final _RunSegment b) {
      final int startCompare = a.startX.compareTo(b.startX);
      if (startCompare != AppMath.zero) {
        return startCompare;
      }
      return a.endXExclusive.compareTo(b.endXExclusive);
    });
    final List<_RunSegment> normalizedRuns = _normalizeRowRuns(entry.value);
    entry.value
      ..clear()
      ..addAll(normalizedRuns);
  }

  return groupedRuns;
}

/// Merges overlapping or touching row intervals into maximal runs.
List<_RunSegment> _normalizeRowRuns(final List<_RunSegment> sortedRuns) {
  if (sortedRuns.isEmpty) {
    return const <_RunSegment>[];
  }

  final List<_RunSegment> normalizedRuns = <_RunSegment>[];
  _RunSegment currentRun = sortedRuns.first;
  for (final _RunSegment run in sortedRuns.skip(AppMath.one)) {
    if (run.startX <= currentRun.endXExclusive) {
      currentRun = _RunSegment(
        startX: currentRun.startX,
        endXExclusive: currentRun.endXExclusive >= run.endXExclusive ? currentRun.endXExclusive : run.endXExclusive,
      );
      continue;
    }

    normalizedRuns.add(currentRun);
    currentRun = run;
  }
  normalizedRuns.add(currentRun);
  return normalizedRuns;
}

/// Builds directed contour segments without invoking path unions.
List<_BoundarySegment> _buildBoundarySegments(
  final SplayTreeMap<int, List<_RunSegment>> groupedRuns,
) {
  final List<_BoundarySegment> segments = <_BoundarySegment>[];
  Map<int, int> activeLeftEdges = <int, int>{};
  Map<int, int> activeRightEdges = <int, int>{};
  List<_RunSegment> previousRuns = const <_RunSegment>[];
  int previousY = AppMath.zero;
  bool hasPreviousRow = false;

  for (final MapEntry<int, List<_RunSegment>> entry in groupedRuns.entries) {
    final int currentY = entry.key;
    final List<_RunSegment> currentRuns = entry.value;
    final bool isConsecutiveRow = hasPreviousRow && currentY == previousY + AppMath.one;

    if (!hasPreviousRow) {
      _emitExposedHorizontalSegments(
        baseRuns: currentRuns,
        overlapRuns: const <_RunSegment>[],
        y: currentY,
        isTopBoundary: true,
        segments: segments,
      );
    } else if (isConsecutiveRow) {
      _emitExposedHorizontalSegments(
        baseRuns: previousRuns,
        overlapRuns: currentRuns,
        y: previousY + AppMath.one,
        isTopBoundary: false,
        segments: segments,
      );
      _emitExposedHorizontalSegments(
        baseRuns: currentRuns,
        overlapRuns: previousRuns,
        y: currentY,
        isTopBoundary: true,
        segments: segments,
      );
    } else {
      _emitExposedHorizontalSegments(
        baseRuns: previousRuns,
        overlapRuns: const <_RunSegment>[],
        y: previousY + AppMath.one,
        isTopBoundary: false,
        segments: segments,
      );
      _closeActiveVerticalEdges(
        activeEdges: activeLeftEdges,
        endYExclusive: previousY + AppMath.one,
        isLeftBoundary: true,
        segments: segments,
      );
      _closeActiveVerticalEdges(
        activeEdges: activeRightEdges,
        endYExclusive: previousY + AppMath.one,
        isLeftBoundary: false,
        segments: segments,
      );
      _emitExposedHorizontalSegments(
        baseRuns: currentRuns,
        overlapRuns: const <_RunSegment>[],
        y: currentY,
        isTopBoundary: true,
        segments: segments,
      );
    }

    activeLeftEdges = _advanceVerticalEdges(
      currentRuns: currentRuns,
      activeEdges: activeLeftEdges,
      currentY: currentY,
      previousY: previousY,
      isConsecutiveRow: isConsecutiveRow,
      isLeftBoundary: true,
      segments: segments,
    );
    activeRightEdges = _advanceVerticalEdges(
      currentRuns: currentRuns,
      activeEdges: activeRightEdges,
      currentY: currentY,
      previousY: previousY,
      isConsecutiveRow: isConsecutiveRow,
      isLeftBoundary: false,
      segments: segments,
    );

    previousRuns = currentRuns;
    previousY = currentY;
    hasPreviousRow = true;
  }

  if (!hasPreviousRow) {
    return segments;
  }

  _emitExposedHorizontalSegments(
    baseRuns: previousRuns,
    overlapRuns: const <_RunSegment>[],
    y: previousY + AppMath.one,
    isTopBoundary: false,
    segments: segments,
  );
  _closeActiveVerticalEdges(
    activeEdges: activeLeftEdges,
    endYExclusive: previousY + AppMath.one,
    isLeftBoundary: true,
    segments: segments,
  );
  _closeActiveVerticalEdges(
    activeEdges: activeRightEdges,
    endYExclusive: previousY + AppMath.one,
    isLeftBoundary: false,
    segments: segments,
  );
  return segments;
}

/// Emits the exposed horizontal edges for [baseRuns] after subtracting [overlapRuns].
void _emitExposedHorizontalSegments({
  required final List<_RunSegment> baseRuns,
  required final List<_RunSegment> overlapRuns,
  required final int y,
  required final bool isTopBoundary,
  required final List<_BoundarySegment> segments,
}) {
  int overlapIndex = AppMath.zero;

  for (final _RunSegment baseRun in baseRuns) {
    int cursor = baseRun.startX;
    while (overlapIndex < overlapRuns.length && overlapRuns[overlapIndex].endXExclusive <= cursor) {
      overlapIndex += AppMath.one;
    }

    int scanIndex = overlapIndex;
    while (scanIndex < overlapRuns.length && overlapRuns[scanIndex].startX < baseRun.endXExclusive) {
      final _RunSegment overlapRun = overlapRuns[scanIndex];
      if (overlapRun.startX > cursor) {
        _addHorizontalBoundarySegment(
          startX: cursor,
          endXExclusive: overlapRun.startX,
          y: y,
          isTopBoundary: isTopBoundary,
          segments: segments,
        );
      }
      if (overlapRun.endXExclusive > cursor) {
        cursor = overlapRun.endXExclusive;
      }
      if (cursor >= baseRun.endXExclusive) {
        break;
      }
      scanIndex += AppMath.one;
    }

    if (cursor < baseRun.endXExclusive) {
      _addHorizontalBoundarySegment(
        startX: cursor,
        endXExclusive: baseRun.endXExclusive,
        y: y,
        isTopBoundary: isTopBoundary,
        segments: segments,
      );
    }
  }
}

/// Adds one oriented horizontal contour segment.
void _addHorizontalBoundarySegment({
  required final int startX,
  required final int endXExclusive,
  required final int y,
  required final bool isTopBoundary,
  required final List<_BoundarySegment> segments,
}) {
  if (startX >= endXExclusive) {
    return;
  }

  final _GridPoint start = isTopBoundary ? _GridPoint(startX, y) : _GridPoint(endXExclusive, y);
  final _GridPoint end = isTopBoundary ? _GridPoint(endXExclusive, y) : _GridPoint(startX, y);
  segments.add(_BoundarySegment(start: start, end: end));
}

/// Advances one set of vertical contour edges by a single row.
Map<int, int> _advanceVerticalEdges({
  required final List<_RunSegment> currentRuns,
  required final Map<int, int> activeEdges,
  required final int currentY,
  required final int previousY,
  required final bool isConsecutiveRow,
  required final bool isLeftBoundary,
  required final List<_BoundarySegment> segments,
}) {
  final Map<int, int> nextActiveEdges = <int, int>{};

  for (final _RunSegment run in currentRuns) {
    final int boundaryX = isLeftBoundary ? run.startX : run.endXExclusive;
    final int? existingStartY = isConsecutiveRow ? activeEdges.remove(boundaryX) : null;
    nextActiveEdges[boundaryX] = existingStartY ?? currentY;
  }

  if (activeEdges.isEmpty) {
    return nextActiveEdges;
  }

  _closeActiveVerticalEdges(
    activeEdges: activeEdges,
    endYExclusive: previousY + AppMath.one,
    isLeftBoundary: isLeftBoundary,
    segments: segments,
  );
  return nextActiveEdges;
}

/// Flushes the still-open vertical contour edges into boundary segments.
void _closeActiveVerticalEdges({
  required final Map<int, int> activeEdges,
  required final int endYExclusive,
  required final bool isLeftBoundary,
  required final List<_BoundarySegment> segments,
}) {
  for (final MapEntry<int, int> entry in activeEdges.entries) {
    final _GridPoint start = isLeftBoundary ? _GridPoint(entry.key, endYExclusive) : _GridPoint(entry.key, entry.value);
    final _GridPoint end = isLeftBoundary ? _GridPoint(entry.key, entry.value) : _GridPoint(entry.key, endYExclusive);
    segments.add(_BoundarySegment(start: start, end: end));
  }
}

/// Traces closed contour loops from the directed boundary segments.
Path _traceBoundaryPath({
  required final List<_BoundarySegment> segments,
  required final int left,
  required final int top,
}) {
  final Path path = Path();
  if (segments.isEmpty) {
    return path;
  }

  final Map<_GridPoint, List<int>> outgoingByStart = <_GridPoint, List<int>>{};
  for (int i = AppMath.zero; i < segments.length; i += AppMath.one) {
    outgoingByStart.putIfAbsent(segments[i].start, () => <int>[]).add(i);
  }

  final List<bool> usedSegments = List<bool>.filled(segments.length, false);
  for (int i = AppMath.zero; i < segments.length; i += AppMath.one) {
    if (usedSegments[i]) {
      continue;
    }

    final _BoundarySegment startSegment = segments[i];
    path.moveTo(
      (startSegment.start.x - left).toDouble(),
      (startSegment.start.y - top).toDouble(),
    );

    int currentIndex = i;
    while (true) {
      final _BoundarySegment segment = segments[currentIndex];
      usedSegments[currentIndex] = true;
      path.lineTo(
        (segment.end.x - left).toDouble(),
        (segment.end.y - top).toDouble(),
      );

      if (segment.end == startSegment.start) {
        path.close();
        break;
      }

      final int? nextIndex = _findNextUnusedSegment(
        candidateIndices: outgoingByStart[segment.end],
        usedSegments: usedSegments,
      );
      if (nextIndex == null) {
        path.close();
        break;
      }
      currentIndex = nextIndex;
    }
  }

  return path;
}

/// Returns the next unconsumed segment that starts at the current contour point.
int? _findNextUnusedSegment({
  required final List<int>? candidateIndices,
  required final List<bool> usedSegments,
}) {
  if (candidateIndices == null) {
    return null;
  }

  for (final int index in candidateIndices) {
    if (!usedSegments[index]) {
      return index;
    }
  }
  return null;
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

  final _FloodFillTaskInput taskInput = _FloodFillTaskInput(
    x: x,
    y: y,
    width: width,
    height: height,
    tolerance: tolerance,
    pixelData: TransferableTypedData.fromList(<Uint8List>[pixels]),
  );

  final _FloodFillTaskOutput output;
  if (kIsWeb) {
    output = _runFloodFillTask(taskInput);
  } else {
    output = await Isolate.run<_FloodFillTaskOutput>(
      () => _runFloodFillTask(taskInput),
    );
  }

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
