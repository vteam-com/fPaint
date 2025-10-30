// ignore_for_file: use_build_context_synchronously, prefer_final_locals, always_specify_types, inference_failure_on_instance_creation

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/main.dart' as app;
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:integration_test/integration_test.dart';

import 'integration_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('fPaint Integration Tests', () {
    testWidgets('Multi-Layer Painting Mastery - Complete Scene', (final WidgetTester tester) async {
      debugPrint('🎨🖼️  Testing Multi-Layer Painting Mastery - Creating Complete 6-Layer Scene');

      app.main();
      await tester.pumpAndSettle();

      final Finder canvasFinder = find.byType(MainView);
      final Offset canvasCenter = tester.getCenter(canvasFinder);

      // Initialize layer management - we should start with a default white background layer
      await LayerTestHelpers.printLayerStructure(tester);

      // ================================
      // 1️⃣ BOTTOM LAYER: Sky Background
      // ================================
      debugPrint('🌤️  LAYER 1: Creating Sky Background Layer - Full canvas gradient');
      await LayerTestHelpers.addNewLayer(tester, 'Sky'); // Added as top layer
      await LayerTestHelpers.printLayerStructure(tester);

      // Give time for first layer to stabilize before drawing
      await Future.delayed(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Create gradient sky effect using multiple rectangle layers
      debugPrint('🎨🌤️ Creating blue sky gradient with layered rectangles...');

      // Deep blue top layer (highest point)
      await drawRectangleWithHumanGestures(
        tester,
        startPosition: const Offset(0, 0), // Top-left
        endPosition: const Offset(1024, 200), // Top strip
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Medium blue middle layer
      await drawRectangleWithHumanGestures(
        tester,
        startPosition: const Offset(0, 200), // Middle-top
        endPosition: const Offset(1024, 500), // Middle section
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Light blue/cyan bottom layer
      await drawRectangleWithHumanGestures(
        tester,
        startPosition: const Offset(0, 500), // Bottom-top
        endPosition: const Offset(1024, 600), // Bottom section (before land starts)
      );

      debugPrint('🌤️ Blue sky gradient created with layered rectangles!');
      await Future.delayed(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // ================================
      // 2️⃣ SUN LAYER: Bright Yellow Circle
      // ================================
      debugPrint('☀️  LAYER 2: Creating Sun Layer - Bright circle');
      await LayerTestHelpers.addNewLayer(tester, 'Sun'); // Added as top layer (currently selected)

      // Give extra time for layer to settle before drawing
      await Future.delayed(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      await drawCircleWithHumanGestures(
        tester,
        center: canvasCenter + const Offset(-200, -120), // Top-left area
        radius: 70.0, // Size of the sun
      );

      await Future.delayed(const Duration(milliseconds: 500));

      // ================================
      // 3️⃣ LAND LAYER: Green Ground
      // ================================
      debugPrint('🌱 LAYER 3: Creating Land Layer - Green ground');
      await LayerTestHelpers.addNewLayer(tester, 'Land'); // Added as top layer (currently selected)

      // Extra stabilization before drawing on new layer
      await Future.delayed(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Draw ground: Large green rectangle covering bottom of canvas
      await drawRectangleWithHumanGestures(
        tester,
        startPosition: const Offset(0, 600), // Bottom-left
        endPosition: const Offset(1024, 768), // Bottom-right (full width, bottom quarter)
      );

      await Future.delayed(const Duration(milliseconds: 500));

      // ================================
      // 4️⃣ HOUSE LAYER: Complete House Structure
      // ================================
      debugPrint('🏠 LAYER 4: Creating House Layer - Complete house with roof');
      await LayerTestHelpers.addNewLayer(tester, 'House'); // Added as top layer (currently selected)

      // Stabilization before complex house drawing
      await Future.delayed(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Main house structure
      await drawRectangleWithHumanGestures(
        tester,
        startPosition: canvasCenter,
        endPosition: canvasCenter + const Offset(200, 100),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Door
      await drawRectangleWithHumanGestures(
        tester,
        startPosition: canvasCenter + const Offset(130, 24),
        endPosition: canvasCenter + const Offset(180, 88),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Window
      await drawRectangleWithHumanGestures(
        tester,
        startPosition: canvasCenter + const Offset(20, 30),
        endPosition: canvasCenter + const Offset(80, 50),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Roof: Three lines forming closed triangle
      debugPrint('🏠📐 Adding triangular roof to house...');

      // Left roof line
      await drawLineWithHumanGestures(
        tester,
        startPosition: canvasCenter + const Offset(-5, 0),
        endPosition: canvasCenter + const Offset(100, -100),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Right roof line
      await drawLineWithHumanGestures(
        tester,
        startPosition: canvasCenter + const Offset(205, 0),
        endPosition: canvasCenter + const Offset(100, -100),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Bottom roof line (closes triangle)
      await drawLineWithHumanGestures(
        tester,
        startPosition: canvasCenter + const Offset(-5, 0),
        endPosition: canvasCenter + const Offset(205, 0),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Skip flood fill for now - would require complex UI-based gradient configuration
      debugPrint('🎨🏠 Skipping roof gradient fill - requires UI-based gradient setup');
      await Future.delayed(const Duration(milliseconds: 300));

      // ================================
      // 5️⃣ FENCE LAYER: Simple Fence in Front
      // ================================
      debugPrint('🚧 LAYER 5: Creating Fence Layer - Pickets in front of house');
      await LayerTestHelpers.addNewLayer(tester, 'Fence'); // Layer 4 (fence)
      await LayerTestHelpers.switchToLayer(tester, 5);

      // Simple fence pattern: vertical lines with horizontal rail
      const double fenceY = 650.0; // Bottom area
      const double fenceHeight = 80.0;

      // Draw 8 fence pickets
      for (int i = 0; i < 8; i++) {
        final double picketX = -200 + (i * 80); // Spacing between pickets
        await drawLineWithHumanGestures(
          tester,
          startPosition: canvasCenter + Offset(picketX, fenceY),
          endPosition: canvasCenter + Offset(picketX, fenceY - fenceHeight),
        );
      }

      await Future.delayed(const Duration(milliseconds: 200));

      // Horizontal rail at top of fence
      await drawLineWithHumanGestures(
        tester,
        startPosition: const Offset(180, fenceY - fenceHeight + 20),
        endPosition: const Offset(820, fenceY - fenceHeight + 20),
      );

      await Future.delayed(const Duration(milliseconds: 300));

      await LayerTestHelpers.printLayerStructure(tester);

      // ================================
      // 🎯 VALIDATION: Multi-Layer Scene Complete

      // Check that we have the right number of layers
      final BuildContext context = tester.element(find.byType(MainScreen));
      final LayersProvider layersProvider = LayersProvider.of(context);

      debugPrint('🎨 Multi-Layer Scene Final Status:');
      expect(layersProvider.length, 6, reason: 'Should have 6 layers total');
      expect(layersProvider.selectedLayerIndex, 5, reason: 'Should be on the top layer (fence)');

      // Count total drawing actions across all layers
      int totalActions = 0;
      for (int i = 0; i < layersProvider.length; i++) {
        final layer = layersProvider.get(i);
        totalActions += layer.actionStack.length;
        final layerType = ['Background', 'Sky', 'Sun', 'Land', 'House', 'Fence'][i];
        debugPrint('  $layerType Layer: ${layer.actionStack.length} actions');
      }

      debugPrint('📊 TOTAL: $totalActions drawing actions across ${layersProvider.length} layers');

      // Multi-layer scene successfully demonstrates layer management
      expect(totalActions, greaterThan(5), reason: 'Multi-layer scene with distributed content across layers');

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
