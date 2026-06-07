import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/smudge_helper.dart';

const int _testWidth = 12;
const int _testHeight = 4;

Future<ui.Image> _createSplitImage() {
  return renderCanvasImage(
    width: _testWidth,
    height: _testHeight,
    draw: (final ui.Canvas canvas) {
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

Future<ui.Image> _resultToImage(final PixelBrushSegmentResult result) {
  return imageFromPixels(result.pixels, result.width, result.height);
}

Future<Color> _readPixel(
  final ui.Image image,
  final int x,
  final int y,
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

Future<Uint8List> _imagePixels(final ui.Image source) async {
  final Uint8List? pixels = await extractImagePixels(
    source,
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  expect(pixels, isNotNull);
  return pixels!;
}

void main() {
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
      draw: (final ui.Canvas canvas) {
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

  test('rasterizePixelBrushSegment returns null for a single point', () async {
    final ui.Image source = await _createSplitImage();

    final PixelBrushSegmentResult? result = await rasterizePixelBrushSegment(
      livePixels: await _imagePixels(source),
      imageWidth: _testWidth,
      imageHeight: _testHeight,
      segmentPoints: const <Offset>[Offset(4, 2)],
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
    // because the blur kernel mixes in neighbouring red pixels.
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
}
