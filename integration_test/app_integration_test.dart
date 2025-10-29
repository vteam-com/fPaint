// ignore_for_file: use_build_context_synchronously, prefer_final_locals, always_specify_types, inference_failure_on_instance_creation

import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/export_download_non_web.dart';
import 'package:fpaint/main.dart' as app;
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('fPaint Integration Tests', () {
    testWidgets('Human-Like Rectangle Drawing - Two Rectangles', (final WidgetTester tester) async {
      debugPrint('👤 Testing Human-Simulated Multi-Rectangle Drawing');

      app.main();
      await tester.pumpAndSettle();

      final Finder canvasFinder = find.byType(MainView);
      final Offset canvasCenter = tester.getCenter(canvasFinder);

      // Simulate natural human drawing sequence with realistic timing

      // First Rectangle - Natural user behavior
      await tester.tap(find.byIcon(Icons.crop_square));
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 800));

      final TestGesture firstGesture = await tester.startGesture(
        canvasCenter,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryButton,
      );

      // Human-like gradual drag with natural pauses
      await firstGesture.moveBy(const Offset(50, 25));
      await Future.delayed(const Duration(milliseconds: 200));
      await tester.pump();

      await firstGesture.moveBy(const Offset(50, 25));
      await Future.delayed(const Duration(milliseconds: 300));
      await tester.pump();

      await firstGesture.moveBy(const Offset(50, 50));
      await Future.delayed(const Duration(milliseconds: 150));
      await tester.pump();

      await firstGesture.up();
      await tester.pump();

      // second rectangle (human thinking time)
      await Future.delayed(const Duration(seconds: 1));

      // Second Rectangle - Separate human action sequence
      await tester.tap(find.byIcon(Icons.crop_square));
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 600));

      final TestGesture secondGesture = await tester.startGesture(
        canvasCenter + const Offset(-150, 100), // Different position
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryButton,
      );

      // Second rectangle with different human-like drag timing
      await secondGesture.moveBy(const Offset(40, 20));
      await Future.delayed(const Duration(milliseconds: 250));
      await tester.pump();

      await secondGesture.moveBy(const Offset(60, 30));
      await Future.delayed(const Duration(milliseconds: 350));
      await tester.pump();

      await secondGesture.moveBy(const Offset(40, 40));
      await Future.delayed(const Duration(milliseconds: 200));
      await tester.pump();

      await secondGesture.up();
      await tester.pump();

      // Validation: Verify both rectangles were created
      final BuildContext context = tester.element(find.byType(MainScreen));
      final AppProvider appProvider = AppProvider.of(context);

      expect(
        appProvider.layers.selectedLayer.actionStack.length,
        2,
        reason: 'Two rectangles should be successfully drawn',
      );

      // Save the artwork
      final String testFilePath = '${Directory.current.path}/integration_test_artwork.png';
      await saveAsPng(appProvider.layers, testFilePath);

      debugPrint('✅ SUCCESS: Human-like multi-rectangle drawing completed');
      debugPrint('📁 Artwork saved: $testFilePath');
    });
  });
}
