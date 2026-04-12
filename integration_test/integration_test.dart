// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/main.dart' as app;
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/transform_model.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'integration_helpers.dart';

const String _englishLanguageCode = 'en';
const Map<String, Object> _integrationTestPreferences = <String, Object>{
  AppPreferences.keyLanguageCode: _englishLanguageCode,
};
const String _aggregatedIntegrationTestName = 'Aggregated Painting Mastery - Multi-Layer Scene And Bird Transforms';
const String _birdsLayerName = 'Birds';
const String _finalArtworkFilename = 'integration_test_final_artwork.jpg';
const String _finalRenderedFilename = 'integration_test_final_rendered.jpg';
const String _applyTooltipText = 'Apply';
const String _scaleTooltipText = 'Scale';
const String _rotateTooltipText = 'Resize / Rotate';
const Size _defaultCanvasSize = Size(
  AppLayout.canvasDefaultWidth,
  AppLayout.canvasDefaultHeight,
);
const int _birdCopyCount = 3;
const double _birdBrushSize = 4.0;
const double _birdSelectionWidth = 60.0;
const double _birdSelectionHeight = 28.0;
const double _screenPositionTolerance = 4.0;
const double _transformChangeTolerance = 1.0;
const double _transformScaleDragFactor = 0.55;
const double _transformRotateDragFactor = 0.4;
const Duration _clipboardPumpDuration = Duration(milliseconds: 300);
const Duration _overlayActionPumpDuration = Duration(milliseconds: 300);
const Offset _birdOriginalTopLeftOffset = Offset(80, -170);
const Offset _birdScaledCopyTopLeftOffset = Offset(180, -210);
const Offset _birdRotatedCopyTopLeftOffset = Offset(250, -150);
const Offset _birdTransformedCopyTopLeftOffset = Offset(330, -205);
const Offset _birdLine1Start = Offset(4, 18);
const Offset _birdLine1End = Offset(18, 4);
const Offset _birdLine2Start = Offset(18, 4);
const Offset _birdLine2End = Offset(30, 18);
const Offset _birdLine3Start = Offset(30, 18);
const Offset _birdLine3End = Offset(42, 6);
const Offset _birdLine4Start = Offset(42, 6);
const Offset _birdLine4End = Offset(56, 18);
const Offset _birdSelectionSizeOffset = Offset(_birdSelectionWidth, _birdSelectionHeight);
const Offset _birdDeformDelta = Offset(18, -14);

enum _BirdTransformVariant {
  scale,
  rotate,
  deform,
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('fPaint Integration Tests', () {
    testWidgets(_aggregatedIntegrationTestName, (final WidgetTester tester) async {
      debugPrint('🎨🖼️  Testing aggregated integration flow');

      await _launchIntegrationTestApp(tester);
      await _runMultiLayerSceneScenario(tester);
      await _resetCanvasForBirdScenario(tester);
      await _runBirdTransformScenario(tester);
      await _saveFinalAggregatedScreenshots(tester);
    });
  });
}

Future<void> _launchIntegrationTestApp(final WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(_integrationTestPreferences);
  debugPrint('🧹 Shared preferences mocked for clean test environment');

  await configureTabletLandscapeViewport(tester);

  await app.main();
  await tester.pumpAndSettle();

  await prepareCanvasViewport(tester);
}

Future<void> _runMultiLayerSceneScenario(final WidgetTester tester) async {
  debugPrint('🎨 Running multi-layer scene scenario');

  final Offset canvasCenter = tester.getCenter(find.byType(MainView));

  await _drawSky(tester, canvasCenter);
  await _drawSun(tester, canvasCenter);
  await _drawLand(tester, canvasCenter);
  await _drawHouse(tester, canvasCenter);
  await _drawFence(tester, canvasCenter);

  final int layerCountBeforeCrop = LayersProvider.of(
    tester.element(find.byType(MainScreen)),
  ).length;
  await _resizeCanvasToSquare(tester);
  _validateCrop(tester, layerCountBeforeCrop);
  await _drawBlackFrame(tester);
  await LayerTestHelpers.printLayerStructure(tester);
}

