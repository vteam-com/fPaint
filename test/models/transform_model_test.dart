import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.vteam.fpaint/haptic'),
      (final MethodCall methodCall) async => null,
    );
  });

  group('TransformModel', () {
    test('starts hidden with no image', () {
      final TransformModel model = TransformModel();
      expect(model.isVisible, isFalse);
      expect(model.sourceImage, isNull);
      expect(model.sourceBounds, Rect.zero);
      expect(model.corners, isEmpty);
    });

    test('start() initializes corners from bounds', () async {
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
      expect(model.edgeMidpoints.length, TransformModel.edgeHandleCount);
      expect(model.edgeMidpoints[TransformModel.topEdgeIndex], bounds.topCenter);
      expect(model.edgeMidpoints[TransformModel.rightEdgeIndex], bounds.centerRight);
      expect(model.edgeMidpoints[TransformModel.bottomEdgeIndex], bounds.bottomCenter);
      expect(model.edgeMidpoints[TransformModel.leftEdgeIndex], bounds.centerLeft);
      expect(model.handleSet, TransformHandleSet.corners);
      expect(model.areCornerHandlesEnabled, isTrue);
      expect(model.areEdgeHandlesEnabled, isFalse);
      expect(model.isCenterHandleEnabled, isFalse);
    });

    test('cycleHandleSet rotates corners, edges, and all handles', () {
      final TransformModel model = TransformModel();

      expect(model.handleSet, TransformHandleSet.corners);

      model.cycleHandleSet();
      expect(model.handleSet, TransformHandleSet.edges);
      expect(model.areCornerHandlesEnabled, isFalse);
      expect(model.areEdgeHandlesEnabled, isTrue);
      expect(model.isCenterHandleEnabled, isFalse);

      model.cycleHandleSet();
      expect(model.handleSet, TransformHandleSet.all);
      expect(model.areCornerHandlesEnabled, isTrue);
      expect(model.areEdgeHandlesEnabled, isTrue);
      expect(model.isCenterHandleEnabled, isTrue);

      model.cycleHandleSet();
      expect(model.handleSet, TransformHandleSet.corners);
      expect(model.areCornerHandlesEnabled, isTrue);
      expect(model.areEdgeHandlesEnabled, isFalse);
      expect(model.isCenterHandleEnabled, isFalse);
    });

    test('setDeformMode resets the default handle set to corners', () {
      final TransformModel model = TransformModel();

      model.cycleHandleSet();
      model.cycleHandleSet();
      expect(model.handleSet, TransformHandleSet.all);

      model.setRotateMode();
      model.setDeformMode();

      expect(model.isDeformMode, isTrue);
      expect(model.handleSet, TransformHandleSet.corners);
      expect(model.areCornerHandlesEnabled, isTrue);
      expect(model.areEdgeHandlesEnabled, isFalse);
      expect(model.isCenterHandleEnabled, isFalse);
    });

    test('disabled edge handles do not affect the active warp controls', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      const Rect bounds = Rect.fromLTWH(10, 20, 100, 50);
      model.start(image: image, bounds: bounds);

      model.moveEdgeHandle(TransformModel.bottomEdgeIndex, const Offset(0, 30));

      expect(model.edgeMidpoints[TransformModel.bottomEdgeIndex], const Offset(60, 100));
      expect(model.effectiveEdgeMidpoints[TransformModel.bottomEdgeIndex], const Offset(60, 70));
      expect(model.quadBounds.bottom, 70);

      model.cycleHandleSet();

      expect(model.effectiveEdgeMidpoints[TransformModel.bottomEdgeIndex], const Offset(60, 100));
      expect(model.quadBounds.bottom, 100);
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

    test('moveEdgeHandle moves only the midpoint control', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      const Rect bounds = Rect.fromLTWH(0, 0, 100, 100);
      model.start(image: image, bounds: bounds);

      model.moveEdgeHandle(TransformModel.leftEdgeIndex, const Offset(-15, 20));

      expect(model.edgeMidpoints[TransformModel.leftEdgeIndex], const Offset(-15, 70));
      expect(model.corners[TransformModel.topLeftIndex], Offset.zero);
      expect(model.corners[TransformModel.bottomLeftIndex], const Offset(0, 100));
    });

    test('moveConnectedEdge moves the linked corners and midpoint together', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      const Rect bounds = Rect.fromLTWH(0, 0, 100, 100);
      model.start(image: image, bounds: bounds);

      model.moveConnectedEdge(TransformModel.topEdgeIndex, const Offset(10, -5));

      expect(model.corners[TransformModel.topLeftIndex], const Offset(10, -5));
      expect(model.corners[TransformModel.topRightIndex], const Offset(110, -5));
      expect(model.edgeMidpoints[TransformModel.topEdgeIndex], const Offset(60, -5));
      expect(model.corners[TransformModel.bottomLeftIndex], const Offset(0, 100));
      expect(model.corners[TransformModel.bottomRightIndex], const Offset(100, 100));
      expect(model.edgeMidpoints[TransformModel.leftEdgeIndex], const Offset(0, 50));
      expect(model.edgeMidpoints[TransformModel.rightEdgeIndex], const Offset(100, 50));
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

    test('scaleUniform scales all corners evenly around the center', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      const Rect bounds = Rect.fromLTWH(0, 0, 100, 100);
      model.start(image: image, bounds: bounds);

      model.beginScaleGesture();
      model.scaleUniform(2);

      expect(model.corners[TransformModel.topLeftIndex], const Offset(-50, -50));
      expect(model.corners[TransformModel.topRightIndex], const Offset(150, -50));
      expect(model.corners[TransformModel.bottomRightIndex], const Offset(150, 150));
      expect(model.corners[TransformModel.bottomLeftIndex], const Offset(-50, 150));
      expect(model.activeScalePercent, AppMath.percentScale * 2);
      expect(model.isScaleFeedbackVisible, isTrue);
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

    test('quadBounds includes edge midpoint controls when edge handles are enabled', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      const Rect bounds = Rect.fromLTWH(10, 20, 100, 50);
      model.start(image: image, bounds: bounds);

      model.moveEdgeHandle(TransformModel.bottomEdgeIndex, const Offset(0, 30));
      model.cycleHandleSet();

      final Rect quad = model.quadBounds;
      expect(quad.left, 10);
      expect(quad.top, 20);
      expect(quad.right, 110);
      expect(quad.bottom, 100);
    });

    test('quadBounds returns Rect.zero when corners empty', () {
      final TransformModel model = TransformModel();
      expect(model.quadBounds, Rect.zero);
    });

    test('clear() resets all state', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      model.start(image: image, bounds: const Rect.fromLTWH(0, 0, 100, 100));

      model.beginScaleGesture();
      model.setRotateMode();

      model.clear();

      expect(model.isVisible, isFalse);
      expect(model.sourceImage, isNull);
      expect(model.sourceBounds, Rect.zero);
      expect(model.corners, isEmpty);
      expect(model.edgeMidpoints, isEmpty);
      expect(model.isDeformMode, isTrue);
      expect(model.activeScalePercent, AppMath.percentScale);
      expect(model.isScaleFeedbackVisible, isFalse);
    });

    test('interaction mode setters work correctly', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      model.start(image: image, bounds: const Rect.fromLTWH(0, 0, 100, 100));

      expect(model.isDeformMode, isTrue);
      expect(model.isRotateMode, isFalse);
      expect(model.isScaleMode, isFalse);

      model.setRotateMode();
      expect(model.isRotateMode, isTrue);
      expect(model.isDeformMode, isFalse);
      expect(model.isScaleMode, isFalse);

      model.setScaleMode();
      expect(model.isScaleMode, isTrue);
      expect(model.isDeformMode, isFalse);
      expect(model.isRotateMode, isFalse);

      model.setDeformMode();
      expect(model.isDeformMode, isTrue);
    });

    test('beginScaleGesture and endScaleGesture', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      model.start(image: image, bounds: const Rect.fromLTWH(0, 0, 100, 100));

      model.beginScaleGesture();
      expect(model.isScaleMode, isTrue);
      expect(model.isScaleFeedbackVisible, isTrue);
      expect(model.activeScalePercent, AppMath.percentScale);

      model.endScaleGesture();
      expect(model.isScaleFeedbackVisible, isFalse);
      expect(model.activeScalePercent, AppMath.percentScale);
    });

    test('beginRotateGesture and endRotateGesture', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      model.start(image: image, bounds: const Rect.fromLTWH(0, 0, 100, 100));

      model.beginRotateGesture();
      expect(model.isRotateMode, isTrue);
      expect(model.isRotationFeedbackVisible, isTrue);
      expect(model.activeRotationDegrees, 0);

      model.endRotateGesture();
      expect(model.isRotationFeedbackVisible, isFalse);
      expect(model.activeRotationDegrees, 0);
    });

    test('updateRotationFeedback accumulates degrees', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      model.start(image: image, bounds: const Rect.fromLTWH(0, 0, 100, 100));

      model.beginRotateGesture();
      const double piRadians = 3.14159265;
      model.updateRotationFeedback(piRadians);
      // pi radians ≈ 180 degrees
      expect(model.activeRotationDegrees, closeTo(180, 1));
    });

    test('isFeedbackVisible returns true when either feedback active', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      model.start(image: image, bounds: const Rect.fromLTWH(0, 0, 100, 100));

      expect(model.isFeedbackVisible, isFalse);

      model.beginScaleGesture();
      expect(model.isFeedbackVisible, isTrue);

      model.endScaleGesture();
      expect(model.isFeedbackVisible, isFalse);

      model.beginRotateGesture();
      expect(model.isFeedbackVisible, isTrue);
    });

    test('rotate rotates corners around center', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      const Rect bounds = Rect.fromLTWH(0, 0, 100, 100);
      model.start(image: image, bounds: bounds);

      final Offset centerBefore = model.center;
      // Rotate 90 degrees (pi/2)
      const double quarterTurn = 1.5707963;
      model.rotate(quarterTurn);

      // Center should be unchanged
      expect(model.center.dx, closeTo(centerBefore.dx, 1));
      expect(model.center.dy, closeTo(centerBefore.dy, 1));

      // Top-left (0,0) rotated 90° CW around (50,50) => (100,0)
      expect(model.corners[TransformModel.topLeftIndex].dx, closeTo(100, 1));
      expect(model.corners[TransformModel.topLeftIndex].dy, closeTo(0, 1));
    });

    test('scaleUniform clamps to valid range', () async {
      final TransformModel model = TransformModel();
      final ui.Image image = await _createTestImage();
      const Rect bounds = Rect.fromLTWH(0, 0, 100, 100);
      model.start(image: image, bounds: bounds);

      model.beginScaleGesture();
      // Try to scale by an extreme factor - it should be clamped
      model.scaleUniform(AppInteraction.transformScaleFactorMax + 10);
      // Corners should still be finite
      for (final Offset corner in model.corners) {
        expect(corner.dx.isFinite, isTrue);
        expect(corner.dy.isFinite, isTrue);
      }
    });
  });

  group('TransformInteractionMode', () {
    test('has 3 values', () {
      expect(TransformInteractionMode.values.length, 3);
    });

    test('contains scale, rotate, deform', () {
      expect(TransformInteractionMode.values, contains(TransformInteractionMode.scale));
      expect(TransformInteractionMode.values, contains(TransformInteractionMode.rotate));
      expect(TransformInteractionMode.values, contains(TransformInteractionMode.deform));
    });
  });
}
