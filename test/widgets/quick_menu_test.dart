import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/quick_menu_geometry.dart';
import 'package:fpaint/models/quick_menu_model.dart';
import 'package:fpaint/models/quick_menu_slot.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/tool_descriptor.dart';
import 'package:fpaint/models/tool_kind.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/canvas_gesture_handler.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/painting_test_helpers.dart';
import '../helpers/widget_test_harness.dart';

/// Where on the canvas each gesture starts, away from the edges.
const Offset _canvasPoint = Offset(320, 260);

/// Ring slot of the eraser once the brush is active: the menu records the
/// active tool first, so the default list starts brush, eraser, ...
const int _eraserSlot = 1;

/// Position of Redo on the history ring (undo, redo).
const int _historyRedoIndex = 1;

/// Position of Cancel on the selection ring: the modes, then add, remove,
/// invert, cancel.
final int _selectionCancelIndex = SelectorMode.values.length + 3;

/// Corners of a small marquee drawn for the selection-ring tests.
const Offset _selectionCorner = Offset(10, 10);
const Offset _selectionOppositeCorner = Offset(60, 60);

/// How far a flick travels past the menu centre.
const double _flickDistance = AppLayout.quickMenuRingRadius;

/// Extra time past the hold delay so the hold timer has surely fired.
const Duration _holdSettle = Duration(milliseconds: 50);

/// Horizontal puck drag used to grow the brush.
const Offset _puckDrag = Offset(60, 0);

/// Small right-drag that is a pan, not a click.
const Offset _panDrag = Offset(40, 0);

/// Inset from the canvas corner for a tap well clear of the menu.
const Offset _cornerInset = Offset(40, 40);

/// A quick touch stroke, well past the draw slop.
const Offset _strokeStep = Offset(30, 0);

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

Key _slotKey(int index) => ValueKey<String>('${Keys.quickMenuSlotKeyPrefixText}$index');

Key _submenuKey(int index) => ValueKey<String>('${Keys.quickMenuSubmenuKeyPrefixText}$index');

Key _colorKey(int index) => ValueKey<String>('${Keys.quickMenuColorKeyPrefixText}$index');