Future<void> _resetCanvasForBirdScenario(final WidgetTester tester) async {
  debugPrint('🧹 Resetting canvas for bird transform scenario');

  final AppProvider appProvider = _appProvider(tester);
  appProvider.canvasClear(_defaultCanvasSize);
  appProvider.update();

  await tester.pumpAndSettle();
  await prepareCanvasViewport(tester);
}

Future<void> _runBirdTransformScenario(final WidgetTester tester) async {
  debugPrint('🐦 Running bird transform scenario');

  final Offset canvasCenter = tester.getCenter(find.byType(MainView));

  await _drawSky(tester, canvasCenter);
  await _drawSun(tester, canvasCenter);
  await _drawLand(tester, canvasCenter);
  await _drawHouse(tester, canvasCenter);
  await _drawBirdLayer(tester, canvasCenter);

  final BuildContext context = tester.element(find.byType(MainScreen));
  final LayersProvider layersProvider = LayersProvider.of(context);
  final AppProvider appProvider = AppProvider.of(context, listen: false);
  final int layerCountBeforeBirdCopies = layersProvider.length;

  await _pasteAndTransformBirdCopy(
    tester,
    canvasCenter: canvasCenter,
    targetTopLeft: canvasCenter + _birdScaledCopyTopLeftOffset,
    variant: _BirdTransformVariant.scale,
  );
  await _pasteAndTransformBirdCopy(
    tester,
    canvasCenter: canvasCenter,
    targetTopLeft: canvasCenter + _birdRotatedCopyTopLeftOffset,
    variant: _BirdTransformVariant.rotate,
  );
  await _pasteAndTransformBirdCopy(
    tester,
    canvasCenter: canvasCenter,
    targetTopLeft: canvasCenter + _birdTransformedCopyTopLeftOffset,
    variant: _BirdTransformVariant.deform,
  );

  expect(
    layersProvider.length,
    layerCountBeforeBirdCopies + _birdCopyCount,
    reason: 'Each pasted bird copy should commit as its own layer',
  );
  expect(appProvider.imagePlacementModel.isVisible, isFalse);
  expect(appProvider.transformModel.isVisible, isFalse);
  expect(appProvider.selectorModel.isVisible, isFalse);

  await LayerTestHelpers.printLayerStructure(tester);
}

Future<void> _saveFinalAggregatedScreenshots(final WidgetTester tester) async {
  final BuildContext context = tester.element(find.byType(MainScreen));
  final LayersProvider layersProvider = LayersProvider.of(context);

  debugPrint('📸 Saving final aggregated screenshots');

  await IntegrationTestUtils.saveArtworkScreenshot(
    layersProvider: layersProvider,
    filename: _finalArtworkFilename,
  );
  await IntegrationTestUtils.saveRenderedViewScreenshot(
    tester: tester,
    filename: _finalRenderedFilename,
  );
  await Future<void>.delayed(AppDefaults.integrationEvidenceCollectionDelay);
}

/// Draws the sky background layer with a blue gradient
Future<void> _drawSky(final WidgetTester tester, final Offset canvasCenter) async {
  debugPrint('🌤️ Drawing sky background with gradient...');

  await LayerTestHelpers.addNewLayer(tester, 'Sky');
  await LayerTestHelpers.printLayerStructure(tester);

  // Apply gradient fill in the center of the canvas
  await performFloodFillGradient(
    tester,
    gradientMode: FillMode.linear,
    gradientPoints: <GradientPoint>[
      GradientPoint(
        color: const Color.fromARGB(255, 34, 97, 168),
        offset: canvasCenter + const Offset(0, -240),
      ), // Light blue at top relative to center
      GradientPoint(
        color: const Color.fromARGB(255, 110, 161, 219),
        offset: canvasCenter + const Offset(0, -20),
      ), // Dark blue at bottom relative to center
    ],
  );

  debugPrint('🌤️ Sky gradient background completed!');
}

