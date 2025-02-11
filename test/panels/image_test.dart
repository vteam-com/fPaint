import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/image_helper.dart';

void main() {
  group('Flood Fill Tests', () {
    test('Fill with same color returns unchanged image', () async {
      const int testImageWidth = 4;
      const int testImageHeight = 4;

      // Create an image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = Colors.blue;
      canvas.drawRect(const Rect.fromLTWH(1, 1, 2, 2), paint);
      final picture = recorder.endRecording();
      final testImage = await picture.toImage(testImageWidth, testImageHeight);

      // Convert to bytes
      final Uint8List? data = await convertImageToUint8List(testImage);

      expect(
        imageBytesListToString(data!, testImageWidth),
        [
          '00000000|00000000|00000000|00000000',
          '00000000|2196f3ff|2196f3ff|00000000',
          '00000000|2196f3ff|2196f3ff|00000000',
          '00000000|00000000|00000000|00000000',
        ],
      );

      // recreate the same image from the bytes
      {
        final restored = await createImageFromBytes(
          bytes: data,
          width: testImageWidth,
          height: testImageHeight,
        );

        // test that the same bytes are restored
        final Uint8List? data2 = await convertImageToUint8List(restored);
        expect(
          imageBytesListToString(data2!, testImageWidth),
          [
            '00000000|00000000|00000000|00000000',
            '00000000|2196f3ff|2196f3ff|00000000',
            '00000000|2196f3ff|2196f3ff|00000000',
            '00000000|00000000|00000000|00000000',
          ],
        );
      }
    });
  });
}