void main() {
  late AppPreferences preferences;
  late AppProvider appProvider;
  late ShellProvider shellProvider;

  QuickMenuModel menu() => appProvider.quickMenuModel;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    appProvider.selectedTool = ToolKind.brush;
    shellProvider = ShellProvider();
  });

  /// Pumps the main view and returns the global position of [_canvasPoint].
  Future<Offset> pumpCanvas(WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(preferences: preferences, appProvider: appProvider, shellProvider: shellProvider),
    );
    await tester.pump();
    return tester.getTopLeft(find.byType(CanvasGestureHandler)) + _canvasPoint;
  }

  /// Global position of the open menu's centre.
  Offset menuCenter(WidgetTester tester) => tester.getTopLeft(find.byType(CanvasGestureHandler)) + menu().anchor!;

  Future<void> rightClick(WidgetTester tester, Offset at) async {
    final TestGesture gesture = await tester.startGesture(at, kind: PointerDeviceKind.mouse, buttons: kSecondaryButton);
    await gesture.up();
    await tester.pump();
  }

  group('opening', () {
    testWidgets('a right-click opens the menu where it was clicked', (WidgetTester tester) async {
      final Offset point = await pumpCanvas(tester);

      await rightClick(tester, point);

      expect(menu().isOpen, isTrue);
      expect(menuCenter(tester), point);
      expect(find.byKey(Keys.quickMenu), findsOneWidget);
    });

    testWidgets('a right-drag pans instead of opening the menu', (WidgetTester tester) async {
      final Offset point = await pumpCanvas(tester);
      final Offset offsetBefore = appProvider.canvasOffset;

      final TestGesture gesture = await tester.startGesture(
        point,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await gesture.moveBy(_panDrag);
      await gesture.up();
      await tester.pump();

      expect(menu().isOpen, isFalse);
      expect(appProvider.canvasOffset, isNot(offsetBefore));
    });

    testWidgets('a pen barrel-button press opens the menu without drawing', (WidgetTester tester) async {
      final Offset point = await pumpCanvas(tester);

      final TestGesture gesture = await tester.startGesture(
        point,
        kind: PointerDeviceKind.stylus,
        buttons: kStylusContact | kSecondaryStylusButton,
      );
      await tester.pump();

      expect(menu().isOpen, isTrue);

      await gesture.up();
      await tester.pump();

      expect(menu().isOpen, isTrue, reason: 'Lifting without aiming leaves the menu open for taps.');
      expect(appProvider.layers.selectedLayer.lastUserAction, isNull);
    });

    testWidgets('a touch-and-hold opens the menu; lifting without aiming keeps it open', (
      WidgetTester tester,
    ) async {
      final Offset point = await pumpCanvas(tester);

      final TestGesture gesture = await tester.startGesture(point, kind: PointerDeviceKind.touch);
      await tester.pump(AppInteraction.quickMenuHoldDelay + _holdSettle);

      expect(menu().isOpen, isTrue);

      await gesture.up();
      await tester.pump();

      expect(menu().isOpen, isTrue);
      expect(appProvider.layers.selectedLayer.lastUserAction, isNull, reason: 'The hold must not leave a dab.');
    });

    testWidgets('a quick touch stroke still paints and never opens the menu', (WidgetTester tester) async {
      final Offset point = await pumpCanvas(tester);

      final TestGesture gesture = await tester.startGesture(point, kind: PointerDeviceKind.touch);
      await gesture.moveBy(_strokeStep);
      await gesture.moveBy(_strokeStep);
      await tester.pump(AppInteraction.quickMenuHoldDelay + _holdSettle);
      await gesture.up();
      await tester.pump();
      await tester.pump(AppDefaults.thumbnailDebounceDuration);

      expect(menu().isOpen, isFalse);
      expect(appProvider.layers.selectedLayer.lastUserAction?.action, ActionType.brush);
    });
  });

  group('picking', () {
    testWidgets('a touch-and-hold flick toward a slot picks it on release', (WidgetTester tester) async {
      final Offset point = await pumpCanvas(tester);

      final TestGesture gesture = await tester.startGesture(point, kind: PointerDeviceKind.touch);
      await tester.pump(AppInteraction.quickMenuHoldDelay + _holdSettle);
      final Offset center = menuCenter(tester);
      final Offset eraserDirection =
          quickMenuSlotCenter(
            center: Offset.zero,
            index: _eraserSlot,
            count: appProvider.quickMenuSlots.length,
          ) /
          AppLayout.quickMenuRingRadius;

      await gesture.moveTo(center + eraserDirection * _flickDistance);
      await tester.pump();

      expect(menu().highlightedSlot, _eraserSlot);

      await gesture.up();
      await tester.pump();

      expect(appProvider.selectedTool, ToolKind.eraser);
      expect(menu().isOpen, isFalse);
    });

    testWidgets('tapping a tool slot activates it and closes the menu', (WidgetTester tester) async {
      final Offset point = await pumpCanvas(tester);
      await rightClick(tester, point);

      await tapByKey(tester, _slotKey(_eraserSlot));

      expect(appProvider.activeTool, const ToolDescriptor.gesture(ToolKind.eraser));
      expect(menu().isOpen, isFalse);
    });

    testWidgets('tapping a color swatch sets the brush color and closes the menu', (WidgetTester tester) async {
      final Offset point = await pumpCanvas(tester);
      await rightClick(tester, point);
      final Color swatchColor = appProvider.layers.recentColors.colors.last;

      await tapByKey(tester, _colorKey(appProvider.layers.recentColors.colors.length - 1));

      expect(appProvider.brushColor, swatchColor);
      expect(menu().isOpen, isFalse);
    });

    testWidgets('tapping outside the menu closes it without painting', (WidgetTester tester) async {
      final Offset point = await pumpCanvas(tester);
      await rightClick(tester, point);

      await tester.tapAt(tester.getBottomRight(find.byType(CanvasGestureHandler)) - _cornerInset);
      await tester.pump();

      expect(menu().isOpen, isFalse);
      expect(appProvider.layers.selectedLayer.lastUserAction, isNull);
    });

    testWidgets('dragging the puck sideways grows the brush', (WidgetTester tester) async {
      final Offset point = await pumpCanvas(tester);
      await rightClick(tester, point);
      final double sizeBefore = appProvider.brushSize;

      await tester.drag(find.byKey(Keys.quickMenuPuck), _puckDrag);
      await tester.pump();

      expect(appProvider.brushSize, greaterThan(sizeBefore));
      expect(menu().isOpen, isTrue);
    });

    testWidgets('tapping Undo steps back and fans out the history ring with Redo', (
      WidgetTester tester,
    ) async {
      final Offset point = await pumpCanvas(tester);
      int forwardCount = 0;
      appProvider.undoProvider.executeAction(
        name: ActionType.brush.name,
        forward: () => forwardCount++,
        backward: () => forwardCount--,
      );
      await rightClick(tester, point);
      expect(find.byKey(_submenuKey(_historyRedoIndex)), findsNothing);

      await tapByKey(tester, _slotKey(appProvider.quickMenuParentSlot(QuickMenuSubmenu.history)));

      expect(forwardCount, 0);
      expect(menu().isOpen, isTrue);
      expect(find.byKey(_submenuKey(_historyRedoIndex)), findsOneWidget);

      await tapByKey(tester, _submenuKey(_historyRedoIndex));

      expect(forwardCount, 1);
      expect(menu().submenu, QuickMenuSubmenu.history, reason: 'The history ring stays open for more steps.');
    });

    testWidgets('tapping Select fans out the modes; picking one arms the selector', (WidgetTester tester) async {
      final Offset point = await pumpCanvas(tester);
      await rightClick(tester, point);

      await tapByKey(tester, _slotKey(appProvider.quickMenuParentSlot(QuickMenuSubmenu.selection)));

      expect(find.byKey(_submenuKey(SelectorMode.values.length - 1)), findsOneWidget);

      await tapByKey(tester, _submenuKey(SelectorMode.lasso.index));

      expect(appProvider.selectedTool, ToolKind.selector);
      expect(appProvider.selectorModel.mode, SelectorMode.lasso);
      expect(menu().isOpen, isFalse);
    });

    testWidgets('the selection ring cancels a live selection', (WidgetTester tester) async {
      final Offset point = await pumpCanvas(tester);
      appProvider.activateSelectorMode(SelectorMode.rectangle);
      appProvider.selectorModel.addP1(_selectionCorner);
      appProvider.selectorModel.addP2(_selectionOppositeCorner);
      appProvider.selectorModel.isVisible = true;
      await tester.pump();
      await rightClick(tester, point);
      await tapByKey(tester, _slotKey(appProvider.quickMenuParentSlot(QuickMenuSubmenu.selection)));

      await tapByKey(tester, _submenuKey(_selectionCancelIndex));

      expect(appProvider.selectorModel.isVisible, isFalse);
      expect(appProvider.selectedTool, ToolKind.brush);
      expect(menu().isOpen, isFalse);
    });

    testWidgets('a hold-and-flick onto Select opens the selection ring', (WidgetTester tester) async {
      final Offset point = await pumpCanvas(tester);
      final TestGesture gesture = await tester.startGesture(point, kind: PointerDeviceKind.touch);
      await tester.pump(AppInteraction.quickMenuHoldDelay + _holdSettle);
      final Offset selectDirection =
          quickMenuSlotCenter(
            center: Offset.zero,
            index: appProvider.quickMenuParentSlot(QuickMenuSubmenu.selection),
            count: appProvider.quickMenuSlots.length,
          ) /
          AppLayout.quickMenuRingRadius;

      await gesture.moveTo(menuCenter(tester) + selectDirection * _flickDistance);
      await gesture.up();
      await tester.pump();

      expect(menu().isOpen, isTrue);
      expect(menu().submenu, QuickMenuSubmenu.selection);
      expect(appProvider.selectedTool, ToolKind.brush);
    });
  });
}
