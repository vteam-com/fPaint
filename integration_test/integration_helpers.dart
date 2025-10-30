// ignore_for_file: use_build_context_synchronously, prefer_final_locals, always_specify_types, inference_failure_on_instance_creation

import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/export_download_non_web.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/main_view.dart';

/// Helper method to draw a rectangle with human-like gestures
/// Includes automatic rectangle tool selection and natural timing
Future<void> drawRectangleWithHumanGestures(
  final WidgetTester tester, {
  required final Offset startPosition,
  required final Offset endPosition,
  final double? brushSize,
  final Color? brushColor,
  final Color? fillColor,
}) async {
  // Get AppProvider to configure drawing properties
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context);

  // Apply optional drawing properties
  if (brushSize != null) {
    appProvider.brushSize = brushSize;
  }
  if (brushColor != null) {
    appProvider.brushColor = brushColor;
  }
  if (fillColor != null) {
    appProvider.fillColor = fillColor;
  }

  // Select rectangle tool (always needed for rectangle drawing)
  const Duration toolSelectionDelay = Duration(milliseconds: 100);
  await tester.tap(find.byIcon(Icons.crop_square));
  await tester.pump();
  await Future.delayed(toolSelectionDelay);

  final TestGesture gesture = await tester.startGesture(
    startPosition,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );

  // Calculate total movement and divide into 3 human-like steps
  final Offset totalOffset = endPosition - startPosition;
  final Offset stepOffset = totalOffset / 3;

  // Human-like drag with natural timing between steps
  const List<Duration> delays = <Duration>[
    Duration(milliseconds: 200),
    Duration(milliseconds: 250),
    Duration(milliseconds: 150),
  ];

  for (int i = 0; i < 3; i++) {
    await gesture.moveBy(stepOffset);
    if (i < delays.length) {
      await Future.delayed(delays[i]);
    }
    await tester.pump();
  }

  await gesture.up();
  await tester.pump();
}

/// Helper method to draw a line with human-like gestures from point A to point B
/// Includes automatic line tool selection and natural timing
Future<void> drawLineWithHumanGestures(
  final WidgetTester tester, {
  required final Offset startPosition,
  required final Offset endPosition,
  final double? brushSize,
  final Color? brushColor,
}) async {
  // Get AppProvider to configure drawing properties
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context);

  // Apply optional drawing properties
  if (brushSize != null) {
    appProvider.brushSize = brushSize;
  }
  if (brushColor != null) {
    appProvider.brushColor = brushColor;
  }

  // Select line tool
  const Duration toolSelectionDelay = Duration(milliseconds: 100);
  await tester.tap(find.byIcon(Icons.line_axis));
  await tester.pump();
  await Future.delayed(toolSelectionDelay);

  // Start drawing line at point A
  final TestGesture gesture = await tester.startGesture(
    startPosition,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );

  // Calculate total movement and divide into smooth human-like steps
  final Offset totalOffset = endPosition - startPosition;
  final Offset stepOffset = totalOffset / 8; // More steps for smoother line

  // Human-like drag with natural timing (more steps, shorter delays for line drawing)
  const List<Duration> delays = <Duration>[
    Duration(milliseconds: 50),
    Duration(milliseconds: 60),
    Duration(milliseconds: 70),
    Duration(milliseconds: 80),
    Duration(milliseconds: 50),
    Duration(milliseconds: 60),
    Duration(milliseconds: 40),
  ];

  for (int i = 0; i < 8; i++) {
    await gesture.moveBy(stepOffset);
    if (i < delays.length) {
      await Future.delayed(delays[i]);
    }
    await tester.pump();
  }

  await gesture.up();
  await tester.pump();
}

/// Integration test utilities for common operations
class IntegrationTestUtils {
  /// Saves the current layer artwork to a PNG file
  static Future<void> saveArtworkScreenshot({
    required final AppProvider appProvider,
    final String filename = 'integration_test_artwork.png',
  }) async {
    final String testFilePath = '${Directory.current.path}/$filename';
    await saveAsPng(appProvider.layers, testFilePath);
    debugPrint('💾 Artwork saved: $testFilePath');
  }
}