/// Draws the sun as a bright yellow circle
Future<void> _drawSun(final WidgetTester tester, final Offset canvasCenter) async {
  debugPrint('☀️ Drawing bright sun circle...');

  await LayerTestHelpers.addNewLayer(tester, 'Sun');
  await LayerTestHelpers.printLayerStructure(tester);

  final Offset sunCenter = canvasCenter + const Offset(-200, -120); // Top-left area

  // Add sun rays using circle selection and gradient fill
  await _addSunRays(tester, sunCenter, 400);
  await myWait(tester);

  // Draw the main sun circle
  await drawCircleWithHumanGestures(
    tester,
    center: sunCenter,
    radius: 70.0,
    brushSize: 0,
    brushColor: Colors.transparent,
    fillColor: const Color.fromARGB(179, 241, 226, 179),
  );
  await myWait(tester);

  debugPrint('☀️ Sun circle completed!');
}

/// Draws the land/ground as a large green rectangle
Future<void> _drawLand(final WidgetTester tester, final Offset canvasCenter) async {
  debugPrint('🌱 Drawing green land ground...');

  await LayerTestHelpers.addNewLayer(tester, 'Land');

  // Stabilization before drawing
  await tester.pumpAndSettle();

  // Draw ground: Large green rectangle covering bottom of canvas
  await drawRectangleWithHumanGestures(
    tester,
    startPosition: canvasCenter + const Offset(-300, 10), // Bottom-left (stay within canvas bounds)
    endPosition: canvasCenter + const Offset(300, 300), // Bottom-right (full width, bottom quarter)
    brushSize: 1,
    brushColor: Colors.greenAccent,
    fillColor: Colors.green,
  );

  debugPrint('🌱 Land ground completed!');
}

/// Draws a complete house structure with main building, door, window, and roof
Future<void> _drawHouse(final WidgetTester tester, final Offset canvasCenter) async {
  debugPrint('🏠 Drawing complete house structure...');

  await LayerTestHelpers.addNewLayer(tester, 'House');

  // Main house structure
  await drawRectangleWithHumanGestures(
    tester,
    startPosition: canvasCenter,
    endPosition: canvasCenter + const Offset(200, 100),
    brushSize: 1,
    brushColor: Colors.white,
    fillColor: const Color.fromARGB(255, 248, 163, 191),
  );

  // Door
  await drawRectangleWithHumanGestures(
    tester,
    startPosition: canvasCenter + const Offset(130, 24),
    endPosition: canvasCenter + const Offset(180, 88),
    brushSize: 2,
    brushColor: Colors.white,
    fillColor: Colors.red,
  );

  // Window
  await drawRectangleWithHumanGestures(
    tester,
    startPosition: canvasCenter + const Offset(20, 30),
    endPosition: canvasCenter + const Offset(80, 50),
    brushSize: 2,
    brushColor: Colors.white,
    fillColor: Colors.grey,
  );

  // Roof: Three lines forming closed triangle
  debugPrint('🏠📐 Adding triangular roof...');

  // Left roof line
  await drawLineWithHumanGestures(
    tester,
    startPosition: canvasCenter + const Offset(-5, 0),
    endPosition: canvasCenter + const Offset(100, -100),
    brushSize: 1,
    brushColor: Colors.orange,
  );

  // Right roof line
  await drawLineWithHumanGestures(
    tester,
    startPosition: canvasCenter + const Offset(205, 0),
    endPosition: canvasCenter + const Offset(100, -100),
    brushSize: 1,
    brushColor: Colors.orange,
  );

  // Bottom roof line (closes triangle)
  await drawLineWithHumanGestures(
    tester,
    startPosition: canvasCenter + const Offset(-5, 0),
    endPosition: canvasCenter + const Offset(205, 0),
    brushSize: 1,
    brushColor: Colors.orange,
  );

  // Fill the roof triangle with orange gradient
  debugPrint('🏠🎨 Filling roof with gradient...');
  await performFloodFillSolid(
    tester,
    position: canvasCenter + const Offset(50, -50),
    color: const Color.fromARGB(255, 183, 104, 19),
  );

  debugPrint('🏠 House with roof completed!');
}

