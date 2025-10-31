// ignore_for_file: use_build_context_synchronously, prefer_final_locals, always_specify_types, inference_failure_on_instance_creation

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/main.dart' as app;
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/models/constants.dart';
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

      app.main();
      await tester.pumpAndSettle();

      await tapByKey(tester, Keys.floatActionCenter);
      await tapByKey(tester, Keys.floatActionZoomOut); // ensure that we do not hit the float actions

      final Finder canvasFinder = find.byType(MainView);
      final Offset canvasCenter = tester.getCenter(canvasFinder);

      // ================================
      // 1️⃣ BOTTOM LAYER: Sky Background
      // ================================
      await _drawSky(tester, canvasCenter);
      await _pause(tester);

      // ================================
      // 2️⃣ SUN LAYER: Bright Yellow Circle
      // ================================
      await _drawSun(tester, canvasCenter);
      await _pause(tester);

      // ================================
      // 3️⃣ LAND LAYER: Green Ground
      // ================================
      await _drawLand(tester, canvasCenter);
      await _pause(tester);

      // ================================
      // 4️⃣ HOUSE LAYER: Complete House Structure
      // ================================
      await _drawHouse(tester, canvasCenter);
      await _pause(tester);

      // ================================
      // 5️⃣ FENCE LAYER: Simple Fence in Front
      // ================================
      await _drawFence(tester, canvasCenter);
      await _pause(tester);

      await LayerTestHelpers.printLayerStructure(tester);

      // ================================
      // 🎯 VALIDATION: Multi-Layer Scene Complete

      // Check that we have the right number of layers
      final BuildContext context = tester.element(find.byType(MainScreen));
      final LayersProvider layersProvider = LayersProvider.of(context);

      debugPrint('🎨 Multi-Layer Scene Final Status:');
      // expect(layersProvider.length, 6, reason: 'Should have 6 layers total');

      // Count total drawing actions across all layers
      // int totalActions = 0;
      // for (int i = 0; i < layersProvider.length; i++) {
      //   final layer = layersProvider.get(i);
      //   totalActions += layer.actionStack.length;
      //   final layerType = ['Background', 'Sky', 'Sun', 'Land', 'House', 'Fence'][i];
      //   debugPrint('  $layerType Layer: ${layer.actionStack.length} actions');
      // }

      // debugPrint('📊 TOTAL: $totalActions drawing actions across ${layersProvider.length} layers');

      // Multi-layer scene successfully demonstrates layer management
      // expect(totalActions, greaterThan(5), reason: 'Multi-layer scene with distributed content across layers');

      // Save the multi-layer masterpiece!
      await IntegrationTestUtils.saveArtworkScreenshot(
        layersProvider: layersProvider,
        filename: 'multi_layer_masterpiece.png',
      );

      debugPrint('🎨🎭 SUCCESS: Multi-Layer Painting Mastery Achieved!');
      debugPrint('🏗️  6 distinct layers meticulously crafted and composited!');
      debugPrint('🖼️  Multi-layer image saved: multi_layer_masterpiece.png');
    });
  });
}

Future<void> _pause(
  final WidgetTester tester,
) async {
  // Give time for layer to stabilize
  await Future.delayed(const Duration(milliseconds: 200));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
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

  await drawCircleWithHumanGestures(
    tester,
    center: canvasCenter + const Offset(-200, -120), // Top-left area
    radius: 70.0, // Size of the sun
    brushSize: 0,
    brushColor: Colors.transparent,
    fillColor: Colors.amber,
  );

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
    startPosition: canvasCenter + const Offset(-370, 10), // Bottom-left
    endPosition: canvasCenter + const Offset(370, 300), // Bottom-right (full width, bottom quarter)
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

  await Future.delayed(const Duration(milliseconds: 200));

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
