import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/smudge_helper.dart';
import 'package:material_ui/material_ui.dart';

const int _testWidth = 12;
const int _testHeight = 4;

Future<ui.Image> _createSplitImage() {
  return renderCanvasImage(
    width: _testWidth,
    height: _testHeight,
    draw: (ui.Canvas canvas) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, 6, _testHeight.toDouble()),
        Paint()..color = const Color(0xFFFF0000),
      );
      canvas.drawRect(
        Rect.fromLTWH(6, 0, 6, _testHeight.toDouble()),
        Paint()..color = const Color(0xFF0000FF),
      );
    },
  );
}

/// Builds a straight-RGBA buffer: left half (x < 6) opaque red, right half
/// fully transparent (0,0,0,0). Constructed pixel-exact (no canvas, no
/// anti-aliasing) so the red→transparent boundary is hard — anti-aliased edge
/// pixels keep full-strength colour with partial alpha and would mask the
/// regression this guards.
Uint8List _redLeftTransparentRightPixels() {
  final Uint8List pixels = Uint8List(_testWidth * _testHeight * AppMath.bytesPerPixel);
  const int boundaryX = 6;
  for (int y = 0; y < _testHeight; y++) {
    for (int x = 0; x < boundaryX; x++) {
      final int i = ((y * _testWidth) + x) * AppMath.bytesPerPixel;
      pixels[i + AppMath.rgbChannelRed] = AppLimits.rgbChannelMax;
      pixels[i + AppMath.rgbChannelAlpha] = AppLimits.rgbChannelMax;
    }
  }
  return pixels;
}

/// Builds a [size]×[size] opaque buffer of red/blue vertical stripes two columns
/// wide. A box-downsample-by-2 keeps the stripes' contrast (so a dab still finds
/// something to push), but the bilinear-upsample back smears every column toward
/// its neighbour — so a pixel that comes back bit-exact proves it bypassed the
/// LOD round-trip entirely.
Uint8List _verticalStripes(int size) {
  final Uint8List pixels = Uint8List(size * size * AppMath.bytesPerPixel);
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final int i = ((y * size) + x) * AppMath.bytesPerPixel;
      final bool red = (x ~/ 2).isEven;
      pixels[i + AppMath.rgbChannelRed] = red ? AppLimits.rgbChannelMax : AppMath.zero;
      pixels[i + AppMath.rgbChannelBlue] = red ? AppMath.zero : AppLimits.rgbChannelMax;
      pixels[i + AppMath.rgbChannelAlpha] = AppLimits.rgbChannelMax;
    }
  }
  return pixels;
}

Future<ui.Image> _resultToImage(PixelBrushSegmentResult result) {
  return imageFromPixelsDecode(result.pixels, result.width, result.height);
}

