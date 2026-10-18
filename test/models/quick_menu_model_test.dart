import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/quick_menu_model.dart';
import 'package:fpaint/models/quick_menu_slot.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/tool_descriptor.dart';
import 'package:fpaint/models/tool_kind.dart';

const Offset _anchor = Offset(120, 80);

void main() {
  late QuickMenuModel model;
  late int notifications;

  setUp(() {
    model = QuickMenuModel();
    notifications = 0;
    model.addListener(() => notifications++);
  });

  tearDown(() => model.dispose());

  test('starts closed with a full set of default tools', () {
    expect(model.isOpen, isFalse);
    expect(model.anchor, isNull);
    expect(model.recentTools, hasLength(AppLimits.quickMenuRecentToolCount));
  });

  test('opens at the anchor and closes again, notifying each time', () {
    model.open(_anchor);

    expect(model.isOpen, isTrue);
    expect(model.anchor, _anchor);

    model.close();

    expect(model.isOpen, isFalse);
    expect(notifications, 2);
  });

  test('closing an already closed menu does not notify', () {
    model.close();

    expect(notifications, 0);
  });

  test('highlights a slot only when it changes', () {
    model.open(_anchor);
    notifications = 0;

    model.highlightedSlot = 2;
    model.highlightedSlot = 2;

    expect(model.highlightedSlot, 2);
    expect(notifications, 1);
  });

  test('ending tracking clears the highlight but keeps the menu open', () {
    model.open(_anchor);
    model.highlightedSlot = 1;

    model.endTracking();

    expect(model.isOpen, isTrue);
    expect(model.highlightedSlot, isNull);
  });

  test('recording promotes a tool to the front without duplicating it', () {
    const ToolDescriptor eraser = ToolDescriptor.gesture(ToolKind.eraser);

    model.recordTool(eraser);

    expect(model.recentTools.first, eraser);
    expect(model.recentTools.where((ToolDescriptor tool) => tool == eraser), hasLength(1));
    expect(model.recentTools, hasLength(AppLimits.quickMenuRecentToolCount));
  });

  test('recording a new tool drops the least recent one', () {
    final ToolDescriptor oldest = model.recentTools.last;
    const ToolDescriptor blur = ToolDescriptor.adjust(SelectionEffect.blur);

    model.recordTool(blur);

    expect(model.recentTools.first, blur);
    expect(model.recentTools, isNot(contains(oldest)));
    expect(model.recentTools, hasLength(AppLimits.quickMenuRecentToolCount));
  });

  group('sub-rings', () {
    test('expanding sets the sub-ring and notifies once', () {
      model.open(_anchor);
      notifications = 0;

      model.expand(QuickMenuSubmenu.history);
      model.expand(QuickMenuSubmenu.history);

      expect(model.submenu, QuickMenuSubmenu.history);
      expect(notifications, 1);
    });

    test('toggling the open sub-ring collapses it; another one replaces it', () {
      model.open(_anchor);

      model.toggle(QuickMenuSubmenu.selection);
      expect(model.submenu, QuickMenuSubmenu.selection);

      model.toggle(QuickMenuSubmenu.history);
      expect(model.submenu, QuickMenuSubmenu.history);

      model.toggle(QuickMenuSubmenu.history);
      expect(model.submenu, isNull);
    });

    test('closing and reopening start with no sub-ring', () {
      model.open(_anchor);
      model.expand(QuickMenuSubmenu.selection);

      model.close();
      expect(model.submenu, isNull);

      model.open(_anchor);
      expect(model.submenu, isNull);
    });
  });
}