Future<void> _drawBirdLayer(final WidgetTester tester, final Offset canvasCenter) async {
  await LayerTestHelpers.addNewLayer(tester, _birdsLayerName);

  final Offset birdTopLeft = canvasCenter + _birdOriginalTopLeftOffset;

  await drawLineWithHumanGestures(
    tester,
    startPosition: birdTopLeft + _birdLine1Start,
    endPosition: birdTopLeft + _birdLine1End,
    brushSize: _birdBrushSize,
    brushColor: Colors.black,
  );
  await drawLineWithHumanGestures(
    tester,
    startPosition: birdTopLeft + _birdLine2Start,
    endPosition: birdTopLeft + _birdLine2End,
    brushSize: _birdBrushSize,
    brushColor: Colors.black,
  );
  await drawLineWithHumanGestures(
    tester,
    startPosition: birdTopLeft + _birdLine3Start,
    endPosition: birdTopLeft + _birdLine3End,
    brushSize: _birdBrushSize,
    brushColor: Colors.black,
  );
  await drawLineWithHumanGestures(
    tester,
    startPosition: birdTopLeft + _birdLine4Start,
    endPosition: birdTopLeft + _birdLine4End,
    brushSize: _birdBrushSize,
    brushColor: Colors.black,
  );
}

Future<void> _pasteAndTransformBirdCopy(
  final WidgetTester tester, {
  required final Offset canvasCenter,
  required final Offset targetTopLeft,
  required final _BirdTransformVariant variant,
}) async {
  await LayerTestHelpers.switchToLayerByName(tester, _birdsLayerName);

  final Rect originalBirdRect = _birdRectAt(canvasCenter + _birdOriginalTopLeftOffset);
  await selectRectangleArea(
    tester,
    startPosition: originalBirdRect.topLeft,
    endPosition: originalBirdRect.bottomRight,
  );

  final AppProvider appProvider = _appProvider(tester);
  await appProvider.regionCopy();
  await tester.pump(_clipboardPumpDuration);
  await appProvider.paste();
  await tester.pump(_overlayActionPumpDuration);

  expect(appProvider.imagePlacementModel.isVisible, isTrue, reason: 'Paste should open image placement overlay');

  await _moveActiveImagePlacementTo(tester, targetTopLeft: targetTopLeft);
  await tapByTooltip(tester, _applyTooltipText);
  await tester.pump(_overlayActionPumpDuration);

  expect(appProvider.imagePlacementModel.isVisible, isFalse, reason: 'Pasted bird should be committed to a layer');

  final Rect pastedBirdRect = _birdRectAt(targetTopLeft);
  await selectRectangleArea(
    tester,
    startPosition: pastedBirdRect.topLeft,
    endPosition: pastedBirdRect.bottomRight,
  );

  await tapByKey(tester, Keys.toolTransform);
  await tester.pump(_overlayActionPumpDuration);

  expect(appProvider.transformModel.isVisible, isTrue, reason: 'Selected pasted bird should enter transform mode');

  switch (variant) {
    case _BirdTransformVariant.scale:
      await _applyScaleTransform(tester);
    case _BirdTransformVariant.rotate:
      await _applyRotateTransform(tester);
    case _BirdTransformVariant.deform:
      await _applyDeformTransform(tester);
  }

  await tapByTooltip(tester, _applyTooltipText);
  await tester.pump(_overlayActionPumpDuration);

  expect(appProvider.transformModel.isVisible, isFalse, reason: 'Transform should be committed after Apply');
  expect(appProvider.selectorModel.isVisible, isFalse, reason: 'Transform commit should clear the active selection');
}

Future<void> _moveActiveImagePlacementTo(
  final WidgetTester tester, {
  required final Offset targetTopLeft,
}) async {
  final AppProvider appProvider = _appProvider(tester);
  final Offset currentCenter = _imagePlacementCenterGlobal(tester, appProvider);
  final Offset targetCenter =
      targetTopLeft +
      Offset(
        appProvider.imagePlacementModel.displayWidth * appProvider.layers.scale / AppMath.pair,
        appProvider.imagePlacementModel.displayHeight * appProvider.layers.scale / AppMath.pair,
      );

  await dragLikeHuman(tester, currentCenter, targetCenter);
  await tester.pump();

  final Offset updatedTopLeft = _imagePlacementTopLeftGlobal(tester, appProvider);
  expect(updatedTopLeft.dx, moreOrLessEquals(targetTopLeft.dx, epsilon: _screenPositionTolerance));
  expect(updatedTopLeft.dy, moreOrLessEquals(targetTopLeft.dy, epsilon: _screenPositionTolerance));
}

