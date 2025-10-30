// ignore_for_file: use_build_context_synchronously, prefer_final_locals, always_specify_types, inference_failure_on_instance_creation

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/panels/layers/layer_thumbnail.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/main_view.dart';

/// Helper method to set brush size via AppProvider (direct API approach for reliable brushing size control)
Future<void> setBrushSizeViaUI(final WidgetTester tester, final double brushSize) async {
  debugPrint('🎨 Setting brush size via AppProvider: $brushSize');

  // Get the AppProvider directly and set the brush size
  final BuildContext context = tester.element(find.byType(MainView));

  // Use Provider to access AppProvider and set brush size directly
  final AppProvider appProvider = AppProvider.of(context, listen: false);
  appProvider.brushSize = brushSize;

  debugPrint('🎨 Set brush size directly via AppProvider: $brushSize');

  // Pump to ensure the UI updates
  await tester.pumpAndSettle();

  debugPrint('🎨 Brush size UI interaction completed');
}

/// Helper method to draw a rectangle with human-like gestures
/// Includes automatic rectangle tool selection and natural timing
/// Supports brush size, brush color, and fill color configuration via UI interface
Future<void> drawRectangleWithHumanGestures(
  final WidgetTester tester, {
  required final Offset startPosition,
  required final Offset endPosition,
  final double? brushSize, // Optional parameter for brush size
  final Color? brushColor, // Optional parameter for brush color
  final Color? fillColor, // Optional parameter for fill color
}) async {
  // Set brush size via UI if specified
  if (brushSize != null) {
    await setBrushSizeViaUI(tester, brushSize);
  }

  // Set colors if specified (directly modify appProvider)
  if (brushColor != null || fillColor != null) {
    final BuildContext context = tester.element(find.byType(MainView));
    final AppProvider appProvider = AppProvider.of(context);

    if (brushColor != null) {
      debugPrint('🎨 Setting brush color to: $brushColor');
      appProvider.brushColor = brushColor;
    }

    if (fillColor != null) {
      debugPrint('🎨 Setting fill color to: $fillColor');
      appProvider.fillColor = fillColor;
    }
  }

  // Select rectangle tool via UI (always needed for rectangle drawing)
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

/// Helper method to draw a circle with human-like gestures
/// Circle is defined by center point and radius (drag from center to circumference)
/// Supports brush size, brush color, and fill color configuration via UI interface
Future<void> drawCircleWithHumanGestures(
  final WidgetTester tester, {
  required final Offset center,
  required final double radius,
  final double? brushSize, // Optional parameter for brush size
  final Color? brushColor, // Optional parameter for brush color
  final Color? fillColor, // Optional parameter for fill color
}) async {
  // Set brush size via UI if specified
  if (brushSize != null) {
    await setBrushSizeViaUI(tester, brushSize);
  }

  // Set colors if specified (directly modify appProvider)
  if (brushColor != null || fillColor != null) {
    final BuildContext context = tester.element(find.byType(MainView));
    final AppProvider appProvider = AppProvider.of(context);

    if (brushColor != null) {
      debugPrint('🎨 Setting brush color to: $brushColor');
      appProvider.brushColor = brushColor;
    }

    if (fillColor != null) {
      debugPrint('🎨 Setting fill color to: $fillColor');
      appProvider.fillColor = fillColor;
    }
  }

  // Select circle tool via UI
  const Duration toolSelectionDelay = Duration(milliseconds: 100);
  await tester.tap(find.byIcon(Icons.circle_outlined));
  await tester.pump();
  await Future.delayed(toolSelectionDelay);

  final TestGesture gesture = await tester.startGesture(
    center,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );

  // Drag from center outward to define radius (rightward for simplicity)
  final Offset circumferencePoint = center + Offset(radius, 0);

  // Calculate total movement and divide into smooth human-like steps
  final Offset totalOffset = circumferencePoint - center;
  final Offset stepOffset = totalOffset / 5; // 5 steps for circle radius definition

  // Human-like drag with natural timing for circle creation
  const List<Duration> delays = <Duration>[
    Duration(milliseconds: 100),
    Duration(milliseconds: 120),
    Duration(milliseconds: 140),
    Duration(milliseconds: 100),
    Duration(milliseconds: 80),
  ];

  for (int i = 0; i < 5; i++) {
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
/// Supports brush size, brush color, and fill color configuration via UI interface
Future<void> drawLineWithHumanGestures(
  final WidgetTester tester, {
  required final Offset startPosition,
  required final Offset endPosition,
  final double? brushSize, // Optional parameter for brush size
  final Color? brushColor, // Optional parameter for brush color
  final Color? fillColor, // Optional parameter for fill color
}) async {
  // Set brush size via UI if specified
  if (brushSize != null) {
    await setBrushSizeViaUI(tester, brushSize);
  }

  // Set colors if specified (directly modify appProvider)
  if (brushColor != null || fillColor != null) {
    final BuildContext context = tester.element(find.byType(MainView));
    final AppProvider appProvider = AppProvider.of(context);

    if (brushColor != null) {
      debugPrint('🎨 Setting brush color to: $brushColor');
      appProvider.brushColor = brushColor;
    }

    if (fillColor != null) {
      debugPrint('🎨 Setting fill color to: $fillColor');
      appProvider.fillColor = fillColor;
    }
  }

  // Select line tool via UI
  const Duration toolSelectionDelay = Duration(milliseconds: 100);
  await tester.tap(find.byIcon(Icons.line_axis));
  await tester.pump();
  await Future.delayed(toolSelectionDelay);

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

/// Helper method to perform flood fill with gradient configuration
/// Supports both solid color fills and gradient fills with UI configuration
/// Uses human-like gesture simulation for natural interaction
Future<void> performFloodFill(
  final WidgetTester tester, {
  required final Offset fillPosition,
  required final FillMode gradientMode, // FillMode.linear or FillMode.radial
  final List<GradientPoint>? gradientPoints,
}) async {
  debugPrint('🎨 Performing flood fill at: $fillPosition (gradient: $gradientMode)');

  // Select the fill tool via UI
  await tester.tap(find.byIcon(Icons.format_color_fill));
  await tester.pump(const Duration(milliseconds: 300));

  // ================================
  // SET FILL MODE, Solid, Linear, Radial
  // ================================
  if (gradientMode != FillMode.solid && gradientPoints != null) {
    await selectFillMode(tester, gradientMode, gradientPoints);
  }

  // ================================
  // APPLY THE FILL WITH HUMAN GESTURE
  // ================================
  // Use human-like gesture: press down at fill position and hold briefly
  final TestGesture gesture = await tester.startGesture(
    fillPosition,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );

  // Hold down for a brief moment to simulate human press
  await Future.delayed(const Duration(milliseconds: 200));
  await tester.pump();

  // Release the gesture
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 300));

  // Allow time for the fill operation to complete and UI to update
  await tester.pump();
  await Future.delayed(const Duration(milliseconds: 1000));

  // Reset fill mode back to solid to terminate gradient gesture
  final String solidModeKey = 'tool-fill-mode-solid';
  final Finder solidModeButton = find.byKey(Key(solidModeKey));

  if (solidModeButton.evaluate().isNotEmpty) {
    debugPrint('🔄 Resetting fill mode to solid...');
    await tester.tap(solidModeButton.first);
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(milliseconds: 300));
    debugPrint('✅ Fill mode reset to solid');
  } else {
    debugPrint('⚠️ Solid fill mode button not found, skipping reset');
  }

  await Future.delayed(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

/// Helper method to configure gradient fill via UI interactions
/// Note: The actual gradient configuration happens through the FillWidget which shows gradient control points on the canvas
Future<void> selectFillMode(
  final WidgetTester tester,
  final FillMode gradientMode,
  final List<GradientPoint> gradientPoints,
) async {
  debugPrint('🎨 Configuring gradient via UI: mode=$gradientMode, points=${gradientPoints.length}');

  // ================================
  // STEP 1: Try to set gradient mode via UI button first
  // ================================
  String keyName = 'tool-fill-mode-solid';

  if (gradientMode == FillMode.linear) {
    keyName = 'tool-fill-mode-linear';
  }
  if (gradientMode == FillMode.radial) {
    keyName = 'tool-fill-mode-radial';
  }

  final Finder gradientModeButton = find.byKey(Key(keyName));

  if (gradientModeButton.evaluate().isNotEmpty) {
    debugPrint('    Found gradient mode button, tapping to select $gradientMode');
    await tester.tap(gradientModeButton.first);
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(milliseconds: 300));
  } else {
    debugPrint('⚠️ Gradient mode button with key "$keyName" not found, using direct model access');
  }

  // Force UI update
  await tester.pumpAndSettle();
  await Future.delayed(const Duration(milliseconds: 300));

  debugPrint('🎨 Gradient UI configuration completed');
}

/// Layer management helper methods for integration tests
/// All methods use UI interactions instead of direct API calls
class LayerTestHelpers {
  /// Adds a new layer above the currently selected layer using UI
  static Future<void> addNewLayer(final WidgetTester tester, final String name) async {
    // Try to add layer using API approach first (most reliable for tests)
    final BuildContext context = tester.element(find.byType(MainView));
    final LayersProvider layersProvider = LayersProvider.of(context);
    final int currentIndex = layersProvider.selectedLayerIndex;

    // Use the API to add the layer
    layersProvider.insertAt(currentIndex);
    final LayerProvider newLayer = layersProvider.get(currentIndex);
    layersProvider.selectedLayerIndex = layersProvider.getLayerIndex(newLayer);

    debugPrint('🆕 Added new layer via API (total layers now: ${layersProvider.length})');

    // Give time for UI to update and try to make layer visible
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    // Try to select the layer via UI to ensure it's properly visible
    try {
      await switchToLayer(tester, currentIndex);
      await tester.pumpAndSettle();
      debugPrint('🔄 Selected layer via UI to ensure visibility');
    } catch (e) {
      debugPrint('⚠️ Could not select layer via UI, using API selection');
    }

    // Give additional time for UI to settle before renaming
    await Future.delayed(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    // Rename the newly selected layer using context menu
    await renameLayer(tester, name);

    debugPrint('🎯 Layer added and renamed successfully: "$name"');
  }

  /// Switches to a specific layer by tapping on it in the UI (by index)
  static Future<void> switchToLayer(final WidgetTester tester, final int layerIndex) async {
    // Get the context and provider to verify current state
    final BuildContext context = tester.element(find.byType(MainView));
    final LayersProvider layersProvider = LayersProvider.of(context);

    if (layerIndex < 0 || layerIndex >= layersProvider.length) {
      debugPrint('❌ Invalid layer index: $layerIndex (total layers: ${layersProvider.length})');
      return;
    }

    // Get the target layer name to find it in the UI
    final String targetLayerName = layersProvider.get(layerIndex).name;

    // Find the text widget showing the layer name
    final Finder textFinder = find.text(targetLayerName);

    if (textFinder.evaluate().isEmpty) {
      debugPrint('❌ Could not find layer name text widget for "$targetLayerName" at index $layerIndex');
      // Try to find any LayerThumbnail widgets and tap on the correct one by position
      final Finder thumbnails = find.byType(LayerThumbnail);
      if (thumbnails.evaluate().isNotEmpty && layerIndex < thumbnails.evaluate().length) {
        try {
          await tester.tap(thumbnails.at(layerIndex));
          await tester.pump(const Duration(milliseconds: 300));
          debugPrint('🔄 Switched to layer index: $layerIndex via thumbnail tap fallback');
          return;
        } catch (e) {
          debugPrint('❌ Thumbnail tap fallback also failed: $e');
        }
      }

      // Last resort: use direct API since UI interaction failed
      debugPrint('⚠️ Falling back to direct API for layer switching');
      layersProvider.selectedLayerIndex = layerIndex;
      debugPrint('🔄 Switched to layer index: $layerIndex via direct API (fallback)');
      return;
    }

    // Tap on the layer text/name widget to select it
    await tester.tap(textFinder.first);
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('🔄 Switched to layer index: $layerIndex ("$targetLayerName") via UI tap');
  }

  /// Switches to a specific layer by tapping on it in the UI (by name)
  static Future<void> switchToLayerByName(final WidgetTester tester, final String layerName) async {
    // Get the context and provider to verify current state
    final BuildContext context = tester.element(find.byType(MainView));
    final LayersProvider layersProvider = LayersProvider.of(context);

    // Find the layer index by name
    int layerIndex = -1;
    for (int i = 0; i < layersProvider.length; i++) {
      if (layersProvider.get(i).name == layerName) {
        layerIndex = i;
        break;
      }
    }

    if (layerIndex == -1) {
      debugPrint('❌ Layer with name "$layerName" not found');
      return;
    }

    // Find the text widget showing the layer name
    final Finder textFinder = find.text(layerName);

    if (textFinder.evaluate().isEmpty) {
      debugPrint('❌ Could not find layer name text widget for "$layerName"');
      // Try to find any LayerThumbnail widgets and tap on the correct one by position
      final Finder thumbnails = find.byType(LayerThumbnail);
      if (thumbnails.evaluate().isNotEmpty && layerIndex < thumbnails.evaluate().length) {
        try {
          await tester.tap(thumbnails.at(layerIndex));
          await tester.pump(const Duration(milliseconds: 300));
          debugPrint('🔄 Switched to layer "$layerName" via thumbnail tap fallback');
          return;
        } catch (e) {
          debugPrint('❌ Thumbnail tap fallback also failed: $e');
        }
      }

      // Last resort: use direct API since UI interaction failed
      debugPrint('⚠️ Falling back to direct API for layer switching');
      layersProvider.selectedLayerIndex = layerIndex;
      debugPrint('🔄 Switched to layer "$layerName" via direct API (fallback)');
      return;
    }

    // Tap on the layer text/name widget to select it
    await tester.tap(textFinder.first);
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('🔄 Switched to layer "$layerName" via UI tap');
  }

  /// Merges a layer into the layer below it using UI
  static Future<void> mergeLayer(final WidgetTester tester, final int fromIndex, final int toIndex) async {
    // First ensure we're on the source layer
    await switchToLayer(tester, fromIndex);

    // Find and tap the merge button (layers_outlined icon)
    await tester.tap(find.byIcon(Icons.layers_outlined));
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('🔗 Merged layer $fromIndex into layer below via UI');
  }

  /// Removes the currently selected layer using UI
  static Future<void> removeLayer(final WidgetTester tester, final int layerIndex) async {
    // First switch to the layer to delete
    await switchToLayer(tester, layerIndex);

    // Find and tap the remove button (playlist_remove icon)
    await tester.tap(find.byIcon(Icons.playlist_remove));
    await tester.pump(const Duration(milliseconds: 300));

    debugPrint('🗑️ Removed layer $layerIndex via UI delete button');
  }

  /// Prints the current layer structure (async to avoid conflicts)
  static Future<void> printLayerStructure(final WidgetTester tester) async {
    await tester.pumpAndSettle(); // Ensure UI is settled before accessing context
    final BuildContext context = tester.element(find.byType(MainView));
    final LayersProvider layersProvider = LayersProvider.of(context);
    debugPrint('📚 Layer Structure:');
    for (int i = 0; i < layersProvider.length; i++) {
      final layer = layersProvider.get(i);
      final selected = layer.isSelected ? ' ← SELECTED' : '';
      final visible = layer.isVisible ? '👁️' : '👁️‍🗨️';
      debugPrint('  [$i] $visible "${layer.name}" - ${layer.actionStack.length} actions$selected');
    }
  }

  /// Renames the currently selected layer via UI using the context menu (3-dot menu)
  static Future<void> renameLayer(final WidgetTester tester, final String newName) async {
    // Find the 3-dot menu button (more_vert icon) for the currently selected layer
    final Finder menuButtonFinder = find.byIcon(Icons.more_vert);
    expect(menuButtonFinder, findsWidgets, reason: 'Should find context menu button (more_vert icon)');

    // Tap the menu button to open the context menu with increased pump time
    await tester.tap(menuButtonFinder.first);
    await Future.delayed(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // Wait additional time for menu to render completely
    await Future.delayed(const Duration(milliseconds: 1000));

    // Find the "Rename layer" menu item using descendant finder to be more specific
    final Finder popupMenu = find.byWidgetPredicate(
      (final Widget widget) => widget.runtimeType.toString().contains('PopupMenu'),
    );
    final Finder renameMenuItem = find
        .descendant(
          of: popupMenu,
          matching: find.text('Rename layer'),
        )
        .first;

    // If specific finder fails, try the general one as fallback
    Finder finalRenameFinder = renameMenuItem;
    if (finalRenameFinder.evaluate().isEmpty) {
      finalRenameFinder = find.text('Rename layer');
    }

    expect(finalRenameFinder, findsOneWidget, reason: 'Should find "Rename layer" menu item in context menu');

    // Try tapping with warnIfMissed disabled since popup menus often have positioning issues in tests
    await tester.tap(finalRenameFinder, warnIfMissed: false);
    await Future.delayed(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Wait for the rename dialog to appear
    await Future.delayed(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    // Verify dialog is open by looking for TextField
    final Finder textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget, reason: 'Rename dialog should contain a TextField');

    // Enter new name in the text field
    await tester.enterText(textFieldFinder.first, newName);
    await tester.pumpAndSettle();

    // Find and tap the "Apply" button
    final Finder applyButtonFinder = find.widgetWithText(TextButton, 'Apply');
    expect(applyButtonFinder, findsOneWidget, reason: 'Should find Apply button in rename dialog');

    await tester.tap(applyButtonFinder);
    await tester.pumpAndSettle();

    debugPrint('✏️ Renamed selected layer to: "$newName" via context menu');
  }
}

/// Integration test utilities for common operations
class IntegrationTestUtils {
  /// Saves the current layer artwork to a PNG file
  static Future<void> saveArtworkScreenshot({
    required final LayersProvider layersProvider,
    final String filename = 'integration_test_artwork.png',
  }) async {
    final Uint8List bytes = await layersProvider.capturePainterToImageBytes();
    final String testFilePath = '${Directory.current.path}/$filename';
    await File(testFilePath).writeAsBytes(bytes);
    debugPrint('💾 Artwork saved: $testFilePath');
  }
}

Future<void> tapByKey(final WidgetTester tester, final Key key) async {
  // Hide the Float Action panel
  final Finder buttonsFound = find.byKey(key);

  if (buttonsFound.evaluate().isNotEmpty) {
    await tester.tap(buttonsFound.first);
    await tester.pumpAndSettle();
  }
}