Future<Color> _readPixel(
  ui.Image image,
  int x,
  int y,
) async {
  final Uint8List? pixels = await extractImagePixels(
    image,
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  expect(pixels, isNotNull);
  final int index = ((y * image.width) + x) * AppMath.bytesPerPixel;
  return Color.fromARGB(
    pixels![index + AppMath.rgbChannelAlpha],
    pixels[index + AppMath.rgbChannelRed],
    pixels[index + AppMath.rgbChannelGreen],
    pixels[index + AppMath.rgbChannelBlue],
  );
}

Future<Uint8List> _imagePixels(ui.Image source) async {
  final Uint8List? pixels = await extractImagePixels(
    source,
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  expect(pixels, isNotNull);
  return pixels!;
}

void main() {
  test('resolvePixelBrushStepSpacing scales dab spacing with brush radius', () {
    // Small brushes are lower-bounded so fine strokes stay crisp.
    expect(resolvePixelBrushStepSpacing(0), AppInteraction.smudgeInputPointSpacing);

    // Large brushes scale spacing with the brush radius (radius * factor) rather
    // than a fixed cap: the old ~2px cap forced hundreds of full-disc dabs per
    // stroke and caused multi-second lag, so it was removed for performance.
    const double largeBrush = 100;
    final double expectedRadius = largeBrush * AppInteraction.smudgeBrushRadiusFactor;
    expect(
      resolvePixelBrushStepSpacing(largeBrush),
      expectedRadius * AppInteraction.smudgeStepSpacingFactor,
    );
  });

  test('rasterizePixelBrushSegment (smudge) moves sampled color along stroke', () async {
    final ui.Image source = await _createSplitImage();

    final PixelBrushSegmentResult? result = await rasterizePixelBrushSegment(
      livePixels: await _imagePixels(source),
      imageWidth: _testWidth,
      imageHeight: _testHeight,
      segmentPoints: const <Offset>[Offset(4, 2), Offset(8, 2)],
      brushSize: 4,
      mode: PixelBrushMode.smudge,
    );

    expect(result, isNotNull);
    final ui.Image output = await _resultToImage(result!);
    final Color smeared = await _readPixel(output, 7, 2);
    expect((smeared.r * AppLimits.rgbChannelMax).round(), greaterThan(AppMath.zero));
    expect((smeared.b * AppLimits.rgbChannelMax).round(), lessThan(AppLimits.rgbChannelMax));
  });

  test('rasterizePixelBrushSegment (smudge) respects clip mask', () async {
    final ui.Image source = await _createSplitImage();
    // Build a clip mask: white only for x < 8, so x=10 should remain unaffected.
    final ui.Path clipPath = ui.Path()..addRect(Rect.fromLTWH(0, 0, 8, _testHeight.toDouble()));
    final ui.Image maskImage = await renderCanvasImage(
      width: _testWidth,
      height: _testHeight,
      draw: (ui.Canvas canvas) {
        canvas.drawPath(clipPath, ui.Paint()..color = const Color(0xFFFFFFFF));
      },
    );
    final Uint8List clipMask = await _imagePixels(maskImage);

    final PixelBrushSegmentResult? result = await rasterizePixelBrushSegment(
      livePixels: await _imagePixels(source),
      imageWidth: _testWidth,
      imageHeight: _testHeight,
      segmentPoints: const <Offset>[Offset(4, 2), Offset(10, 2)],
      brushSize: 4,
      mode: PixelBrushMode.smudge,
      clipMask: clipMask,
    );

    expect(result, isNotNull);
    final ui.Image output = await _resultToImage(result!);
    final Color outsideClip = await _readPixel(output, 10, 2);
    expect(outsideClip, const Color(0xFF0000FF));
  });

  test('rasterizePixelBrushSegment (smudge) presses ink outward for a single point (tap)', () async {
    // A single tap has no drag direction, so smudge presses the ink radially
    // outward from the tap point (like pressing a stamp into wet paint). Tapping
    // the red/blue boundary pushes the centre's blue onto the neighbouring red,
    // so the red pixel just inside the disc is no longer pure red.
    final ui.Image source = await _createSplitImage();

    final PixelBrushSegmentResult? result = await rasterizePixelBrushSegment(
      livePixels: await _imagePixels(source),
      imageWidth: _testWidth,
      imageHeight: _testHeight,
      segmentPoints: const <Offset>[Offset(6, 2)],
      brushSize: 6,
      mode: PixelBrushMode.smudge,
      preferSynchronous: true,
    );

    expect(result, isNotNull);
    final ui.Image output = await _resultToImage(result!);
    final Color pushed = await _readPixel(output, 5, 2);
    expect(pushed, isNot(const Color(0xFFFF0000)));
  });

  test('rasterizePixelBrushSegment (blur) softens a single point (tap)', () async {
    // A single blur tap softens the spot in place; at the tapped red/blue
    // boundary the kernel mixes the two colours.
    final ui.Image source = await _createSplitImage();

    final PixelBrushSegmentResult? result = await rasterizePixelBrushSegment(
      livePixels: await _imagePixels(source),
      imageWidth: _testWidth,
      imageHeight: _testHeight,
      segmentPoints: const <Offset>[Offset(6, 2)],
      brushSize: 6,
      mode: PixelBrushMode.blur,
      preferSynchronous: true,
    );

    expect(result, isNotNull);
    final ui.Image output = await _resultToImage(result!);
    final Color boundary = await _readPixel(output, 6, 2);
    expect(boundary, isNot(const Color(0xFF0000FF)));
  });

  test('rasterizePixelBrushSegment (smudge) leaves pixels outside a large-brush dab untouched (no square)', () async {
    // Regression: a single-tap dab commits its whole rectangular footprint via
    // BlendMode.src, so pixels the dab did not touch must stay bit-exact — else
    // the untouched margin stamps a visible square. A large brush used to route
    // the tap through the LOD down/up-sample, which blurred that whole margin.
    const int size = 160;
    final Uint8List input = _verticalStripes(size);

    final PixelBrushSegmentResult? result = await rasterizePixelBrushSegment(
      livePixels: Uint8List.fromList(input),
      imageWidth: size,
      imageHeight: size,
      // radius 80 > smudgeComputeLodMinRadius (64): would trigger LOD for a drag.
      segmentPoints: const <Offset>[Offset(80, 80)],
      brushSize: 160,
      mode: PixelBrushMode.smudge,
      preferSynchronous: true,
    );

    expect(result, isNotNull);
    // A corner ~110 px from the centre — well outside the radius-80 disc.
    const int corner = ((2 * size) + 2) * AppMath.bytesPerPixel;
    expect(
      result!.pixels.sublist(corner, corner + AppMath.bytesPerPixel),
      input.sublist(corner, corner + AppMath.bytesPerPixel),
      reason: 'the dab must not alter pixels outside its disc',
    );
  });

  test('rasterizePixelBrushSegment returns null for an empty stroke', () async {
    final ui.Image source = await _createSplitImage();

    final PixelBrushSegmentResult? result = await rasterizePixelBrushSegment(
      livePixels: await _imagePixels(source),
      imageWidth: _testWidth,
      imageHeight: _testHeight,
      segmentPoints: const <Offset>[],
      brushSize: 4,
      mode: PixelBrushMode.smudge,
    );

    expect(result, isNull);
  });

  test('rasterizePixelBrushSegment (blur) reduces contrast at colour boundary', () async {
    final ui.Image source = await _createSplitImage();

    final PixelBrushSegmentResult? result = await rasterizePixelBrushSegment(
      livePixels: await _imagePixels(source),
      imageWidth: _testWidth,
      imageHeight: _testHeight,
      segmentPoints: const <Offset>[Offset(5, 2), Offset(7, 2)],
      brushSize: 6,
      mode: PixelBrushMode.blur,
    );

    expect(result, isNotNull);
    final ui.Image output = await _resultToImage(result!);
    // The pixel at the colour boundary (x=6) should no longer be pure blue
    // because the blur kernel mixes in neighboring red pixels.
    final Color boundary = await _readPixel(output, 6, 2);
    expect(boundary, isNot(const Color(0xFF0000FF)));
  });

  test('rasterizePixelBrushSegment intensity changes blur strength', () async {
    final ui.Image source = await _createSplitImage();
    final Uint8List sourcePixels = await _imagePixels(source);

    final PixelBrushSegmentResult? lowIntensityResult = await rasterizePixelBrushSegment(
      livePixels: Uint8List.fromList(sourcePixels),
      imageWidth: _testWidth,
      imageHeight: _testHeight,
      segmentPoints: const <Offset>[Offset(5, 2), Offset(7, 2)],
      brushSize: 6,
      intensity: 0.2,
      mode: PixelBrushMode.blur,
    );

    final PixelBrushSegmentResult? highIntensityResult = await rasterizePixelBrushSegment(
      livePixels: Uint8List.fromList(sourcePixels),
      imageWidth: _testWidth,
      imageHeight: _testHeight,
      segmentPoints: const <Offset>[Offset(5, 2), Offset(7, 2)],
      brushSize: 6,
      intensity: 1.0,
      mode: PixelBrushMode.blur,
    );

    expect(lowIntensityResult, isNotNull);
    expect(highIntensityResult, isNotNull);

    final Color lowBoundary = await _readPixel(await _resultToImage(lowIntensityResult!), 6, 2);
    final Color highBoundary = await _readPixel(await _resultToImage(highIntensityResult!), 6, 2);

    expect(highBoundary.r, greaterThan(lowBoundary.r));
    expect(highBoundary.b, lessThan(lowBoundary.b));
  });

  test('successive incremental smudge segments accumulate correctly', () async {
    final ui.Image source = await _createSplitImage();
    final Uint8List startPixels = await _imagePixels(source);

    // First segment: 4 → 6
    final PixelBrushSegmentResult? first = await rasterizePixelBrushSegment(
      livePixels: Uint8List.fromList(startPixels),
      imageWidth: _testWidth,
      imageHeight: _testHeight,
      segmentPoints: const <Offset>[Offset(4, 2), Offset(6, 2)],
      brushSize: 4,
      mode: PixelBrushMode.smudge,
    );
    expect(first, isNotNull);

    // Second segment: 6 → 8 built on the first result (incremental update).
    final PixelBrushSegmentResult? second = await rasterizePixelBrushSegment(
      livePixels: first!.pixels,
      imageWidth: _testWidth,
      imageHeight: _testHeight,
      segmentPoints: const <Offset>[Offset(6, 2), Offset(8, 2)],
      brushSize: 4,
      mode: PixelBrushMode.smudge,
    );
    expect(second, isNotNull);

    final ui.Image output = await _resultToImage(second!);
    final Color smeared = await _readPixel(output, 7, 2);
    expect((smeared.r * AppLimits.rgbChannelMax).round(), greaterThan(AppMath.zero));
  });

  test('rasterizePixelBrushSegment (blur) preserves hue across a transparent edge', () async {
    // Regression guard for premultiplied-alpha handling. Blurring a hard
    // red→transparent edge must not drag the red channel down toward the
    // (partial) alpha: a straight, non-premultiplied channel average mixes in
    // the undefined RGB of transparent neighbours and darkens the edge into a
    // halo. The alpha-weighted average keeps the un-premultiplied colour pure,
    // so the formerly-transparent boundary pixel stays saturated red while only
    // partially covered. (Fully-opaque blurs are unaffected: with every alpha
    // at max the alpha-weighted average reduces to the plain average.)
    final PixelBrushSegmentResult? result = await rasterizePixelBrushSegment(
      livePixels: _redLeftTransparentRightPixels(),
      imageWidth: _testWidth,
      imageHeight: _testHeight,
      segmentPoints: const <Offset>[Offset(6, 1), Offset(6, 3)],
      brushSize: 6,
      intensity: 1.0,
      mode: PixelBrushMode.blur,
    );

    expect(result, isNotNull);
    // Read the computed pixel straight from the result buffer (no ui.Image
    // round-trip) so the channel values stay exact. Pixel (6, 2) starts fully
    // transparent and sits at the blur centre, gaining colour only from its red
    // neighbours.
    final Uint8List out = result!.pixels;
    final int index = ((2 * result.width) + 6) * AppMath.bytesPerPixel;
    final int red = out[index + AppMath.rgbChannelRed];
    final int green = out[index + AppMath.rgbChannelGreen];
    final int blue = out[index + AppMath.rgbChannelBlue];
    final int alpha = out[index + AppMath.rgbChannelAlpha];

    // Partial coverage: the formerly-transparent pixel picks up some alpha but
    // is not fully opaque.
    expect(alpha, greaterThan(AppMath.zero));
    expect(alpha, lessThan(AppLimits.rgbChannelMax));
    // Hue stays red and saturated: un-premultiplied red is well above the
    // partial alpha. The straight (buggy) average yields red == alpha here.
    expect(red, greaterThan(alpha));
    expect(green, AppMath.zero);
    expect(blue, AppMath.zero);
  });

  test('large-brush LOD round-trip preserves colour across a transparent edge', () async {
    // Regression guard for the straight-RGBA bilinear upsample. A brush radius
    // above smudgeComputeLodMinRadius (64) routes the dab through the
    // downsample -> compute -> upsample LOD path. Interpolating all four
    // channels in straight space mixes the undefined RGB of transparent
    // neighbours into the rim and, worse, scales the colour down in step with
    // the alpha - so the smear's leading edge arrives washed pale instead of
    // saturated, reading as a light fringe. Premultiplied interpolation divides
    // the alpha back out and recovers the true colour.
    const int size = 160;
    final Uint8List pixels = Uint8List(size * size * AppMath.bytesPerPixel);
    // Left half opaque pure red; right half fully transparent but carrying
    // WHITE rgb - what a cleared/white-backed readback contains, and the exact
    // colour that used to bleed across the edge.
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final int i = ((y * size) + x) * AppMath.bytesPerPixel;
        pixels[i + AppMath.rgbChannelRed] = AppLimits.rgbChannelMax;
        if (x < size ~/ 2) {
          pixels[i + AppMath.rgbChannelAlpha] = AppLimits.rgbChannelMax;
        } else {
          pixels[i + AppMath.rgbChannelGreen] = AppLimits.rgbChannelMax;
          pixels[i + AppMath.rgbChannelBlue] = AppLimits.rgbChannelMax;
          pixels[i + AppMath.rgbChannelAlpha] = AppMath.zero;
        }
      }
    }

    // brushSize 140 -> radius 70, above the LOD threshold. The stroke drags red
    // rightward into the transparent half, leaving a partially-covered smear
    // front a little past x=112 rather than flooding the whole row.
    final PixelBrushSegmentResult? result = await rasterizePixelBrushSegment(
      livePixels: pixels,
      imageWidth: size,
      imageHeight: size,
      segmentPoints: const <Offset>[Offset(50, 80), Offset(90, 80)],
      brushSize: 140,
      intensity: 1.0,
      mode: PixelBrushMode.smudge,
      preferSynchronous: true,
    );

    expect(result, isNotNull);
    final Uint8List out = result!.pixels;

    // The smear front: partially covered, so alpha is well below opaque.
    const int frontX = 120;
    final int index = ((80 * size) + frontX) * AppMath.bytesPerPixel;
    final int red = out[index + AppMath.rgbChannelRed];
    final int green = out[index + AppMath.rgbChannelGreen];
    final int blue = out[index + AppMath.rgbChannelBlue];
    final int alpha = out[index + AppMath.rgbChannelAlpha];

    expect(alpha, greaterThan(AppMath.zero), reason: 'the smear reaches this pixel');
    expect(alpha, lessThan(AppLimits.rgbChannelMax), reason: 'only partially covered');
    // The smeared ink is pure red, so its straight colour must stay saturated
    // regardless of how little coverage it has. Straight-space interpolation
    // scaled red down to equal the alpha (64/64); premultiplied keeps it at max.
    expect(
      red,
      greaterThan(alpha * 2),
      reason: 'straight interpolation washes the smear front pale (red == alpha)',
    );
    expect(green, AppMath.zero, reason: 'no white bleed into green');
    expect(blue, AppMath.zero, reason: 'no white bleed into blue');
  });
}
