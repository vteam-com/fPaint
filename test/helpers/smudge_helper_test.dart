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

Future<ui.Image> _applyResultToSource(
  final ui.Image source,
  final SmudgeStrokeRasterResult result,
) {
  return renderCanvasImage(
    width: source.width,
    height: source.height,
    draw: (final ui.Canvas canvas) {
      canvas.drawImage(source, Offset.zero, Paint());
      canvas.drawImage(result.image, result.bounds.topLeft, Paint());
    },
  );
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

void main() {
  test('rasterizeSmudgeStroke moves sampled color along the stroke', () async {
    final ui.Image source = await _createSplitImage();

    final SmudgeStrokeRasterResult? result = await rasterizeSmudgeStroke(
      sourceImage: source,
      strokePoints: const <Offset>[
        Offset(4, 2),
        Offset(8, 2),
      ],
      brushSize: 4,
    );

    expect(result, isNotNull);

    final ui.Image output = await _applyResultToSource(source, result!);
    final Color smeared = await _readPixel(output, 7, 2);
    final int smearedRed = (smeared.r * AppLimits.rgbChannelMax).round();
    final int smearedBlue = (smeared.b * AppLimits.rgbChannelMax).round();

    expect(smearedRed, greaterThan(AppMath.zero));
    expect(smearedBlue, lessThan(AppLimits.rgbChannelMax));
  });

  test('rasterizeSmudgeStroke respects the clip path', () async {
    final ui.Image source = await _createSplitImage();
    final ui.Path clipPath = ui.Path()..addRect(Rect.fromLTWH(0, 0, 8, _testHeight.toDouble()));

    final SmudgeStrokeRasterResult? result = await rasterizeSmudgeStroke(
      sourceImage: source,
      strokePoints: const <Offset>[
        Offset(4, 2),
        Offset(10, 2),
      ],
      brushSize: 4,
      clipPath: clipPath,
    );

    expect(result, isNotNull);
    expect(result!.bounds.right, lessThanOrEqualTo(8.0));

    final ui.Image output = await _applyResultToSource(source, result);
    final Color outsideClip = await _readPixel(output, 10, 2);

    expect(outsideClip, const Color(0xFF0000FF));
  });

  test('rasterizeSmudgeStroke returns null for a single point', () async {
    final ui.Image source = await _createSplitImage();

    final SmudgeStrokeRasterResult? result = await rasterizeSmudgeStroke(
      sourceImage: source,
      strokePoints: const <Offset>[Offset(4, 2)],
      brushSize: 4,
    );

    expect(result, isNull);
  });
}
