import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _viewSize = Size(1200, 800);
const Offset _anchor = Offset(400, 300);

void main() {
  late AppPreferences preferences;
  late AppProvider appProvider;
  late ShellProvider shellProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    appProvider.undoProvider.clear();
    appProvider.selectedAction = ActionType.brush;
    shellProvider = ShellProvider();
    shellProvider.shellMode = ShellMode.full;
  });

  Future<void> pumpMainView(WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = _viewSize;
    await tester.pumpWidget(
      InheritedControllerScope<AppPreferences>(
        controller: preferences,
        child: InheritedControllerScope<AppProvider>(
          controller: appProvider,
          child: InheritedControllerScope<LayersProvider>(
            controller: appProvider.layers,
            child: InheritedControllerScope<ShellProvider>(
              controller: shellProvider,
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: MainView(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Runs [body] with the platform pinned to macOS.
  ///
  /// The test binding reports android by default, so the chord under test has to
  /// be chosen deliberately; the override is cleared before the test returns
  /// because the binding asserts no foundation debug var outlives a test. (The
  /// Ctrl+Alt branch is covered by the platform unit tests in
  /// app_provider_tools_test.dart.)
  Future<void> onMacOS(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  /// Holds the platform resize chord for the duration of [body].
  Future<void> withResizeModifiers(WidgetTester tester, Future<void> Function() body) async {
    // macOS is the test binding's default target platform, so Cmd+Option is the
    // chord under test here.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    try {
      await body();
    } finally {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    }
  }

  int strokeCount() => appProvider.layers.selectedLayer.actionStack.length;

  /// Drains the layer's debounced cache/thumbnail rebuild so the test does not
  /// end with a pending timer.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
  }

  testWidgets('dragging right with the modifiers held grows the brush', (WidgetTester tester) async {
    await onMacOS(() async {
      await pumpMainView(tester);
      final double before = appProvider.brushSize;

      await withResizeModifiers(tester, () async {
        final TestGesture gesture = await tester.startGesture(_anchor);
        await gesture.moveTo(_anchor + const Offset(120, 0));
        await tester.pump();
        expect(appProvider.brushSize, greaterThan(before));
        await gesture.up();
      });
      await settle(tester);

      expect(appProvider.brushSize, greaterThan(before));
    });
  });

  testWidgets('dragging left with the modifiers held shrinks the brush', (WidgetTester tester) async {
    await onMacOS(() async {
      appProvider.brushSize = 60;
      await pumpMainView(tester);

      await withResizeModifiers(tester, () async {
        final TestGesture gesture = await tester.startGesture(_anchor);
        await gesture.moveTo(_anchor - const Offset(120, 0));
        await tester.pump();
        await gesture.up();
      });
      await settle(tester);

      expect(appProvider.brushSize, lessThan(60));
    });
  });

  testWidgets('the resize drag never paints a stroke', (WidgetTester tester) async {
    await onMacOS(() async {
      await pumpMainView(tester);
      final int before = strokeCount();

      await withResizeModifiers(tester, () async {
        final TestGesture gesture = await tester.startGesture(_anchor);
        await gesture.moveTo(_anchor + const Offset(150, 20));
        await tester.pump();
        await gesture.moveTo(_anchor + const Offset(200, 40));
        await tester.pump();
        await gesture.up();
      });
      await settle(tester);

      expect(strokeCount(), before, reason: 'a size scrub must not land on the layer');
      expect(appProvider.undoProvider.canUndo, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the same drag without modifiers paints instead of resizing', (WidgetTester tester) async {
    await onMacOS(() async {
      await pumpMainView(tester);
      final double sizeBefore = appProvider.brushSize;
      final int before = strokeCount();

      final TestGesture gesture = await tester.startGesture(_anchor);
      await gesture.moveTo(_anchor + const Offset(120, 0));
      await tester.pump();
      await gesture.up();
      await settle(tester);

      expect(appProvider.brushSize, sizeBefore, reason: 'no modifiers means no resize');
      expect(strokeCount(), greaterThan(before));
    });
  });

  testWidgets('the size scrub releases the pointer lock when the drag ends', (WidgetTester tester) async {
    await onMacOS(() async {
      await pumpMainView(tester);

      await withResizeModifiers(tester, () async {
        final TestGesture gesture = await tester.startGesture(_anchor);
        await gesture.moveTo(_anchor + const Offset(80, 0));
        await tester.pump();
        expect(appProvider.isTolerancePointerLocked, isTrue);
        await gesture.up();
      });
      await settle(tester);

      expect(appProvider.isTolerancePointerLocked, isFalse);
    });
  });

  testWidgets('pressing Option before Cmd still resizes rather than eyedropping', (WidgetTester tester) async {
    await onMacOS(() async {
      await pumpMainView(tester);
      final double before = appProvider.brushSize;

      // Option first arms the eyedropper shortcut; adding Cmd must escalate the
      // chord into a resize instead of leaving the eyedropper to swallow the drag.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(appProvider.isEyeDropShortcutActive, isFalse);

      final TestGesture gesture = await tester.startGesture(_anchor);
      await gesture.moveTo(_anchor + const Offset(120, 0));
      await tester.pump();
      await gesture.up();
      await settle(tester);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      expect(appProvider.brushSize, greaterThan(before));
    });
  });
}