Future<void> _applyScaleTransform(final WidgetTester tester) async {
  final AppProvider appProvider = _appProvider(tester);
  final Rect initialBounds = appProvider.transformModel.quadBounds;
  final Offset transformCenter = _transformCenterGlobal(tester, appProvider);
  final Offset scaleControlCenter = tester.getCenter(find.byTooltip(_scaleTooltipText));
  final Offset scaleDelta = (scaleControlCenter - transformCenter) * _transformScaleDragFactor;

  await dragByTooltip(
    tester,
    tooltip: _scaleTooltipText,
    delta: scaleDelta,
  );

  final Rect updatedBounds = appProvider.transformModel.quadBounds;
  expect(appProvider.transformModel.isScaleMode, isTrue);
  expect(updatedBounds.width, greaterThan(initialBounds.width + _transformChangeTolerance));
  expect(updatedBounds.height, greaterThan(initialBounds.height + _transformChangeTolerance));
}

Future<void> _applyRotateTransform(final WidgetTester tester) async {
  final AppProvider appProvider = _appProvider(tester);
  final List<Offset> initialCorners = List<Offset>.of(appProvider.transformModel.corners);
  final Offset transformCenter = _transformCenterGlobal(tester, appProvider);
  final Offset rotateControlCenter = tester.getCenter(find.byTooltip(_rotateTooltipText));
  final Offset rotateVector = rotateControlCenter - transformCenter;
  final Offset rotateDelta = Offset(-rotateVector.dy, rotateVector.dx) * _transformRotateDragFactor;

  await dragByTooltip(
    tester,
    tooltip: _rotateTooltipText,
    delta: rotateDelta,
  );

  expect(appProvider.transformModel.isRotateMode, isTrue);
  expect(_cornersChanged(initialCorners, appProvider.transformModel.corners), isTrue);
}

Future<void> _applyDeformTransform(final WidgetTester tester) async {
  final AppProvider appProvider = _appProvider(tester);
  final Offset initialCorner = appProvider.transformModel.corners[TransformModel.topRightIndex];
  final Offset handlePosition = _transformCornerGlobal(
    tester,
    appProvider,
    TransformModel.topRightIndex,
  );

  await dragLikeHuman(tester, handlePosition, handlePosition + _birdDeformDelta);
  await tester.pump();

  final Offset updatedCorner = appProvider.transformModel.corners[TransformModel.topRightIndex];
  expect(appProvider.transformModel.isDeformMode, isTrue);
  expect((updatedCorner - initialCorner).distance, greaterThan(_transformChangeTolerance));
}

AppProvider _appProvider(final WidgetTester tester) {
  final BuildContext context = tester.element(find.byType(MainScreen));
  return AppProvider.of(context, listen: false);
}

Rect _birdRectAt(final Offset topLeft) {
  return Rect.fromPoints(topLeft, topLeft + _birdSelectionSizeOffset);
}

Offset _imagePlacementTopLeftGlobal(final WidgetTester tester, final AppProvider appProvider) {
  return _mainViewTopLeft(tester) + appProvider.fromCanvas(appProvider.imagePlacementModel.position);
}

Offset _imagePlacementCenterGlobal(final WidgetTester tester, final AppProvider appProvider) {
  return _mainViewTopLeft(tester) +
      appProvider.fromCanvas(
        appProvider.imagePlacementModel.position +
            Offset(
              appProvider.imagePlacementModel.displayWidth / AppMath.pair,
              appProvider.imagePlacementModel.displayHeight / AppMath.pair,
            ),
      );
}

