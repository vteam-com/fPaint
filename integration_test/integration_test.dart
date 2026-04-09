// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/main.dart' as app;
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'integration_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('fPaint Integration Tests', () {
    testWidgets('Multi-Layer Painting Mastery - Complete Scene', (final WidgetTester tester) async {
      debugPrint('🎨🖼️  Testing Multi-Layer Painting Mastery - Creating Complete 6-Layer Scene');

      // Mock shared preferences to ensure clean test environment
      // This prevents using engineer's existing preferences and ensures consistent test behavior
      SharedPreferences.setMockInitialValues(<String, Object>{});
      debugPrint('🧹 Shared preferences mocked for clean test environment');

      await app.main();
      await tester.pumpAndSettle();

      await tapByKey(tester, Keys.floatActionCenter);
      await tapByKey(tester, Keys.floatActionZoomOut); // ensure that we do not hit the float actions

      final Finder canvasFinder = find.byType(MainView);
      final Offset canvasCenter = tester.getCenter(canvasFinder);

      // ================================
      // 1️⃣ BOTTOM LAYER: Sky Background
      // ================================
      await _drawSky(tester, canvasCenter);

      // ================================
      // 2️⃣ SUN LAYER: Bright Yellow Circle
      // ================================
      await _drawSun(tester, canvasCenter);

      // ================================
      // 3️⃣ LAND LAYER: Green Ground
      // ================================
      await _drawLand(tester, canvasCenter);

      // ================================
      // 4️⃣ HOUSE LAYER: Complete House Structure
      // ================================
      await _drawHouse(tester, canvasCenter);

      // ================================
      // 5️⃣ FENCE LAYER: Simple Fence in Front
      // ================================
      await _drawFence(tester, canvasCenter);

      // ================================
      // 📐 CANVAS RESIZE: Crop to square (half height, centered)
      // ================================
      await _resizeCanvasToSquare(tester);

      // ================================
      // 🖼️ BLACK FRAME: Draw border to confirm crop bounds
      // ================================
      await _drawBlackFrame(tester);

      await LayerTestHelpers.printLayerStructure(tester);

      // ================================
      // 🎯 VALIDATION: Multi-Layer Scene Complete

      // Check that we have the right number of layers
      final BuildContext context = tester.element(find.byType(MainScreen));
      final LayersProvider layersProvider = LayersProvider.of(context);

      debugPrint('🎨 Multi-Layer Scene Final Status:');

      // Save the multi-layer masterpiece!
      await IntegrationTestUtils.saveArtworkScreenshot(
        layersProvider: layersProvider,
        filename: 'multi_layer_masterpiece.png',
      );
    });
  });
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

/// Resizes the canvas to a square using half the current height, centered.
Future<void> _resizeCanvasToSquare(final WidgetTester tester) async {
  debugPrint('📐 Resizing canvas to centered square (half height)...');

  final BuildContext context = tester.element(find.byType(MainScreen));
  final LayersProvider layersProvider = LayersProvider.of(context);
  final double halfHeight = (layersProvider.size.height / 2).roundToDouble();
  final String squareSize = halfHeight.toInt().toString();

  debugPrint('📐 Current canvas: ${layersProvider.size} → target: ${squareSize}x$squareSize');

  // Open menu → Canvas...
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Canvas...'));
  await tester.pumpAndSettle();

  // Disable aspect-ratio lock so width/height can be set independently.
  final Finder lockButton = find.byIcon(Icons.link);
  if (lockButton.evaluate().isNotEmpty) {
    await tester.tap(lockButton.first);
    await tester.pumpAndSettle();
  }

  // Enter square dimensions (half height × half height).
  final Finder widthField = find.widgetWithText(TextField, 'Width');
  final Finder heightField = find.widgetWithText(TextField, 'Height');
  expect(widthField, findsOneWidget);
  expect(heightField, findsOneWidget);

  await tester.enterText(widthField, squareSize);
  await tester.pump();
  await tester.enterText(heightField, squareSize);
  await tester.pump();

  // Apply (center anchor is the default).
  await tester.tap(find.widgetWithText(ElevatedButton, 'Apply'));
  await tester.pumpAndSettle();

  expect(layersProvider.size, Size(halfHeight, halfHeight));
  debugPrint('📐 Canvas resized to ${layersProvider.size}');
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
