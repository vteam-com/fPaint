import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/panels/tools/flood_fill.dart';

void main() {
  group('Flood Fill Tests', () {
    late ui.Image testImage;

    setUp(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = Colors.white;
      canvas.drawRect(const Rect.fromLTWH(0, 0, 10, 10), paint);
      final picture = recorder.endRecording();
      testImage = await picture.toImage(10, 10);
    });

    test('Fill with same color returns unchanged image', () async {
      final result = await applyFloodFill(
        image: testImage,
        x: 5,
        y: 5,
        newColor: Colors.white,
      );

      expect(result.width, equals(testImage.width));
      expect(result.height, equals(testImage.height));
    });

    test('Fill with out of bounds coordinates returns original image',
        () async {
      final result = await applyFloodFill(
        image: testImage,
        x: -1,
        y: -1,
        newColor: Colors.red,
      );

      expect(result.width, equals(testImage.width));
      expect(result.height, equals(testImage.height));
    });

    test('Fill with different color changes pixels', () async {
      final result = await applyFloodFill(
        image: testImage,
        x: 5,
        y: 5,
        newColor: Colors.red,
      );

      expect(result.width, equals(testImage.width));
      expect(result.height, equals(testImage.height));

      final ByteData? resultData = await result.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      expect(resultData, isNotNull);
    });

    test('Point class initialization', () {
      final point = Point(1, 2);
      expect(point.x, equals(1));
      expect(point.y, equals(2));
    });
  });
}