Offset _transformCenterGlobal(final WidgetTester tester, final AppProvider appProvider) {
  return _mainViewTopLeft(tester) + appProvider.fromCanvas(appProvider.transformModel.center);
}

Offset _transformCornerGlobal(
  final WidgetTester tester,
  final AppProvider appProvider,
  final int cornerIndex,
) {
  return _mainViewTopLeft(tester) + appProvider.fromCanvas(appProvider.transformModel.corners[cornerIndex]);
}

Offset _mainViewTopLeft(final WidgetTester tester) {
  return tester.getTopLeft(find.byType(MainView));
}

bool _cornersChanged(final List<Offset> previousCorners, final List<Offset> updatedCorners) {
  return List<int>.generate(previousCorners.length, (final int index) => index).any(
    (final int index) => (updatedCorners[index] - previousCorners[index]).distance > _transformChangeTolerance,
  );
}

/// Resizes the canvas to a square using half the current height, centered.
Future<void> _resizeCanvasToSquare(final WidgetTester tester) async {
  debugPrint('📐 Resizing canvas to centered square (half height)...');

  final BuildContext context = tester.element(find.byType(MainScreen));
  final LayersProvider layersProvider = LayersProvider.of(context);
  final double halfHeight = (layersProvider.size.height / 2).roundToDouble();
  final String squareSize = halfHeight.toInt().toString();

  debugPrint('📐 Current canvas: ${layersProvider.size} → target: ${squareSize}x$squareSize');

  layersProvider.canvasResize(
    halfHeight.toInt(),
    halfHeight.toInt(),
    CanvasResizePosition.center,
  );
  await tester.pump();

  expect(layersProvider.size, Size(halfHeight, halfHeight));
  debugPrint('📐 Canvas resized to ${layersProvider.size}');
}

/// Validates that the crop operation resized the canvas and all layers correctly.
void _validateCrop(final WidgetTester tester, final int expectedLayerCount) {
  final BuildContext context = tester.element(find.byType(MainScreen));
  final LayersProvider layersProvider = LayersProvider.of(context);

  final Size canvasSize = layersProvider.size;

  // Canvas should be square
  expect(canvasSize.width, canvasSize.height, reason: 'Canvas should be square after crop');
  expect(canvasSize.width, greaterThan(0), reason: 'Canvas width must be positive');

  // All layers must survive the crop
  expect(layersProvider.length, expectedLayerCount, reason: 'Layer count must be preserved after crop');

  // Every layer must match the new canvas size
  for (int i = 0; i < layersProvider.length; i++) {
    final LayerProvider layer = layersProvider.get(i);
    expect(
      layer.size,
      canvasSize,
      reason: 'Layer "${layer.name}" (index $i) size must match canvas after crop',
    );
  }

  debugPrint(
    '✅ Crop validated: ${canvasSize.width.toInt()}x${canvasSize.height.toInt()}, '
    '$expectedLayerCount layers, all sizes match',
  );
}

