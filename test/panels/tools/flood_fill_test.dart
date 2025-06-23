import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/panels/tools/flood_fill.dart';

const int testImageSize = 5;

Future<ui.Image> createInputImage() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = Canvas(recorder);
  final ui.Paint paint = Paint()..color = Colors.white;
  canvas.drawRect(
    const Rect.fromLTWH(1, 1, testImageSize - 2, testImageSize - 2),
    paint,
  );
  final ui.Picture picture = recorder.endRecording();
  return await picture.toImage(testImageSize, testImageSize);
}

void main() {
  group('Flood Fill Tests', () {
    test('Input image', () async {
      final ui.Image inputImage = await createInputImage();
      expect(inputImage.width, 5);
      expect(inputImage.height, 5);
      expect(
        await imageToListToString(inputImage),
        <String>[
          '00000000|00000000|00000000|00000000|00000000',
          '00000000|ffffffff|ffffffff|ffffffff|00000000',
          '00000000|ffffffff|ffffffff|ffffffff|00000000',
          '00000000|ffffffff|ffffffff|ffffffff|00000000',
          '00000000|00000000|00000000|00000000|00000000',
        ],
      );
    });

    test('Fill with same color returns unchanged image', () async {
      final ui.Image inputImage = await createInputImage();
      final ui.Image resultImage = await applyFloodFill(
        image: inputImage,
        x: 2,
        y: 2,
        newColor: Colors.grey,
        tolerance: 1,
      );

      expect(resultImage.width, equals(inputImage.width));
      expect(resultImage.height, equals(inputImage.height));

      expect(
        await imageToListToString(resultImage),
        <String>[
          '00000000|00000000|00000000|00000000|00000000',
          '00000000|9e9e9eff|9e9e9eff|9e9e9eff|00000000',
          '00000000|9e9e9eff|9e9e9eff|9e9e9eff|00000000',
          '00000000|9e9e9eff|9e9e9eff|9e9e9eff|00000000',
          '00000000|00000000|00000000|00000000|00000000',
        ],
      );
    });

    test('Fill with out of bounds coordinates returns original image', () async {
      final ui.Image testImage = await createInputImage();
      // Flood fill top left corner
      ui.Image resultImage = await applyFloodFill(
        image: testImage,
        x: 0,
        y: 0,
        newColor: Colors.red,
        tolerance: 1,
      );

      expect(resultImage.width, equals(testImage.width));
      expect(resultImage.height, equals(testImage.height));

      expect(
        await imageToListToString(resultImage),
        <String>[
          'f44336ff|f44336ff|f44336ff|f44336ff|f44336ff',
          'f44336ff|ffffffff|ffffffff|ffffffff|f44336ff',
          'f44336ff|ffffffff|ffffffff|ffffffff|f44336ff',
          'f44336ff|ffffffff|ffffffff|ffffffff|f44336ff',
          'f44336ff|f44336ff|f44336ff|f44336ff|f44336ff',
        ],
      );

      // Fill from the center
      resultImage = await applyFloodFill(
        image: resultImage,
        x: (testImageSize / 2).toInt(),
        y: (testImageSize / 2).toInt(),
        newColor: Colors.red,
        tolerance: 1,
      );

      expect(
        await imageToListToString(resultImage),
        <String>[
          'f44336ff|f44336ff|f44336ff|f44336ff|f44336ff',
          'f44336ff|f44336ff|f44336ff|f44336ff|f44336ff',
          'f44336ff|f44336ff|f44336ff|f44336ff|f44336ff',
          'f44336ff|f44336ff|f44336ff|f44336ff|f44336ff',
          'f44336ff|f44336ff|f44336ff|f44336ff|f44336ff',
        ],
      );
    });
  });
}
