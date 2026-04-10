import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/transform_helper.dart';

/// Creates a solid-colored test image.
Future<ui.Image> _createTestImage({
  final int width = 100,
  final int height = 100,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.red,
  );
  return recorder.endRecording().toImage(width, height);
}

void main() {
  group('drawPerspectiveImage', () {
    test('draws without error for identity quad', () async {
      final ui.Image image = await _createTestImage();
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // An identity quad matching the image bounds
      final List<Offset> corners = <Offset>[
        Offset.zero,
        const Offset(100, 0),
        const Offset(100, 100),
        const Offset(0, 100),
      ];

      drawPerspectiveImage(canvas, image, corners, 4);

      // If we get here without an exception, the function is correct
      final ui.Image result = await recorder.endRecording().toImage(100, 100);
      expect(result.width, 100);
      expect(result.height, 100);
    });

    test('draws without error for skewed quad', () async {
      final ui.Image image = await _createTestImage();
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // A horizontally skewed quad
      final List<Offset> corners = <Offset>[
        const Offset(10, 0),
        const Offset(110, 0),
        const Offset(100, 100),
        const Offset(0, 100),
      ];

      drawPerspectiveImage(canvas, image, corners, 4);

      final ui.Image result = await recorder.endRecording().toImage(120, 100);
      expect(result.width, 120);
      expect(result.height, 100);
    });

    test('draws with perspective transformation', () async {
      final ui.Image image = await _createTestImage();
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // A perspective-warped quad (top narrower than bottom)
      final List<Offset> corners = <Offset>[
        const Offset(20, 0),
        const Offset(80, 0),
        const Offset(100, 100),
        const Offset(0, 100),
      ];

      drawPerspectiveImage(canvas, image, corners, 8);

      final ui.Image result = await recorder.endRecording().toImage(100, 100);
      expect(result.width, 100);
      expect(result.height, 100);
    });
  });

  group('renderTransformedImage', () {
    test('returns image with correct dimensions', () async {
      final ui.Image source = await _createTestImage();

      final List<Offset> corners = <Offset>[
        const Offset(10, 10),
        const Offset(110, 10),
        const Offset(110, 110),
        const Offset(10, 110),
      ];

      final ui.Image result = await renderTransformedImage(source, corners, 4);

      // Output should be 100x100 (quad bounds: 10..110 = 100)
      expect(result.width, 100);
      expect(result.height, 100);
    });

    test('handles skewed quad bounds', () async {
      final ui.Image source = await _createTestImage();

      // Skewed quad: wider than original
      final List<Offset> corners = <Offset>[
        const Offset(20, 0),
        const Offset(120, 0),
        const Offset(140, 100),
        const Offset(0, 100),
      ];

      final ui.Image result = await renderTransformedImage(source, corners, 4);

      // Quad bounds: x[0..140], y[0..100] → 140x100
      expect(result.width, 140);
      expect(result.height, 100);
    });
  });
}
