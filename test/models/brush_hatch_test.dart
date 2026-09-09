import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/brush_hatch.dart';
import 'package:fpaint/models/hatch_pattern.dart';

int _alphaAt(Uint8List pixels, int size, int x, int y) =>
    pixels[(y * size + x) * AppMath.bytesPerPixel + AppMath.rgbaAlphaOffset];

void main() {
  group('BrushHatch.buildTilePixels', () {
    test('a plain tile has one opaque horizontal line and transparent gaps', () {
      const HatchTileKey key = (spacing: 8, lineWidth: 2, crossed: false);
      final Uint8List pixels = BrushHatch.buildTilePixels(key);
      expect(pixels.length, 8 * 8 * AppMath.bytesPerPixel);

      // The 2px line is centred: rows 3 and 4 are fully covered.
      for (int x = 0; x < 8; x++) {
        expect(_alphaAt(pixels, 8, x, 3), AppLimits.rgbChannelMax);
        expect(_alphaAt(pixels, 8, x, 4), AppLimits.rgbChannelMax);
        expect(_alphaAt(pixels, 8, x, 0), 0);
        expect(_alphaAt(pixels, 8, x, 7), 0);
      }
      // Line texels are white so a srcIn tint gives them the brush colour.
      expect(pixels[(3 * 8) * AppMath.bytesPerPixel + AppMath.rgbaRedOffset], AppLimits.rgbChannelMax);
    });

    test('an odd line width anti-aliases its half-covered rows', () {
      const HatchTileKey key = (spacing: 8, lineWidth: 1, crossed: false);
      final Uint8List pixels = BrushHatch.buildTilePixels(key);
      // Band is [3.5, 4.5]: rows 3 and 4 are each half covered.
      expect(_alphaAt(pixels, 8, 0, 3), (AppLimits.rgbChannelMax * AppVisual.half).round());
      expect(_alphaAt(pixels, 8, 0, 4), (AppLimits.rgbChannelMax * AppVisual.half).round());
      expect(_alphaAt(pixels, 8, 0, 2), 0);
      expect(_alphaAt(pixels, 8, 0, 5), 0);
    });

    test('a crossed tile adds a vertical line without over-darkening the crossing', () {
      const HatchTileKey key = (spacing: 8, lineWidth: 2, crossed: true);
      final Uint8List pixels = BrushHatch.buildTilePixels(key);
      // Vertical line occupies columns 3 and 4 on a gap row.
      expect(_alphaAt(pixels, 8, 3, 0), AppLimits.rgbChannelMax);
      expect(_alphaAt(pixels, 8, 4, 0), AppLimits.rgbChannelMax);
      expect(_alphaAt(pixels, 8, 0, 0), 0);
      // The crossing stays exactly opaque (union, not sum).
      expect(_alphaAt(pixels, 8, 3, 3), AppLimits.rgbChannelMax);
    });
  });

  group('BrushHatch cache', () {
    test('keyFor ignores the angle and clamps the line width to the spacing', () {
      const HatchPattern a = HatchPattern(angleDegrees: 10, spacing: 6, lineWidth: 2);
      const HatchPattern b = HatchPattern(angleDegrees: 170, spacing: 6, lineWidth: 2);
      expect(BrushHatch.keyFor(a), BrushHatch.keyFor(b));
      expect(BrushHatch.keyFor(const HatchPattern(spacing: 4, lineWidth: 99)).lineWidth, 3);
      expect(BrushHatch.keyFor(a.copyWith(crossed: true)), isNot(BrushHatch.keyFor(a)));
    });

    test('shaderFor is null before prewarm and a rotated shader afterwards', () async {
      const HatchPattern pattern = HatchPattern(angleDegrees: 30, spacing: 5, lineWidth: 1);
      expect(BrushHatch.instance.tileFor(pattern), isNull);
      expect(BrushHatch.instance.shaderFor(pattern), isNull);

      // Concurrent prewarms share one generation.
      await Future.wait(<Future<void>>[
        BrushHatch.instance.prewarm(pattern),
        BrushHatch.instance.prewarm(pattern),
      ]);
      final ui.Image? tile = BrushHatch.instance.tileFor(pattern);
      expect(tile, isNotNull);
      expect(tile!.width, 5);
      expect(tile.height, 5);
      expect(BrushHatch.instance.shaderFor(pattern), isA<ui.ImageShader>());
      // A second prewarm of a cached key completes synchronously.
      await BrushHatch.instance.prewarm(pattern);
      expect(identical(BrushHatch.instance.tileFor(pattern), tile), isTrue);
    });
  });
}
