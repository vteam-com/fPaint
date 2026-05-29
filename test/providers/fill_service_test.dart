import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/fill_service.dart';

const Rect _selectionRegionOverrideRect = Rect.fromLTWH(1, 1, 3, 3);
const Offset _selectionRegionTapPosition = Offset(5, 5);
const Rect _offsetGradientRegionOverrideRect = Rect.fromLTWH(10, 20, 20, 20);
const Size _offsetGradientImageSize = Size(40, 50);
const Size _ringImageSize = Size(8, 8);
const Rect _ringOuterRect = Rect.fromLTWH(1, 1, 6, 6);
const Rect _ringInnerRect = Rect.fromLTWH(3, 3, 2, 2);
const Offset _ringSeedPosition = Offset(1, 1);
const Rect _ringLocalBounds = Rect.fromLTWH(0, 0, 6, 6);
const Offset _ringFilledLocalPoint = Offset(0.5, 0.5);
const Offset _ringHoleLocalPoint = Offset(3, 3);
const Size _diagonalImageSize = Size(3, 3);
const Rect _firstDiagonalPixelRect = Rect.fromLTWH(0, 0, 1, 1);
const Rect _secondDiagonalPixelRect = Rect.fromLTWH(1, 1, 1, 1);
const Offset _diagonalSeedPosition = Offset.zero;
const Rect _singlePixelLocalBounds = Rect.fromLTWH(0, 0, 1, 1);
const Offset _singlePixelLocalPoint = Offset(0.5, 0.5);
const Offset _diagonalExcludedLocalPoint = Offset(1.5, 1.5);

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

    test('preserves enclosed holes in the traced region path', () async {
      final ui.Image image = await _createRingTestImage();
      final FillRegion region = await fillService.getRegionPathFromImage(
        image: image,
        position: _ringSeedPosition,
        tolerance: AppMath.zero,
      );

      expect(region.offset, _ringOuterRect.topLeft);
      expect(region.path.getBounds(), _ringLocalBounds);
      expect(region.path.contains(_ringFilledLocalPoint), isTrue);
      expect(region.path.contains(_ringHoleLocalPoint), isFalse);
    });

    test('does not bridge diagonal-only contact into the selected path', () async {
      final ui.Image image = await _createDiagonalTouchImage();
      final FillRegion region = await fillService.getRegionPathFromImage(
        image: image,
        position: _diagonalSeedPosition,
        tolerance: AppMath.zero,
      );

      expect(region.offset, Offset.zero);
      expect(region.path.getBounds(), _singlePixelLocalBounds);
      expect(region.path.contains(_singlePixelLocalPoint), isTrue);
      expect(region.path.contains(_diagonalExcludedLocalPoint), isFalse);
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

    test('uses the selected solid fill color as the halftone dot color', () async {
      final ui.Image image = await _createTestImage();
      final UserActionDrawing result = await fillService.createFloodFillSolidAction(
        sourceImage: image,
        position: const Offset(5, 5),
        fillColor: const Color(0xFFFF0000),
        halftoneDotColor: const Color(0xFFFF0000),
        halftoneMaxDotSizeFactor: AppVisual.half,
        tolerance: 50,
        clipPath: null,
      );

      expect(result.action, ActionType.region);
      expect(result.fillColor, const Color(0xFFFF0000));
      expect(result.halftoneFill, isNotNull);
      expect(result.halftoneFill!.backgroundColor, AppColors.transparent);
      expect(result.halftoneFill!.dotColor, const Color(0xFFFF0000));
      expect(result.halftoneFill!.maxDotSizeFactor, AppVisual.half);
    });

    test('uses regionPathOverride instead of the tapped flood-fill origin', () async {
      final ui.Image image = await _createTestImage();
      final ui.Path overridePath = ui.Path()..addRect(_selectionRegionOverrideRect);

      final UserActionDrawing result = await fillService.createFloodFillSolidAction(
        sourceImage: image,
        position: _selectionRegionTapPosition,
        fillColor: const Color(0xFFFF0000),
        tolerance: 50,
        clipPath: overridePath,
        regionPathOverride: overridePath,
      );

      expect(result.path, isNotNull);
      expect(result.path!.getBounds(), _selectionRegionOverrideRect);
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
      expect(result.halftoneFill, isNull);
    });

    test('uses first and last gradient stops for halftone flood fill', () async {
      final ui.Image image = await _createTestImage();
      final FillModel fillModel = FillModel();
      fillModel.mode = FillMode.linear;
      fillModel.halftoneMaxDotSizePercent = AppLimits.percentMax ~/ AppMath.pair;
      fillModel.halftoneEnabled = true;
      fillModel.gradientStopColors = const <Color>[
        Color(0xFFFF0000),
        Color(0xFF00FF00),
        Color(0xFF0000FF),
      ];
      fillModel.gradientStopPositions = const <double>[0.0, 0.5, 1.0];
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
      expect(result.halftoneFill, isNotNull);
      expect(result.halftoneFill!.backgroundColor, const Color(0xFFFF0000));
      expect(result.halftoneFill!.dotColor, const Color(0xFF0000FF));
      expect(result.halftoneFill!.maxDotSizeFactor, AppVisual.half);
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

    test('uses regionPathOverride for gradient fills', () async {
      final ui.Image image = await _createTestImage();
      final FillModel fillModel = FillModel();
      final ui.Path overridePath = ui.Path()..addRect(_selectionRegionOverrideRect);
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
        clipPath: overridePath,
        toCanvas: (final Offset o) => o,
        regionPathOverride: overridePath,
      );

      expect(result.action, ActionType.region);
      expect(result.path, isNotNull);
      expect(result.path!.getBounds(), _selectionRegionOverrideRect);
    });

    test('uses bounds-relative alignment for linear gradients on offset regions', () async {
      final ui.Image image = await _recordTestImage(
        size: _offsetGradientImageSize,
        painter: (final Canvas canvas) {
          canvas.drawRect(
            Rect.fromLTWH(0, 0, _offsetGradientImageSize.width, _offsetGradientImageSize.height),
            Paint()..color = const Color(0xFFFFFFFF),
          );
        },
      );
      final FillModel fillModel = FillModel();
      final ui.Path overridePath = ui.Path()..addRect(_offsetGradientRegionOverrideRect);
      fillModel.mode = FillMode.linear;
      fillModel.addPoint(
        GradientPoint(offset: _offsetGradientRegionOverrideRect.topLeft, color: const Color(0xFFFF0000)),
      );
      fillModel.addPoint(
        GradientPoint(offset: _offsetGradientRegionOverrideRect.bottomRight, color: const Color(0xFF0000FF)),
      );

      final UserActionDrawing result = await fillService.createFloodFillGradientAction(
        sourceImage: image,
        fillModel: fillModel,
        tolerance: 50,
        clipPath: null,
        toCanvas: (final Offset o) => o,
        regionPathOverride: overridePath,
      );

      final LinearGradient gradient = result.gradient! as LinearGradient;
      expect(gradient.begin, const Alignment(-1, -1));
      expect(gradient.end, const Alignment(1, 1));
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

    test('snapshots gradient stops for recorded actions', () async {
      final ui.Image image = await _createTestImage();
      final FillModel fillModel = FillModel();
      fillModel.mode = FillMode.linear;
      fillModel.gradientStopColors = <Color>[
        const Color(0xFFFF0000),
        const Color(0xFF0000FF),
      ];
      fillModel.gradientStopPositions = <double>[0.0, 1.0];
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

      fillModel.gradientStopColors[0] = const Color(0xFFFFA500);
      fillModel.gradientStopColors[1] = const Color(0xFF800080);
      fillModel.gradientStopPositions[0] = 0.25;
      fillModel.gradientStopPositions[1] = 0.75;

      final LinearGradient gradient = result.gradient! as LinearGradient;
      expect(gradient.colors, <Color>[
        const Color(0xFFFF0000),
        const Color(0xFF0000FF),
      ]);
      expect(gradient.stops, <double>[0.0, 1.0]);
    });
  });
}

/// Creates a small solid-color test image (20x20 white pixels).
Future<ui.Image> _createTestImage() async {
  return _recordTestImage(
    size: const Size(20, 20),
    painter: (final Canvas canvas) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 20, 20),
        Paint()..color = const Color(0xFFFFFFFF),
      );
    },
  );
}

