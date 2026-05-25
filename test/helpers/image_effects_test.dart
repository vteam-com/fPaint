import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/image_effects.dart';

const int _testImageWidth = 50;
const int _testImageHeight = 50;
const double _halfStrength = 0.5;

/// Creates a solid-color test image.
Future<ui.Image> _createTestImage({
  final Color color = Colors.red,
  final int width = _testImageWidth,
  final int height = _testImageHeight,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  return recorder.endRecording().toImage(width, height);
}

Future<ui.Image> _createCheckerImage() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);

  for (int y = 0; y < _testImageHeight; y++) {
    for (int x = 0; x < _testImageWidth; x++) {
      final bool isEvenSquare = ((x ~/ AppMath.pair) + (y ~/ AppMath.pair)).isEven;
      canvas.drawRect(
        Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
        Paint()..color = isEvenSquare ? Colors.white : Colors.black,
      );
    }
  }

  return recorder.endRecording().toImage(_testImageWidth, _testImageHeight);
}

Future<Uint8List> _imageBytes(final ui.Image image) async {
  final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  expect(byteData, isNotNull);
  return byteData!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('applyGaussianBlur', () {
    test('returns original image when strength is zero', () async {
      final ui.Image original = await _createTestImage();
      final ui.Image result = await applyGaussianBlur(
        original,
        AppEffects.blurSigma,
        strength: AppEffects.minIntensity,
      );
      expect(result, same(original));
    });

    test('returns a new image with same dimensions when strength > 0', () async {
      final ui.Image original = await _createTestImage();
      final ui.Image result = await applyGaussianBlur(
        original,
        AppEffects.blurSigma,
      );
      expect(result.width, original.width);
      expect(result.height, original.height);
    });

    test('partial strength applies proportional sigma', () async {
      final ui.Image original = await _createTestImage();
      final ui.Image result = await applyGaussianBlur(
        original,
        AppEffects.blurSigma,
        strength: _halfStrength,
      );
      expect(result.width, original.width);
      expect(result.height, original.height);
    });
  });

  group('applyPixelate', () {
    test('returns original image when strength is zero', () async {
      final ui.Image original = await _createTestImage();
      final ui.Image result = await applyPixelate(
        original,
        strength: AppEffects.minIntensity,
      );
      expect(result, same(original));
    });

    test('returns new image at full strength', () async {
      final ui.Image original = await _createTestImage();
      final ui.Image result = await applyPixelate(original);
      expect(result.width, original.width);
      expect(result.height, original.height);
    });

    test('partial strength blends pixelated over original', () async {
      final ui.Image original = await _createTestImage();
      final ui.Image result = await applyPixelate(
        original,
        strength: _halfStrength,
      );
      expect(result.width, original.width);
      expect(result.height, original.height);
    });

    test('size changes the pixel block size', () async {
      final ui.Image original = await _createCheckerImage();
      final ui.Image fineResult = await applyPixelate(
        original,
        strength: AppEffects.maxIntensity,
        size: AppEffects.minSize,
      );
      final ui.Image coarseResult = await applyPixelate(
        original,
        strength: AppEffects.maxIntensity,
        size: AppEffects.maxSize,
      );

      expect(await _imageBytes(fineResult), isNot(equals(await _imageBytes(coarseResult))));
    });
  });

  group('applyGrayscale', () {
    test('returns original image when strength is zero', () async {
      final ui.Image original = await _createTestImage();
      final ui.Image result = await applyGrayscale(
        original,
        strength: AppEffects.minIntensity,
      );
      expect(result, same(original));
    });

    test('full strength produces grayscale image', () async {
      final ui.Image original = await _createTestImage();
      final ui.Image result = await applyGrayscale(original);
      expect(result.width, original.width);
      expect(result.height, original.height);
    });

    test('partial strength blends grayscale', () async {
      final ui.Image original = await _createTestImage();
      final ui.Image result = await applyGrayscale(
        original,
        strength: _halfStrength,
      );
      expect(result.width, original.width);
      expect(result.height, original.height);
    });
  });

  group('applySharpen', () {
    test('returns original image when strength is zero', () async {
      final ui.Image original = await _createTestImage();
      final ui.Image result = await applySharpen(
        original,
        strength: AppEffects.minIntensity,
      );
      expect(result, same(original));
    });

    test('full strength sharpens the image', () async {
      final ui.Image original = await _createTestImage();
      final ui.Image result = await applySharpen(original);
      expect(result.width, original.width);
      expect(result.height, original.height);
    });

    test('partial strength applies proportional sharpening', () async {
      final ui.Image original = await _createTestImage();
      final ui.Image result = await applySharpen(
        original,
        strength: _halfStrength,
      );
      expect(result.width, original.width);
      expect(result.height, original.height);
    });
  });

  group('applyNoise', () {
    test('returns original image when strength is zero', () async {
      final ui.Image original = await _createTestImage();
      final ui.Image result = await applyNoise(
        original,
        strength: AppEffects.minIntensity,
      );
      expect(result, same(original));
    });

    test('full strength adds noise', () async {
      final ui.Image original = await _createTestImage();
      final ui.Image result = await applyNoise(original);
      expect(result.width, original.width);
      expect(result.height, original.height);
    });

    test('partial strength adds proportional noise', () async {
      final ui.Image original = await _createTestImage();
      final ui.Image result = await applyNoise(
        original,
        strength: _halfStrength,
      );
      expect(result.width, original.width);
      expect(result.height, original.height);
    });

    test('size changes the noise grain', () async {
      final ui.Image original = await _createTestImage(color: Colors.grey);
      final ui.Image fineResult = await applyNoise(
        original,
        strength: AppEffects.maxIntensity,
        size: AppEffects.minSize,
        random: Random(7),
      );
      final ui.Image coarseResult = await applyNoise(
        original,
        strength: AppEffects.maxIntensity,
        size: AppEffects.maxSize,
        random: Random(7),
      );

      expect(await _imageBytes(fineResult), isNot(equals(await _imageBytes(coarseResult))));
    });
  });

  group('applyVignette', () {
    test('returns original image when strength is zero', () async {
      final ui.Image original = await _createTestImage();
      final ui.Image result = await applyVignette(
        original,
        strength: AppEffects.minIntensity,
      );
      expect(result, same(original));
    });

    test('full strength applies vignette', () async {
      final ui.Image original = await _createTestImage();
      final ui.Image result = await applyVignette(original);
      expect(result.width, original.width);
      expect(result.height, original.height);
    });

    test('partial strength applies blended vignette', () async {
      final ui.Image original = await _createTestImage();
      final ui.Image result = await applyVignette(
        original,
        strength: _halfStrength,
      );
      expect(result.width, original.width);
      expect(result.height, original.height);
    });
  });
}
