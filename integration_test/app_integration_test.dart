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
    testWidgets('Human-Like Rectangle Drawing - Complete House', (final WidgetTester tester) async {
      debugPrint('🏠 Testing Human-Simulated Complete House Drawing');

      app.main();
      await tester.pumpAndSettle();

      final Finder canvasFinder = find.byType(MainView);
      final Offset canvasCenter = tester.getCenter(canvasFinder);

      // Simulate natural human drawing of a house
      // sequence with realistic timing

      // First Rectangle: Main house structure (200x100)
      await drawRectangleWithHumanGestures(
        tester,
        startPosition: canvasCenter,
        endPosition: canvasCenter + const Offset(200, 100),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Second Rectangle: Door (20x40)
      await drawRectangleWithHumanGestures(
        tester,
        startPosition: canvasCenter + const Offset(130, 24),
        endPosition: canvasCenter + const Offset(180, 88),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Third Rectangle: Window (30x25) - Test optional color parameters
      await drawRectangleWithHumanGestures(
        tester,
        startPosition: canvasCenter + const Offset(20, 30),
        endPosition: canvasCenter + const Offset(80, 50),
        brushSize: 8.0, // Thicker outline
        brushColor: Colors.red, // Red outline
        fillColor: Colors.blue, // Blue fill
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Roof: Two lines forming a triangular roof above the house
      debugPrint('🏠 Adding roof lines to complete the house...');

      // Left roof line (from house top-left to peak)
      await drawLineWithHumanGestures(
        tester,
        startPosition: canvasCenter + const Offset(-5, 0), // Top-left of house structure
        endPosition: canvasCenter + const Offset(100, -100), // Peak point above center
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Right roof line (from house top-right to peak)
      await drawLineWithHumanGestures(
        tester,
        startPosition: canvasCenter + const Offset(205, 0), // Top-right of house structure
        endPosition: canvasCenter + const Offset(100, -100), // Same peak point
      );

      // Validation: Verify complete house is drawn (3 rectangles + 2 roof lines = 5 elements)
      final BuildContext context = tester.element(find.byType(MainScreen));
      final AppProvider appProvider = AppProvider.of(context);

      expect(
        appProvider.layers.selectedLayer.actionStack.length,
        5,
        reason: 'Complete house: 3 rectangles (structure, door, window) + 2 roof lines',
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
