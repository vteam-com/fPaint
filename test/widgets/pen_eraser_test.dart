import 'package:flutter/gestures.dart';
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

/// Performs a pointer stroke across the canvas with the given [kind]/[buttons].
///
/// Mirrors the human-drag helpers used across the test suite but keeps the input
/// kind and button mask explicit so a Surface pen eraser (invertedStylus) can be
/// simulated.
Future<void> _stroke(WidgetTester tester, Offset start, PointerDeviceKind kind, int buttons) async {
  final TestGesture gesture = await tester.startGesture(start, kind: kind, buttons: buttons);
  await gesture.moveBy(const Offset(0, 40));
  await gesture.moveBy(const Offset(40, 0));
  await gesture.up();
  await tester.pump();
  await tester.pump(AppDefaults.thumbnailDebounceDuration);
  await tester.pump();
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

  Future<Offset> canvasStart(WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump();
    final Finder canvasGestureHandler = find.byType(CanvasGestureHandler);
    expect(canvasGestureHandler, findsOneWidget);
    return tester.getTopLeft(canvasGestureHandler) + const Offset(120, 140);
  }

  testWidgets('the Surface pen eraser erases regardless of the armed tool', (
    WidgetTester tester,
  ) async {
    // Arm a brush (not the eraser) so the pen eraser must override it.
    appProvider.selectedAction = ActionType.brush;
    final Offset start = await canvasStart(tester);

    // The Windows embedder reports the eraser end as an invertedStylus whose
    // buttons carry the stylus-contact bit together with the eraser (secondary
    // stylus) bit — exactly what `_handlePointerStart`/`_handlePointerMove` now
    // accept and route to the eraser.
    await _stroke(
      tester,
      start,
      PointerDeviceKind.invertedStylus,
      kStylusContact | kSecondaryStylusButton,
    );

    expect(appProvider.layers.selectedLayer.lastUserAction?.action, ActionType.eraser);
    expect(appProvider.selectedAction, ActionType.brush, reason: 'The armed tool must be left untouched.');
  });

  testWidgets('a selected brush still draws a brush with a normal mouse stroke', (
    WidgetTester tester,
  ) async {
    appProvider.selectedAction = ActionType.brush;
    final Offset start = await canvasStart(tester);

    await _stroke(tester, start, PointerDeviceKind.mouse, kPrimaryButton);

    expect(appProvider.layers.selectedLayer.lastUserAction?.action, ActionType.brush);
  });

  testWidgets('a selected brush still draws with a single touch stroke', (WidgetTester tester) async {
    appProvider.selectedAction = ActionType.brush;
    final Offset start = await canvasStart(tester);

    await _stroke(tester, start, PointerDeviceKind.touch, kPrimaryButton);

    expect(appProvider.layers.selectedLayer.lastUserAction?.action, ActionType.brush);
  });

  testWidgets('pen-only drawing blocks touch but accepts a normal stylus', (WidgetTester tester) async {
    await preferences.setPenOnlyDrawing(true);
    appProvider.selectedAction = ActionType.brush;
    final Offset start = await canvasStart(tester);
    final int initialActionCount = appProvider.layers.selectedLayer.actionStack.length;

    await _stroke(tester, start, PointerDeviceKind.touch, kPrimaryButton);
    expect(appProvider.layers.selectedLayer.actionStack.length, initialActionCount);

    await _stroke(tester, start, PointerDeviceKind.stylus, kPrimaryButton);
    expect(appProvider.layers.selectedLayer.lastUserAction?.action, ActionType.brush);
  });
}