/// Draws a black rectangle frame around the entire canvas to confirm crop bounds.
Future<void> _drawBlackFrame(final WidgetTester tester) async {
  debugPrint('🖼️ Drawing black frame around cropped canvas...');

  final BuildContext context = tester.element(find.byType(MainScreen));
  final LayersProvider layersProvider = LayersProvider.of(context);

  await LayerTestHelpers.addNewLayer(tester, 'Frame');

  final double w = layersProvider.size.width;
  final double h = layersProvider.size.height;
  const double inset = 4;

  // Convert canvas coordinates to widget-local coordinates for the MainView.
  // The Listener in CanvasGestureHandler receives localPosition relative to
  // the MainView widget, so we need: canvasOffset + canvas coords * scale,
  // then add the MainView's global top-left to get global test coordinates.
  final AppProvider appProvider = AppProvider.of(context, listen: false);
  final Finder mainViewFinder = find.byType(MainView);
  final Offset mainViewTopLeft = tester.getTopLeft(mainViewFinder);
  Offset toScreen(final Offset canvasPoint) =>
      mainViewTopLeft +
      Offset(
        canvasPoint.dx * appProvider.layers.scale + appProvider.canvasOffset.dx,
        canvasPoint.dy * appProvider.layers.scale + appProvider.canvasOffset.dy,
      );

  // Top edge
  await drawLineWithHumanGestures(
    tester,
    startPosition: toScreen(const Offset(inset, inset)),
    endPosition: toScreen(Offset(w - inset, inset)),
    brushSize: 4,
    brushColor: Colors.black,
  );

  // Right edge
  await drawLineWithHumanGestures(
    tester,
    startPosition: toScreen(Offset(w - inset, inset)),
    endPosition: toScreen(Offset(w - inset, h - inset)),
    brushSize: 4,
    brushColor: Colors.black,
  );

  // Bottom edge
  await drawLineWithHumanGestures(
    tester,
    startPosition: toScreen(Offset(w - inset, h - inset)),
    endPosition: toScreen(Offset(inset, h - inset)),
    brushSize: 4,
    brushColor: Colors.black,
  );

  // Left edge
  await drawLineWithHumanGestures(
    tester,
    startPosition: toScreen(Offset(inset, h - inset)),
    endPosition: toScreen(const Offset(inset, inset)),
    brushSize: 4,
    brushColor: Colors.black,
  );

  debugPrint('🖼️ Black frame completed!');
}

/// Adds sun rays by drawing filled rectangles radiating from the sun
Future<void> _addSunRays(final WidgetTester tester, final Offset sunCenter, final double sunRadius) async {
  debugPrint('☀️ Adding sun rays by drawing filled rectangles...');

  // Select circle
  // await selectCircleArea(tester, circleCenter: sunCenter, radius: sunRadius);
  // await myWait(tester);

  // await tester.pumpAndSettle(const Duration(seconds: 2));
  // debugPrintVisibleKeys();

  // Flood fill
  await performFloodFillGradient(
    tester,
    gradientMode: FillMode.linear,
    gradientPoints: <GradientPoint>[
      GradientPoint(
        color: const Color.fromARGB(255, 255, 242, 1),
        offset: sunCenter,
      ), // Light blue at top relative to center
      GradientPoint(
        color: const Color.fromARGB(59, 0, 28, 242),
        offset: sunCenter + Offset(sunRadius, sunRadius),
      ), // Dark blue at bottom relative to center
    ],
  );

  // await myWait(tester);

  // Cancel seletion
  // await tapByKey(tester, Keys.toolSelector);
  // await myWait(tester);

  // await tapByKey(tester, Keys.toolSelectorCancel);
  // await myWait(tester);

  debugPrint('☀️ Sun rays completed!');
}

/// Draws a fence with vertical pickets and horizontal rails
Future<void> _drawFence(final WidgetTester tester, final Offset canvasCenter) async {
  debugPrint('🚧 Drawing fence with pickets and rails...');

  await LayerTestHelpers.addNewLayer(tester, 'Fence');

  // Simple fence pattern: vertical lines with horizontal rails
  const double fenceY = 140; // Bottom area
  const double fenceHeight = 80.0;

  // Draw fence pickets (vertical lines)
  for (int i = 0; i < 7; i++) {
    final double picketX = -200 + (i * 80); // Spacing between pickets
    await drawLineWithHumanGestures(
      tester,
      startPosition: canvasCenter + Offset(picketX, fenceY),
      endPosition: canvasCenter + Offset(picketX, fenceY - fenceHeight),
      brushSize: 10,
      brushColor: Colors.white,
    );
  }

  // Draw horizontal rails
  await drawRectangleWithHumanGestures(
    tester,
    startPosition: canvasCenter + const Offset(-210, 80),
    endPosition: canvasCenter + const Offset(300, 90),
    brushSize: 1,
    brushColor: Colors.grey,
    fillColor: Colors.white,
  );

  await drawRectangleWithHumanGestures(
    tester,
    startPosition: canvasCenter + const Offset(-210, 110),
    endPosition: canvasCenter + const Offset(300, 120),
    brushSize: 1,
    brushColor: Colors.grey,
    fillColor: Colors.white,
  );

  debugPrint('🚧 Fence pickets and rails completed!');
}
