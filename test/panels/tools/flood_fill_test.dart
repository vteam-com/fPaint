import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/panels/tools/flood_fill.dart';

void main() {
  group('Flood Fill Tests', () {
    late ui.Image testImage;
    const int testImageSize = 5;

    setUp(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = Colors.white;
      canvas.drawRect(
        const Rect.fromLTWH(1, 1, testImageSize - 2, testImageSize - 2),
        paint,
      );
      final picture = recorder.endRecording();
      testImage = await picture.toImage(testImageSize, testImageSize);
    });

    test('Fill with same color returns unchanged image', () async {
      final ui.Image resultImage = await applyFloodFill(
        image: testImage,
        x: 2,
        y: 2,
        newColor: Colors.white,
        tolerance: 1,
      );

      expect(resultImage.width, equals(testImage.width));
      expect(resultImage.height, equals(testImage.height));

      final Uint8List? data = await convertImageToUint8List(resultImage);

      expect(
        imageBytesListToString(data!, testImageSize),
        [
          '00000000|00000000|00000000|00000000|00000000',
          '00000000|ffffffff|ffffffff|ffffffff|00000000',
          '00000000|ffffffff|ffffffff|ffffffff|00000000',
          '00000000|ffffffff|ffffffff|ffffffff|00000000',
          '00000000|00000000|00000000|00000000|00000000',
        ],
      );
    });

    test('Fill with out of bounds coordinates returns original image',
        () async {
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

      final Uint8List? data = await convertImageToUint8List(resultImage);

      expect(
        imageBytesListToString(data!, testImageSize),
        [
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

      final Uint8List? data2 = await convertImageToUint8List(resultImage);

      expect(
        imageBytesListToString(data2!, testImageSize),
        [
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
