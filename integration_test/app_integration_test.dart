// ignore_for_file: use_build_context_synchronously, prefer_final_locals, always_specify_types, inference_failure_on_instance_creation

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/main.dart' as app;
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:integration_test/integration_test.dart';

import 'integration_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('fPaint Integration Tests', () {
    testWidgets('Human-Like Rectangle Drawing - Complete House', (final WidgetTester tester) async {
      debugPrint('🏠 Testing Human-Simulated Complete House Drawing');

      app.main();
      await tester.pumpAndSettle();

      final Finder canvasFinder = find.byType(MainView);
      final Offset canvasCenter = tester.getCenter(canvasFinder);

      // Simulate natural human drawing of a complete scene
      // sequence with realistic timing

      // Sun: Bright yellow circle in a more visible position
      debugPrint('☀️  Adding sun to brighten the scene...');
      await drawCircleWithHumanGestures(
        tester,
        center: canvasCenter + const Offset(-200, -120), // Top area, visible position
        radius: 50.0, // Size of the sun
        brushSize: 6.0,
        brushColor: Colors.orange, // Orange outline
        fillColor: Colors.yellow, // Yellow fill for the sun
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // First Rectangle: Main house structure (200x100)
      await drawRectangleWithHumanGestures(
        tester,
        startPosition: canvasCenter,
        endPosition: canvasCenter + const Offset(200, 100),
        brushSize: 0.0, // Thicker outline
        brushColor: Colors.black, // Red outline
        fillColor: const Color.fromARGB(255, 199, 143, 162), // Blue fill
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Second Rectangle: Door (20x40)
      await drawRectangleWithHumanGestures(
        tester,
        startPosition: canvasCenter + const Offset(130, 24),
        endPosition: canvasCenter + const Offset(180, 88),
        brushSize: 8.0, // Thicker outline
        brushColor: Colors.white, // Red outline
        fillColor: Colors.deepOrange, // Blue fill
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Third Rectangle: Window (30x25) - Test optional color parameters
      await drawRectangleWithHumanGestures(
        tester,
        startPosition: canvasCenter + const Offset(20, 30),
        endPosition: canvasCenter + const Offset(80, 50),
        brushSize: 8.0, // Thicker outline
        brushColor: Colors.white, // Red outline
        fillColor: const Color.fromARGB(255, 165, 181, 193),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Roof: Two lines forming a triangular roof above the house
      debugPrint('🏠 Adding roof lines to complete the house...');

      // Left roof line (from house top-left to peak)
      await drawLineWithHumanGestures(
        tester,
        startPosition: canvasCenter + const Offset(-5, 0), // Top-left of house structure
        endPosition: canvasCenter + const Offset(100, -100), // Peak point above center
        brushSize: 2.0, // Thicker outline
        brushColor: Colors.deepOrangeAccent, // Red outline
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Right roof line (from house top-right to peak)
      await drawLineWithHumanGestures(
        tester,
        startPosition: canvasCenter + const Offset(205, 0), // Top-right of house structure
        endPosition: canvasCenter + const Offset(100, -100), // Same peak point
        brushSize: 2.0, // Thicker outline
        brushColor: Colors.deepOrangeAccent, // Red outline
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Bottom roof line to close the triangular roof
      await drawLineWithHumanGestures(
        tester,
        startPosition: canvasCenter + const Offset(-5, 0), // Left roof base (same as left roof start)
        endPosition: canvasCenter + const Offset(205, 0), // Right roof base (same as right roof start)
        brushSize: 2.0,
        brushColor: Colors.deepOrangeAccent,
      );

      // Flood fill the closed triangular roof with linear gradient (white→pink→black, diagonal)
      debugPrint('🎨 Flood filling roof triangle with diagonal gradient...');

      // Create gradient points for white→pink→black diagonal using simpler coordinates
      final List<GradientPoint> gradientPoints = <GradientPoint>[
        GradientPoint(
          offset: const Offset(0.0, 0.0), // Left start: White
          color: Colors.white,
        ),
        GradientPoint(
          offset: const Offset(0.5, 0.5), // Center: Pink
          color: Colors.pink,
        ),
        GradientPoint(
          offset: const Offset(1.0, 1.0), // Right end: Black
          color: Colors.black,
        ),
      ];

      // Apply flood fill to a point inside the triangular roof
      final FillModel fillModel = FillModel();
      fillModel.mode = FillMode.linear; // Set to linear gradient mode
      await drawFloodFillGradient(
        tester,
        fillPosition: canvasCenter + const Offset(100, -30), // Point inside roof triangle area
        gradientPoints: gradientPoints,
        fillModel: fillModel,
      );

      // Validation: Verify complete scene is drawn (sun circle + 3 rectangles + 2 roof lines = 6 elements)
      final BuildContext context = tester.element(find.byType(MainScreen));
      final AppProvider appProvider = AppProvider.of(context);

      debugPrint('🎨 Final drawing elements created: ${appProvider.layers.selectedLayer.actionStack.length}');
      for (int i = 0; i < appProvider.layers.selectedLayer.actionStack.length; i++) {
        final action = appProvider.layers.selectedLayer.actionStack[i];
        debugPrint('  [$i] ${action.action}');
      }

      expect(
        appProvider.layers.selectedLayer.actionStack.length,
        8,
        reason:
            'Complete scene: 1 sun circle + 3 rectangles (house, door, window) + 3 roof lines (closed triangle) + 1 flood fill',
      );

      // Save the artwork
      await IntegrationTestUtils.saveArtworkScreenshot(
        appProvider: appProvider,
        filename: 'integration_test_artwork.png',
      );

      debugPrint('✅ SUCCESS: Human-like multi-rectangle drawing completed');
    });
  });
}
