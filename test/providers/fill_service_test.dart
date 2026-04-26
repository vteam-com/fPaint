import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/fill_service.dart';

void main() {
  late FillService fillService;

  setUp(() {
    fillService = FillService();
  });

  group('FillRegion', () {
    test('stores path and offset', () {
      final FillRegion region = FillRegion(
        path: ui.Path(),
        offset: const Offset(10, 20),
      );
      expect(region.offset, const Offset(10, 20));
      expect(region.path, isNotNull);
    });
  });

  group('getRegionPathFromImage guards', () {
    test('returns empty region for NaN x coordinate', () async {
      final ui.Image image = await _createTestImage();
      final FillRegion region = await fillService.getRegionPathFromImage(
        image: image,
        position: const Offset(double.nan, 5),
        tolerance: 10,
      );
      expect(region.offset, ui.Offset.zero);
    });

    test('returns empty region for NaN y coordinate', () async {
      final ui.Image image = await _createTestImage();
      final FillRegion region = await fillService.getRegionPathFromImage(
        image: image,
        position: const Offset(5, double.nan),
        tolerance: 10,
      );
      expect(region.offset, ui.Offset.zero);
    });

    test('returns empty region for infinite x coordinate', () async {
      final ui.Image image = await _createTestImage();
      final FillRegion region = await fillService.getRegionPathFromImage(
        image: image,
        position: const Offset(double.infinity, 5),
        tolerance: 10,
      );
      expect(region.offset, ui.Offset.zero);
    });

    test('returns empty region for negative x coordinate', () async {
      final ui.Image image = await _createTestImage();
      final FillRegion region = await fillService.getRegionPathFromImage(
        image: image,
        position: const Offset(-1, 5),
        tolerance: 10,
      );
      expect(region.offset, ui.Offset.zero);
    });

    test('returns empty region for negative y coordinate', () async {
      final ui.Image image = await _createTestImage();
      final FillRegion region = await fillService.getRegionPathFromImage(
        image: image,
        position: const Offset(5, -1),
        tolerance: 10,
      );
      expect(region.offset, ui.Offset.zero);
    });

    test('returns empty region for x beyond image width', () async {
      final ui.Image image = await _createTestImage();
      final FillRegion region = await fillService.getRegionPathFromImage(
        image: image,
        position: Offset(image.width.toDouble(), 5),
        tolerance: 10,
      );
      expect(region.offset, ui.Offset.zero);
    });

    test('returns empty region for y beyond image height', () async {
      final ui.Image image = await _createTestImage();
      final FillRegion region = await fillService.getRegionPathFromImage(
        image: image,
        position: Offset(5, image.height.toDouble()),
        tolerance: 10,
      );
      expect(region.offset, ui.Offset.zero);
    });
  });

  group('getRegionPathFromImage valid coordinates', () {
    test('returns a region for valid in-bounds position', () async {
      final ui.Image image = await _createTestImage();
      final FillRegion region = await fillService.getRegionPathFromImage(
        image: image,
        position: const Offset(5, 5),
        tolerance: 50,
      );
      expect(region.path, isNotNull);
    });
  });

  group('createFloodFillSolidAction', () {
    test('returns a UserActionDrawing with region action type', () async {
      final ui.Image image = await _createTestImage();
      final UserActionDrawing result = await fillService.createFloodFillSolidAction(
        sourceImage: image,
        position: const Offset(5, 5),
        fillColor: const Color(0xFFFF0000),
        tolerance: 50,
        clipPath: null,
      );
      expect(result.action, ActionType.region);
      expect(result.fillColor, const Color(0xFFFF0000));
    });

    test('passes clipPath through to the result', () async {
      final ui.Image image = await _createTestImage();
      final ui.Path clip = ui.Path()..addRect(const Rect.fromLTWH(0, 0, 50, 50));
      final UserActionDrawing result = await fillService.createFloodFillSolidAction(
        sourceImage: image,
        position: const Offset(5, 5),
        fillColor: const Color(0xFF00FF00),
        tolerance: 50,
        clipPath: clip,
      );
      expect(result.clipPath, clip);
    });

    test('result has two position entries for bounds', () async {
      final ui.Image image = await _createTestImage();
      final UserActionDrawing result = await fillService.createFloodFillSolidAction(
        sourceImage: image,
        position: const Offset(5, 5),
        fillColor: const Color(0xFF0000FF),
        tolerance: 50,
        clipPath: null,
      );
      expect(result.positions.length, 2);
    });
  });

  group('createFloodFillGradientAction', () {
    test('returns fill action with empty positions for out-of-bounds start', () async {
      final ui.Image image = await _createTestImage();
      final FillModel fillModel = FillModel();
      fillModel.mode = FillMode.linear;
      fillModel.addPoint(
        GradientPoint(offset: const Offset(-100, -100), color: const Color(0xFFFF0000)),
      );
      fillModel.addPoint(
        GradientPoint(offset: const Offset(-50, -50), color: const Color(0xFF0000FF)),
      );

      final UserActionDrawing result = await fillService.createFloodFillGradientAction(
        sourceImage: image,
        fillModel: fillModel,
        tolerance: 50,
        clipPath: null,
        toCanvas: (final Offset o) => o,
      );
      // Out-of-bounds start returns empty fill action
      expect(result.action, ActionType.fill);
      expect(result.positions, isEmpty);
    });

    test('returns region action for valid linear gradient', () async {
      final ui.Image image = await _createTestImage();
      final FillModel fillModel = FillModel();
      fillModel.mode = FillMode.linear;
      fillModel.addPoint(
        GradientPoint(offset: const Offset(2, 2), color: const Color(0xFFFF0000)),
      );
      fillModel.addPoint(
        GradientPoint(offset: const Offset(8, 8), color: const Color(0xFF0000FF)),
      );

      final UserActionDrawing result = await fillService.createFloodFillGradientAction(
        sourceImage: image,
        fillModel: fillModel,
        tolerance: 50,
        clipPath: null,
        toCanvas: (final Offset o) => o,
      );
      expect(result.action, ActionType.region);
      expect(result.gradient, isA<LinearGradient>());
    });

    test('returns region action for valid radial gradient', () async {
      final ui.Image image = await _createTestImage();
      final FillModel fillModel = FillModel();
      fillModel.mode = FillMode.radial;
      fillModel.addPoint(
        GradientPoint(offset: const Offset(5, 5), color: const Color(0xFFFF0000)),
      );
      fillModel.addPoint(
        GradientPoint(offset: const Offset(8, 8), color: const Color(0xFF0000FF)),
      );

      final UserActionDrawing result = await fillService.createFloodFillGradientAction(
        sourceImage: image,
        fillModel: fillModel,
        tolerance: 50,
        clipPath: null,
        toCanvas: (final Offset o) => o,
      );
      expect(result.action, ActionType.region);
      expect(result.gradient, isA<RadialGradient>());
    });

    test('passes clipPath through to gradient result', () async {
      final ui.Image image = await _createTestImage();
      final ui.Path clip = ui.Path()..addRect(const Rect.fromLTWH(0, 0, 20, 20));
      final FillModel fillModel = FillModel();
      fillModel.mode = FillMode.linear;
      fillModel.addPoint(
        GradientPoint(offset: const Offset(2, 2), color: const Color(0xFFFF0000)),
      );
      fillModel.addPoint(
        GradientPoint(offset: const Offset(8, 8), color: const Color(0xFF0000FF)),
      );

      final UserActionDrawing result = await fillService.createFloodFillGradientAction(
        sourceImage: image,
        fillModel: fillModel,
        tolerance: 50,
        clipPath: clip,
        toCanvas: (final Offset o) => o,
      );
      expect(result.clipPath, clip);
    });

    test('uses toCanvas callback to transform coordinates', () async {
      final ui.Image image = await _createTestImage();
      final FillModel fillModel = FillModel();
      fillModel.mode = FillMode.linear;
      // Coordinates that are out of bounds before transform, in bounds after
      fillModel.addPoint(
        GradientPoint(offset: const Offset(1, 1), color: const Color(0xFFFF0000)),
      );
      fillModel.addPoint(
        GradientPoint(offset: const Offset(2, 2), color: const Color(0xFF0000FF)),
      );

      // Scale up coordinates via toCanvas
      final UserActionDrawing result = await fillService.createFloodFillGradientAction(
        sourceImage: image,
        fillModel: fillModel,
        tolerance: 50,
        clipPath: null,
        toCanvas: (final Offset o) => o * 3,
      );
      // Should successfully create a region with the transformed coordinates
      expect(result.action, ActionType.region);
    });
  });
}

/// Creates a small solid-color test image (20x20 white pixels).
Future<ui.Image> _createTestImage() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 20, 20),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  final ui.Picture picture = recorder.endRecording();
  return picture.toImage(20, 20);
}