/// Creates a white ring with a black hole for contour-path testing.
Future<ui.Image> _createRingTestImage() async {
  return _recordTestImage(
    size: _ringImageSize,
    painter: (final Canvas canvas) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, _ringImageSize.width, _ringImageSize.height),
        Paint()..color = const Color(0xFF000000),
      );
      canvas.drawRect(
        _ringOuterRect,
        Paint()..color = const Color(0xFFFFFFFF),
      );
      canvas.drawRect(
        _ringInnerRect,
        Paint()..color = const Color(0xFF000000),
      );
    },
  );
}

/// Creates two white pixels that only touch at one diagonal corner.
Future<ui.Image> _createDiagonalTouchImage() async {
  return _recordTestImage(
    size: _diagonalImageSize,
    painter: (final Canvas canvas) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, _diagonalImageSize.width, _diagonalImageSize.height),
        Paint()..color = const Color(0xFF000000),
      );
      canvas.drawRect(
        _firstDiagonalPixelRect,
        Paint()..color = const Color(0xFFFFFFFF),
      );
      canvas.drawRect(
        _secondDiagonalPixelRect,
        Paint()..color = const Color(0xFFFFFFFF),
      );
    },
  );
}

/// Records one synthetic test image at [size] using [painter].
Future<ui.Image> _recordTestImage({
  required final Size size,
  required final void Function(Canvas canvas) painter,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  painter(canvas);
  final ui.Picture picture = recorder.endRecording();
  return picture.toImage(size.width.toInt(), size.height.toInt());
}
