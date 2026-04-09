import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/image_placement_model.dart';

/// Creates a 1×1 pixel image for testing.
Future<ui.Image> _createTestImage({
  final int width = 100,
  final int height = 50,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.red,
  );
  return recorder.endRecording().toImage(width, height);
}

void main() {
  group('ImagePlacementModel', () {
    test('starts hidden with no image', () {
      final ImagePlacementModel model = ImagePlacementModel();
      expect(model.isVisible, isFalse);
      expect(model.image, isNull);
      expect(model.position, Offset.zero);
      expect(model.scale, 1.0);
      expect(model.rotation, 0.0);
    });

    test('start() makes model visible and stores state', () async {
      final ImagePlacementModel model = ImagePlacementModel();
      final ui.Image image = await _createTestImage();
      const Offset pos = Offset(10, 20);

      model.start(imageToPlace: image, initialPosition: pos);

      expect(model.isVisible, isTrue);
      expect(model.image, isNotNull);
      expect(model.position, pos);
      expect(model.scale, 1.0);
      expect(model.rotation, 0.0);
    });

    test('displayWidth and displayHeight reflect scale', () async {
      final ImagePlacementModel model = ImagePlacementModel();
      final ui.Image image = await _createTestImage(width: 200, height: 100);

      model.start(imageToPlace: image, initialPosition: Offset.zero);
      expect(model.displayWidth, 200.0);
      expect(model.displayHeight, 100.0);

      model.scale = 0.5;
      expect(model.displayWidth, 100.0);
      expect(model.displayHeight, 50.0);
    });

    test('bounds reflects position and scaled size', () async {
      final ImagePlacementModel model = ImagePlacementModel();
      final ui.Image image = await _createTestImage(width: 100, height: 50);

      model.start(imageToPlace: image, initialPosition: const Offset(10, 20));
      model.scale = 2.0;

      expect(model.bounds, const Rect.fromLTWH(10, 20, 200, 100));
    });

    test('center is computed correctly', () async {
      final ImagePlacementModel model = ImagePlacementModel();
      final ui.Image image = await _createTestImage(width: 100, height: 100);

      model.start(imageToPlace: image, initialPosition: const Offset(0, 0));

      expect(model.center, const Offset(50, 50));
    });

    test('clear() resets all state', () async {
      final ImagePlacementModel model = ImagePlacementModel();
      final ui.Image image = await _createTestImage();

      model.start(imageToPlace: image, initialPosition: const Offset(10, 20));
      model.scale = 2.0;
      model.rotation = 1.5;
      model.clear();

      expect(model.isVisible, isFalse);
      expect(model.image, isNull);
      expect(model.position, Offset.zero);
      expect(model.scale, 1.0);
      expect(model.rotation, 0.0);
    });
  });
}
