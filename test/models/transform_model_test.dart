import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/transform_model.dart';

/// Creates a test image.
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
  group('TransformModel', () {
    test('starts hidden with no image', () {
      final TransformModel model = TransformModel();
      expect(model.isVisible, isFalse);
      expect(model.sourceImage, isNull);
      expect(model.sourceBounds, Rect.zero);
      expect(model.corners, isEmpty);
    });

    test('start() initialises corners from bounds', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      const Rect bounds = Rect.fromLTWH(10, 20, 100, 50);

      model.start(image: image, bounds: bounds);

      expect(model.isVisible, isTrue);
      expect(model.sourceImage, isNotNull);
      expect(model.sourceBounds, bounds);
      expect(model.corners.length, TransformModel.cornerCount);
      expect(model.corners[TransformModel.topLeftIndex], bounds.topLeft);
      expect(model.corners[TransformModel.topRightIndex], bounds.topRight);
      expect(model.corners[TransformModel.bottomRightIndex], bounds.bottomRight);
      expect(model.corners[TransformModel.bottomLeftIndex], bounds.bottomLeft);
    });

    test('moveCorner moves a single corner', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      const Rect bounds = Rect.fromLTWH(0, 0, 100, 100);
      model.start(image: image, bounds: bounds);

      model.moveCorner(TransformModel.topRightIndex, const Offset(10, -5));

      expect(model.corners[TransformModel.topRightIndex], const Offset(110, -5));
      // Other corners unchanged
      expect(model.corners[TransformModel.topLeftIndex], Offset.zero);
      expect(model.corners[TransformModel.bottomRightIndex], const Offset(100, 100));
      expect(model.corners[TransformModel.bottomLeftIndex], const Offset(0, 100));
    });

    test('moveEdge moves two corners on the edge', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      const Rect bounds = Rect.fromLTWH(0, 0, 100, 100);
      model.start(image: image, bounds: bounds);

      // Move top edge (topLeft + topRight) by (5, -10)
      model.moveEdge(
        TransformModel.topLeftIndex,
        TransformModel.topRightIndex,
        const Offset(5, -10),
      );

      expect(model.corners[TransformModel.topLeftIndex], const Offset(5, -10));
      expect(model.corners[TransformModel.topRightIndex], const Offset(105, -10));
      // Bottom corners unchanged
      expect(model.corners[TransformModel.bottomLeftIndex], const Offset(0, 100));
      expect(model.corners[TransformModel.bottomRightIndex], const Offset(100, 100));
    });

    test('moveAll translates all corners', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      const Rect bounds = Rect.fromLTWH(0, 0, 100, 100);
      model.start(image: image, bounds: bounds);

      model.moveAll(const Offset(20, 30));

      expect(model.corners[TransformModel.topLeftIndex], const Offset(20, 30));
      expect(model.corners[TransformModel.topRightIndex], const Offset(120, 30));
      expect(model.corners[TransformModel.bottomRightIndex], const Offset(120, 130));
      expect(model.corners[TransformModel.bottomLeftIndex], const Offset(20, 130));
    });

    test('center returns quad centroid', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      const Rect bounds = Rect.fromLTWH(0, 0, 100, 100);
      model.start(image: image, bounds: bounds);

      expect(model.center, const Offset(50, 50));
    });

    test('edgeMidpoint returns correct midpoint', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      const Rect bounds = Rect.fromLTWH(0, 0, 100, 100);
      model.start(image: image, bounds: bounds);

      final Offset topMid = model.edgeMidpoint(
        TransformModel.topLeftIndex,
        TransformModel.topRightIndex,
      );
      expect(topMid, const Offset(50, 0));

      final Offset leftMid = model.edgeMidpoint(
        TransformModel.bottomLeftIndex,
        TransformModel.topLeftIndex,
      );
      expect(leftMid, const Offset(0, 50));
    });

    test('quadBounds returns bounding rect of all corners', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      const Rect bounds = Rect.fromLTWH(10, 20, 100, 50);
      model.start(image: image, bounds: bounds);

      // Move top-right corner further out
      model.moveCorner(TransformModel.topRightIndex, const Offset(30, -10));

      final Rect quad = model.quadBounds;
      expect(quad.left, 10); // topLeft.dx
      expect(quad.top, 10); // topRight moved to y=10
      expect(quad.right, 140); // topRight.dx = 110 + 30
      expect(quad.bottom, 70); // bottomRight.dy = 70
    });

    test('quadBounds returns Rect.zero when corners empty', () {
      final TransformModel model = TransformModel();
      expect(model.quadBounds, Rect.zero);
    });

    test('clear() resets all state', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      model.start(image: image, bounds: const Rect.fromLTWH(0, 0, 100, 100));

      model.clear();

      expect(model.isVisible, isFalse);
      expect(model.sourceImage, isNull);
      expect(model.sourceBounds, Rect.zero);
      expect(model.corners, isEmpty);
    });
  });
}
