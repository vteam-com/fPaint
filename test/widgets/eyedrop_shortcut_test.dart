import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/magnifying_eye_dropper.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:fpaint/widgets/shortcuts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_harness.dart';

void main() {
  late AppProvider appProvider;
  late ShellProvider shellProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppPreferences appPreferences = AppPreferences();
    appProvider = AppProvider(preferences: appPreferences);
    shellProvider = ShellProvider();
  });

  Widget buildTestWidget({Size size = const Size(1200, 900)}) {
    return InheritedControllerScope<AppPreferences>(
      controller: appProvider.preferences,
      child: InheritedControllerScope<AppProvider>(
        controller: appProvider,
        child: InheritedControllerScope<LayersProvider>(
          controller: appProvider.layers,
          child: InheritedControllerScope<ShellProvider>(
            controller: shellProvider,
            child: buildLocalizedTestApp(
              home: Builder(
                builder: (BuildContext context) {
                  return shortCutsForMainApp(
                    context,
                    shellProvider,
                    appProvider,
                    const MainView(),
                    onSave: () async {},
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Alt/Option EyeDrop Shortcut', () {
    testWidgets('triggers eyedropper when Alt key is pressed and removes on release', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(MagnifyingEyeDropper), findsNothing);

      // Press Alt Left
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();

      expect(appProvider.isEyeDropShortcutActive, isTrue);
      expect(find.byType(MagnifyingEyeDropper), findsOneWidget);

      // Release Alt Left
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();

      expect(appProvider.isEyeDropShortcutActive, isFalse);
      expect(find.byType(MagnifyingEyeDropper), findsNothing);
    });

    testWidgets('triggers eyedropper with altRight key as well', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(MagnifyingEyeDropper), findsNothing);

      // Press Alt Right
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altRight);
      await tester.pump();

      expect(appProvider.isEyeDropShortcutActive, isTrue);
      expect(find.byType(MagnifyingEyeDropper), findsOneWidget);

      // Release Alt Right
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altRight);
      await tester.pump();

      expect(appProvider.isEyeDropShortcutActive, isFalse);
      expect(find.byType(MagnifyingEyeDropper), findsNothing);
    });

    testWidgets('action eyedropper accepts selected color and closes on canvas click', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Arm brush eyedropper manually (as if picked from tool panel)
      appProvider.eyeDropPositionForBrush = const Offset(200, 200);
      await tester.pump();

      expect(appProvider.isEyeDropShortcutActive, isFalse);
      expect(find.byType(MagnifyingEyeDropper), findsOneWidget);

      // Tap on the canvas to pick a color
      await tester.tapAt(const Offset(200, 200));
      await tester.pumpAndSettle();

      // Eyedropper should be dismissed and eyeDropPositionForBrush cleared to null
      expect(appProvider.eyeDropPositionForBrush, isNull);
      expect(find.byType(MagnifyingEyeDropper), findsNothing);
    });

    testWidgets('stylus pen drag updates eyedropper position and closes on release', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      appProvider.eyeDropPositionForBrush = const Offset(100, 100);
      await tester.pump();

      final TestGesture gesture = await tester.startGesture(
        const Offset(100, 100),
        kind: PointerDeviceKind.stylus,
      );
      await tester.pump();

      expect(appProvider.eyeDropPositionForBrush, const Offset(100, 100));

      await gesture.moveTo(const Offset(300, 300));
      await tester.pump();

      expect(appProvider.eyeDropPositionForBrush, const Offset(300, 300));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(appProvider.eyeDropPositionForBrush, isNull);
      expect(find.byType(MagnifyingEyeDropper), findsNothing);
    });
  });
}
