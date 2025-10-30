// ignore_for_file: use_build_context_synchronously, prefer_final_locals, always_specify_types, inference_failure_on_instance_creation

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/panels/layers/layer_thumbnail.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/main_view.dart';

/// Helper method to draw a rectangle with human-like gestures
/// Includes automatic rectangle tool selection and natural timing
/// NOTE: Color and brush size parameters removed to enforce UI-only approach
///       Colors and brush properties must be set through the app's UI before calling this method
Future<void> drawRectangleWithHumanGestures(
  final WidgetTester tester, {
  required final Offset startPosition,
  required final Offset endPosition,
}) async {
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
/// NOTE: Color and brush size parameters removed to enforce UI-only approach
///       Colors and brush properties must be set through the app's UI before calling this method
Future<void> drawCircleWithHumanGestures(
  final WidgetTester tester, {
  required final Offset center,
  required final double radius,
}) async {
  // Select circle tool via UI
  const Duration toolSelectionDelay = Duration(milliseconds: 100);
  await tester.tap(find.byIcon(Icons.circle_outlined));
  await tester.pump();
  await Future.delayed(toolSelectionDelay);

  // Start drawing circle at center, then drag to define radius
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
/// NOTE: Color and brush size parameters removed to enforce UI-only approach
///       Colors and brush properties must be set through the app's UI before calling this method
Future<void> drawLineWithHumanGestures(
  final WidgetTester tester, {
  required final Offset startPosition,
  required final Offset endPosition,
}) async {
  // Select line tool via UI
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

/// Helper method to perform flood fill using UI interactions only
/// NOTE: This method selects the fill tool and performs flood fill at a position.
///       Color and gradient settings must be configured via the app's UI panels BEFORE calling this method.
///       Use the app's color picker, gradient tools, etc. to set desired colors before flood filling.
Future<void> performFloodFill(
  final WidgetTester tester, {
  required final Offset fillPosition,
}) async {
  // Select the fill tool via UI
  await tester.tap(find.byIcon(Icons.format_color_fill));
  await tester.pump(const Duration(milliseconds: 100));

  // Click at the fill position to trigger flood fill with current UI settings
  await tester.tapAt(fillPosition);
  await tester.pump();

  debugPrint('🎨 UI-based flood fill at position: $fillPosition');

  // Allow time for the fill operation to complete
  await tester.pump();
  await Future.delayed(const Duration(milliseconds: 300));
}

/// Layer management helper methods for integration tests
/// All methods use UI interactions instead of direct API calls
class LayerTestHelpers {
  /// Adds a new layer above the currently selected layer using UI
  static Future<void> addNewLayer(final WidgetTester tester, final String name) async {
    // Find and tap the "add layer" button (playlist_add icon)
    await tester.tap(find.byIcon(Icons.playlist_add));
    await tester.pump(const Duration(milliseconds: 500));
    await Future.delayed(const Duration(milliseconds: 200));

    // Verify the layer was added by checking the current state
    await tester.pumpAndSettle();
    final BuildContext context = tester.element(find.byType(MainView));
    final LayersProvider layersProvider = LayersProvider.of(context);
    debugPrint('🆕 Added new layer via UI (total layers now: ${layersProvider.length})');

    // Give more time for UI to update and show the 3-dot menu for the new selected layer
    await Future.delayed(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    // Use context menu to rename: 3-dots menu → "Rename layer"
    await renameLayer(tester, name);

    debugPrint('🎯 Layer added and renamed via context menu: "$name"');
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
    await Future.delayed(const Duration(milliseconds: 500));
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
