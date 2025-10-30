// ignore_for_file: use_build_context_synchronously, prefer_final_locals, always_specify_types, inference_failure_on_instance_creation

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/export_download_non_web.dart';
import 'package:fpaint/main.dart' as app;
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:integration_test/integration_test.dart';

import 'integration_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('fPaint Integration Tests', () {
    testWidgets('Human-Like Rectangle Drawing - Two Rectangles', (final WidgetTester tester) async {
      debugPrint('👤 Testing Human-Simulated Multi-Rectangle Drawing');

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
        toolSelectionDelay: const Duration(milliseconds: 800),
      );

      await Future.delayed(const Duration(seconds: 1));

      // Second Rectangle: Door (20x40)
      await drawRectangleWithHumanGestures(
        tester,
        startPosition: canvasCenter + const Offset(130, 24),
        endPosition: canvasCenter + const Offset(180, 90),
        toolSelectionDelay: const Duration(milliseconds: 600),
      );

      // Validation: Verify both rectangles were created
      final BuildContext context = tester.element(find.byType(MainScreen));
      final AppProvider appProvider = AppProvider.of(context);

      expect(
        appProvider.layers.selectedLayer.actionStack.length,
        2,
        reason: 'Two rectangles should be successfully drawn',
      );

      // TODO add roof to house

      // Save the artwork
      final String testFilePath = '${Directory.current.path}/integration_test_artwork.png';
      await saveAsPng(appProvider.layers, testFilePath);

      debugPrint('✅ SUCCESS: Human-like multi-rectangle drawing completed');
      debugPrint('📁 Artwork saved: $testFilePath');
    });
  });
}
