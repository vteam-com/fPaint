import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/canvas_gesture_handler.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_harness.dart';

Widget _buildHarness({
  required AppPreferences preferences,
  required AppProvider appProvider,
  required ShellProvider shellProvider,
}) {
  return InheritedControllerScope<AppPreferences>(
    controller: preferences,
    child: InheritedControllerScope<AppProvider>(
      controller: appProvider,
      child: InheritedControllerScope<LayersProvider>(
        controller: appProvider.layers,
        child: InheritedControllerScope<ShellProvider>(
          controller: shellProvider,
          child: buildLocalizedTestApp(
            home: const Scaffold(body: SizedBox.expand(child: MainView())),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late AppPreferences preferences;
  late AppProvider appProvider;
  late ShellProvider shellProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    shellProvider = ShellProvider();
  });

  testWidgets('shows and hides centered brush-size preview while brush size changes', (
    WidgetTester tester,
  ) async {
    const Color activeColor = Color(0xFF123456);
    appProvider.brushColor = activeColor;

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );

    appProvider.brushSize = 24.0;
    await tester.pump();

    final Finder previewFinder = find.byKey(Keys.brushSizePreviewOverlay);
    expect(previewFinder, findsOneWidget);
    final double expectedDiameter = 24.0 * appProvider.layers.scale;
    expect(tester.getSize(previewFinder), Size(expectedDiameter, expectedDiameter));

    final Finder mainViewFinder = find.byType(MainView);
    expect(tester.getCenter(previewFinder), tester.getCenter(mainViewFinder));
    expect(appProvider.brushSizePreviewColor, activeColor);

    await tester.pump(AppDefaults.brushSizePreviewDuration);
    await tester.pump();

    expect(find.byKey(Keys.brushSizePreviewOverlay), findsNothing);
  });

  testWidgets('shows brush-size preview at the drawing position while dragging', (
    WidgetTester tester,
  ) async {
    appProvider.selectedAction = ActionType.brush;
    appProvider.brushSize = 24.0;

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump(AppDefaults.brushSizePreviewDuration);
    await tester.pump();

    final Finder canvasGestureHandler = find.byType(CanvasGestureHandler);
    expect(canvasGestureHandler, findsOneWidget);

    final Offset dragStart = tester.getTopLeft(canvasGestureHandler) + const Offset(140, 160);
    final TestGesture gesture = await tester.startGesture(dragStart);
    await tester.pump();

    final Finder previewFinder = find.byKey(Keys.brushSizePreviewOverlay);
    expect(previewFinder, findsNothing);

    const Offset dragDelta = Offset(36, 28);
    await gesture.moveBy(dragDelta);
    await tester.pump();

    expect(find.byKey(Keys.brushSizePreviewOverlay), findsOneWidget);
    expect(tester.getCenter(previewFinder), dragStart + dragDelta);

    await gesture.up();
    await tester.pump();
    await tester.pump(AppDefaults.thumbnailDebounceDuration);
    await tester.pump();

    expect(find.byKey(Keys.brushSizePreviewOverlay), findsNothing);
  });

  testWidgets('shows brush-size preview while hovering a mouse before drawing', (
    WidgetTester tester,
  ) async {
    appProvider.selectedAction = ActionType.brush;
    appProvider.brushSize = 24.0;

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump(AppDefaults.brushSizePreviewDuration);
    await tester.pump();

    final Finder canvasGestureHandler = find.byType(CanvasGestureHandler);
    expect(canvasGestureHandler, findsOneWidget);

    final Offset hoverPosition = tester.getTopLeft(canvasGestureHandler) + const Offset(120, 140);
    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: hoverPosition);
    await mouse.moveTo(hoverPosition);
    await tester.pump();

    final Finder previewFinder = find.byKey(Keys.brushSizePreviewOverlay);
    expect(previewFinder, findsOneWidget);
    expect(tester.getCenter(previewFinder), hoverPosition);
  });
  testWidgets('Ctrl+Alt + mouse wheel resizes the brush instead of zooming the canvas', (
    WidgetTester tester,
  ) async {
    appProvider.selectedAction = ActionType.brush;
    appProvider.brushSize = 24.0;

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump(AppDefaults.brushSizePreviewDuration);
    await tester.pump();

    final Finder canvasGestureHandler = find.byType(CanvasGestureHandler);
    expect(canvasGestureHandler, findsOneWidget);

    final Offset wheelPosition = tester.getTopLeft(canvasGestureHandler) + const Offset(160, 180);

    // Hold Ctrl+Alt (the brush-size gesture chord) before scrolling.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);

    final double sizeBefore = appProvider.brushSize;
    final double scaleBefore = appProvider.layers.scale;

    // Scroll up one notch: the brush should grow and the canvas must NOT zoom.
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: ui.PointerDeviceKind.mouse,
        position: wheelPosition,
        scrollDelta: const Offset(0.0, -120.0),
      ),
    );
    await tester.pump();

    expect(appProvider.brushSize, greaterThan(sizeBefore));
    expect(appProvider.layers.scale, scaleBefore);

    // Scroll down one notch: the brush should shrink below the grown value.
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: ui.PointerDeviceKind.mouse,
        position: wheelPosition,
        scrollDelta: const Offset(0.0, 120.0),
      ),
    );
    await tester.pump();

    expect(appProvider.brushSize, closeTo(sizeBefore, 1e-9));
    expect(appProvider.layers.scale, scaleBefore);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
  });
}
