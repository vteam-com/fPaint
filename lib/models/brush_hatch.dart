import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/hatch_pattern.dart';

/// Cache key for one hatch tile: everything that changes the tile's pixels.
/// The angle is *not* part of it — rotation is applied by the shader matrix.
typedef HatchTileKey = ({int spacing, int lineWidth, bool crossed});

/// Lazily-generated, cached line tiles backing the hatch / cross-hatch brush
/// style and fill pattern.
///
/// Each tile is a `spacing × spacing` square holding one horizontal line (and,
/// when crossed, one vertical line) as white texels whose alpha is the line
/// coverage. The renderer samples it as a repeating [ui.ImageShader] in canvas
/// space, rotated by the pattern angle, and tints it with the brush colour, so
/// the hatch reads as a stationary line field that strokes and fills reveal.
///
/// Tiles are tiny (at most `maxSpacing²` texels) and never evicted: a committed
/// action re-renders through the same cache on undo replay and export, and a
/// missing tile would silently bake as a solid stroke. Generation is async
/// ([ui.decodeImageFromPixels]); until [prewarm] completes the style falls back
/// to a solid stroke, so callers prewarm whenever the settings change.
class BrushHatch {
  BrushHatch._();

  /// The shared instance.
  static final BrushHatch instance = BrushHatch._();

  final Map<HatchTileKey, ui.Image> _tiles = <HatchTileKey, ui.Image>{};
  final Map<HatchTileKey, Future<void>> _pending = <HatchTileKey, Future<void>>{};

  /// The cache key for [pattern].
  static HatchTileKey keyFor(HatchPattern pattern) => (
    spacing: pattern.spacing,
    lineWidth: pattern.effectiveLineWidth,
    crossed: pattern.crossed,
  );

  /// The cached tile for [pattern], or null until [prewarm] has completed.
  ui.Image? tileFor(HatchPattern pattern) => _tiles[keyFor(pattern)];

  /// Generates the tile for [pattern] once. Idempotent and safe to call
  /// repeatedly; concurrent calls for the same key share one generation.
  Future<void> prewarm(HatchPattern pattern) {
    final HatchTileKey key = keyFor(pattern);
    if (_tiles.containsKey(key)) {
      return Future<void>.value();
    }
    return _pending.putIfAbsent(key, () => _generate(key));
  }

  /// Builds a canvas-space shader for [pattern], or null until its tile exists.
  ///
  /// The tile's horizontal line is rotated to the pattern angle; the tile
  /// repeats in both directions. Bilinear sampling keeps rotated lines smooth.
  ui.ImageShader? shaderFor(HatchPattern pattern) {
    final ui.Image? tile = tileFor(pattern);
    if (tile == null) {
      return null;
    }
    return ui.ImageShader(
      tile,
      TileMode.repeated,
      TileMode.repeated,
      Matrix4.rotationZ(pattern.angleRadians).storage,
      filterQuality: FilterQuality.low,
    );
  }

  Future<void> _generate(HatchTileKey key) async {
    final Uint8List pixels = buildTilePixels(key);
    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, key.spacing, key.spacing, ui.PixelFormat.rgba8888, completer.complete);
    _tiles[key] = await completer.future;
    _pending.remove(key);
  }

  /// Rasterises the tile for [key] as straight RGBA: white texels whose alpha is
  /// the line coverage. The horizontal line is centred vertically; the crossed
  /// vertical line is centred horizontally; where both pass, coverages are
  /// combined as a union so the intersection does not over-darken.
  static Uint8List buildTilePixels(HatchTileKey key) {
    final int size = key.spacing;
    final int texelCount = size * size;
    final Uint8List pixels = Uint8List(texelCount * AppMath.bytesPerPixel);
    final double lineHalfWidth = key.lineWidth * AppVisual.half;
    final double lineCenter = size * AppVisual.half;
    for (int y = AppMath.zero; y < size; y++) {
      final double rowCoverage = _coverage(y, lineCenter, lineHalfWidth);
      for (int x = AppMath.zero; x < size; x++) {
        final double columnCoverage = key.crossed ? _coverage(x, lineCenter, lineHalfWidth) : AppMath.zero.toDouble();
        final double coverage = rowCoverage + columnCoverage - rowCoverage * columnCoverage;
        final int offset = (y * size + x) * AppMath.bytesPerPixel;
        pixels[offset + AppMath.rgbaRedOffset] = AppLimits.rgbChannelMax;
        pixels[offset + AppMath.rgbaGreenOffset] = AppLimits.rgbChannelMax;
        pixels[offset + AppMath.rgbaBlueOffset] = AppLimits.rgbChannelMax;
        pixels[offset + AppMath.rgbaAlphaOffset] = (coverage * AppLimits.rgbChannelMax).round();
      }
    }
    return pixels;
  }

  /// How much of the unit texel `[index, index + 1)` a line band centred on
  /// [center] with half-width [halfWidth] covers, in `[0, 1]`.
  static double _coverage(int index, double center, double halfWidth) {
    final double overlap =
        math.min(index + AppMath.one, center + halfWidth) - math.max(index.toDouble(), center - halfWidth);
    return overlap.clamp(AppMath.zero.toDouble(), AppVisual.full);
  }
}
