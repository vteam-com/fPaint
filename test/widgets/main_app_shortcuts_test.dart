import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/tool_family.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:fpaint/widgets/shortcuts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_harness.dart';

void main() {
  late AppProvider appProvider;
  late ShellProvider shellProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    appProvider = AppProvider(preferences: AppPreferences());
    shellProvider = ShellProvider();
  });

  Widget buildTestWidget() {
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
                    onNewFromClipboard: () async {},
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  test('addPrimaryModifierShortcut binds exactly Cmd and Ctrl variants', () {
    final Map<ShortcutActivator, Intent> shortcuts = <ShortcutActivator, Intent>{};
    addPrimaryModifierShortcut(shortcuts, LogicalKeyboardKey.keyZ, const RedoIntent(), shift: true);

    expect(shortcuts.length, 2);
    final List<SingleActivator> activators = shortcuts.keys.cast<SingleActivator>().toList();
    expect(activators.every((SingleActivator a) => a.trigger == LogicalKeyboardKey.keyZ && a.shift), isTrue);
    expect(activators.where((SingleActivator a) => a.meta && !a.control).length, 1);
    expect(activators.where((SingleActivator a) => a.control && !a.meta).length, 1);
  });

  testWidgets('every tool-shortcut key selects its tool', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    for (final ToolShortcut tool in kToolShortcuts) {
      appProvider.selectedAction = ActionType.pencil;
      await tester.sendKeyEvent(tool.key);
      await tester.pump();
      expect(appProvider.selectedAction, tool.action, reason: tool.label);
    }
  });

  testWidgets('Cmd/Ctrl + = and - zoom about the canvas centre', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    for (final LogicalKeyboardKey modifier in <LogicalKeyboardKey>[
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.metaLeft,
    ]) {
      final double before = appProvider.layers.scale;
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.sendKeyUpEvent(modifier);
      await tester.pump();
      expect(appProvider.layers.scale, greaterThan(before));
      expect(shellProvider.canvasPlacement, CanvasAutoPlacement.manual);
    }

    final double zoomedIn = appProvider.layers.scale;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(appProvider.layers.scale, lessThan(zoomedIn));
  });

  testWidgets('4 and 6 rotate the view in opposite directions', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
    await tester.pump();
    final double clockwise = appProvider.layers.rotation;
    expect(clockwise, greaterThan(0));

    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.pump();
    expect(appProvider.layers.rotation, closeTo(0, 1e-9));
  });
}
