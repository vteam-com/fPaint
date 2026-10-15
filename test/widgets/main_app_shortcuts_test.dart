import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
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

const Offset _quickMenuAnchor = Offset(40, 40);
const Duration _snackBarDismissWait = Duration(seconds: 5);
const Color _cursorColor = Color(0xFF000000);
const Color _backgroundCursorColor = Color(0xFF808080);

void main() {
  late AppProvider appProvider;
  late ShellProvider shellProvider;
  late int newFromClipboardCount;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    appProvider = AppProvider(preferences: AppPreferences());
    shellProvider = ShellProvider();
    newFromClipboardCount = 0;
  });

  Widget buildTestWidget({Widget child = const MainView()}) {
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
                    child,
                    onSave: () async {},
                    onNewFromClipboard: () async => newFromClipboardCount++,
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
  Future<void> sendPrimaryChord(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
  }

  testWidgets('Escape closes an open quick menu before anything else', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    appProvider.selectedAction = ActionType.selector;
    appProvider.quickMenuModel.open(_quickMenuAnchor);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(appProvider.quickMenuModel.isOpen, isFalse);
    expect(appProvider.selectedAction, ActionType.selector);
  });

  testWidgets('Escape clears the selection, restores the tool and drops the eyedropper', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    appProvider.selectedAction = ActionType.brush;
    appProvider.selectedAction = ActionType.selector;
    appProvider.selectorModel.isVisible = true;
    appProvider.activateEyeDropShortcut();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(appProvider.selectorModel.isVisible, isFalse);
    expect(appProvider.selectedAction, ActionType.brush);
    expect(appProvider.isEyeDropShortcutActive, isFalse);
  });

  testWidgets('Cmd+X on a locked layer is refused, Cmd+N runs New from clipboard', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    appProvider.layers.selectedLayer.isLocked = true;
    appProvider.undoProvider.clear();
    await sendPrimaryChord(tester, LogicalKeyboardKey.keyX);
    expect(appProvider.undoProvider.canUndo, isFalse);

    await sendPrimaryChord(tester, LogicalKeyboardKey.keyN);
    expect(newFromClipboardCount, 1);

    await tester.pump(_snackBarDismissWait);
  });

  testWidgets('Cmd+X, Cmd+C and Cmd+V reach the region clipboard actions', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await sendPrimaryChord(tester, LogicalKeyboardKey.keyX);
    await sendPrimaryChord(tester, LogicalKeyboardKey.keyC);
    await sendPrimaryChord(tester, LogicalKeyboardKey.keyV);
    await tester.pump(AppDefaults.clipboardAccessTimeout);
    // The cut's erase schedules a debounced thumbnail rebuild.
    await tester.pump(AppDefaults.thumbnailDebounceDuration);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a key typed into a text field drops the Alt eyedropper', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController();
    final FocusNode focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      buildTestWidget(
        child: EditableText(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(),
          cursorColor: _cursorColor,
          backgroundCursorColor: _backgroundCursorColor,
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    appProvider.activateEyeDropShortcut();
    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(appProvider.isEyeDropShortcutActive, isFalse);
  });
}
