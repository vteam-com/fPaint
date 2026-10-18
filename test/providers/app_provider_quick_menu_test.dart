import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/quick_menu_slot.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/tool_descriptor.dart';
import 'package:fpaint/models/tool_kind.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Offset _anchor = Offset(200, 150);
const Color _paletteColor = Color(0xFF3366CC);
const double _strengthDragPixels = AppInteraction.quickMenuStrengthDragPixelsPerUnit;
const double _strengthTolerance = 0.0001;
const ToolDescriptor _brush = ToolDescriptor.gesture(ToolKind.brush);
const ToolDescriptor _eraser = ToolDescriptor.gesture(ToolKind.eraser);
const ToolDescriptor _text = ToolDescriptor.gesture(ToolKind.text);
const ToolDescriptor _blur = ToolDescriptor.adjust(SelectionEffect.blur);
const ToolDescriptor _brightness = ToolDescriptor.adjust(SelectionEffect.brightness);
const QuickMenuSlot _select = QuickMenuSlot.command(QuickMenuCommand.selection);
const QuickMenuSlot _undo = QuickMenuSlot.command(QuickMenuCommand.undo);
const QuickMenuSlot _redo = QuickMenuSlot.command(QuickMenuCommand.redo);
const QuickMenuSlot _selectAdd = QuickMenuSlot.command(QuickMenuCommand.selectAdd);
const QuickMenuSlot _selectRemove = QuickMenuSlot.command(QuickMenuCommand.selectRemove);
const QuickMenuSlot _invert = QuickMenuSlot.command(QuickMenuCommand.invertSelection);
const QuickMenuSlot _cancel = QuickMenuSlot.command(QuickMenuCommand.cancelSelection);
const Offset _selectionCorner = Offset(10, 10);
const Offset _selectionOppositeCorner = Offset(40, 40);

void main() {
  late AppProvider appProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppPreferences preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    appProvider.undoProvider.clear();
  });

  /// Draws a small rectangular marquee and makes it visible.
  void makeSelection() {
    appProvider.selectorModel.addP1(_selectionCorner);
    appProvider.selectorModel.addP2(_selectionOppositeCorner);
    appProvider.selectorModel.isVisible = true;
  }

  group('activeTool / activateTool', () {
    test('a gesture tool is active until an effect is armed', () {
      appProvider.activateTool(_eraser);

      expect(appProvider.activeTool, _eraser);

      appProvider.activateTool(_blur);

      expect(appProvider.activeTool, _blur);
      expect(appProvider.effectBrushModel.effect, SelectionEffect.blur);
    });

    test('activating a gesture tool disarms an armed effect', () {
      appProvider.activateTool(_blur);

      appProvider.activateTool(_brush);

      expect(appProvider.effectBrushModel.effect, isNull);
      expect(appProvider.activeTool, _brush);
    });

    test('re-activating the armed effect keeps it armed', () {
      appProvider.activateTool(_blur);

      appProvider.activateTool(_blur);

      expect(appProvider.effectBrushModel.effect, SelectionEffect.blur);
    });
  });

  group('applyPaletteColor', () {
    test('sets the fill color while the paint bucket is active', () {
      appProvider.selectedTool = ToolKind.fill;

      appProvider.applyPaletteColor(_paletteColor);

      expect(appProvider.fillColor, _paletteColor);
    });

    test('sets the brush color for brushes', () {
      appProvider.selectedTool = ToolKind.brush;

      appProvider.applyPaletteColor(_paletteColor);

      expect(appProvider.brushColor, _paletteColor);
    });
  });

  group('quick menu', () {
    test('the inner ring is the recent tools followed by Select and Undo', () {
      final List<QuickMenuSlot> slots = appProvider.quickMenuSlots;

      expect(slots, hasLength(AppLimits.quickMenuRecentToolCount + 2));
      expect(slots[slots.length - 2].command, QuickMenuCommand.selection);
      expect(slots.last.command, QuickMenuCommand.undo);
      expect(slots.where((QuickMenuSlot slot) => slot.command == QuickMenuCommand.redo), isEmpty);
    });

    test('each sub-ring hangs off its parent slot', () {
      final List<QuickMenuSlot> slots = appProvider.quickMenuSlots;

      expect(slots[appProvider.quickMenuParentSlot(QuickMenuSubmenu.history)].command, QuickMenuCommand.undo);
      expect(
        slots[appProvider.quickMenuParentSlot(QuickMenuSubmenu.selection)].command,
        QuickMenuCommand.selection,
      );
    });

    test('the history ring is undo then redo; the selection ring is every mode', () {
      expect(
        appProvider.quickMenuSubmenuSlots(QuickMenuSubmenu.history).map((QuickMenuSlot slot) => slot.command),
        <QuickMenuCommand>[QuickMenuCommand.undo, QuickMenuCommand.redo],
      );
      final List<QuickMenuSlot> selectionRing = appProvider.quickMenuSubmenuSlots(QuickMenuSubmenu.selection);
      expect(
        selectionRing.take(SelectorMode.values.length).map((QuickMenuSlot slot) => slot.selectorMode),
        SelectorMode.values,
      );
      expect(
        selectionRing.skip(SelectorMode.values.length).map((QuickMenuSlot slot) => slot.command),
        <QuickMenuCommand>[
          QuickMenuCommand.selectAdd,
          QuickMenuCommand.selectRemove,
          QuickMenuCommand.invertSelection,
          QuickMenuCommand.cancelSelection,
        ],
      );
    });

    test('opening records the active tool as the most recent', () {
      appProvider.activateTool(_text);

      appProvider.openQuickMenu(_anchor);

      expect(appProvider.quickMenuModel.isOpen, isTrue);
      expect(appProvider.quickMenuModel.anchor, _anchor);
      expect(appProvider.quickMenuModel.recentTools.first, _text);
    });

    test('opening with the selector active leaves the recent tools alone', () {
      final List<ToolDescriptor> before = appProvider.quickMenuModel.recentTools;
      appProvider.selectedTool = ToolKind.selector;

      appProvider.openQuickMenu(_anchor);

      expect(appProvider.quickMenuModel.recentTools, before);
    });

    test('picking a tool slot activates and records it, then closes', () {
      appProvider.openQuickMenu(_anchor);

      appProvider.pickQuickMenuSlot(const QuickMenuSlot.tool(_blur));

      expect(appProvider.activeTool, _blur);
      expect(appProvider.quickMenuModel.recentTools.first, _blur);
      expect(appProvider.quickMenuModel.isOpen, isFalse);
    });

    test('Undo steps back and opens the history ring; Redo steps forward and keeps it', () async {
      int forwardCount = 0;
      appProvider.undoProvider.executeAction(
        name: ActionType.brush.name,
        forward: () => forwardCount++,
        backward: () => forwardCount--,
      );
      appProvider.openQuickMenu(_anchor);

      appProvider.pickQuickMenuSlot(_undo);
      await pumpEventQueue();

      expect(forwardCount, 0);
      expect(appProvider.quickMenuModel.isOpen, isTrue);
      expect(appProvider.quickMenuModel.submenu, QuickMenuSubmenu.history);

      appProvider.pickQuickMenuSlot(_redo);
      await pumpEventQueue();

      expect(forwardCount, 1);
      expect(appProvider.quickMenuModel.submenu, QuickMenuSubmenu.history);
    });

    test('Undo with only redo possible still opens the history ring', () async {
      appProvider.undoProvider.executeAction(name: ActionType.brush.name, forward: () {}, backward: () {});
      await appProvider.undoAction();
      appProvider.openQuickMenu(_anchor);

      expect(appProvider.isQuickMenuSlotEnabled(_undo, inSubmenu: false), isTrue);
      expect(appProvider.isQuickMenuSlotEnabled(_undo, inSubmenu: true), isFalse);

      appProvider.pickQuickMenuSlot(_undo);

      expect(appProvider.quickMenuModel.submenu, QuickMenuSubmenu.history);
      expect(appProvider.undoProvider.canRedo, isTrue);
    });

    test('Undo is disabled with no history at all', () {
      expect(appProvider.isQuickMenuSlotEnabled(_undo, inSubmenu: false), isFalse);
      expect(appProvider.isQuickMenuSlotEnabled(_redo, inSubmenu: true), isFalse);
    });

    test('Select toggles the selection ring without changing the tool', () {
      appProvider.openQuickMenu(_anchor);

      appProvider.pickQuickMenuSlot(_select);

      expect(appProvider.quickMenuModel.submenu, QuickMenuSubmenu.selection);
      expect(appProvider.selectedTool, ToolKind.brush);
      expect(appProvider.isQuickMenuSlotSelected(_select, inSubmenu: false), isTrue);

      appProvider.pickQuickMenuSlot(_select);

      expect(appProvider.quickMenuModel.submenu, isNull);
      expect(appProvider.quickMenuModel.isOpen, isTrue);
    });

    test('picking a selection mode switches to the selector in that mode and closes', () {
      const QuickMenuSlot lasso = QuickMenuSlot.selectorMode(SelectorMode.lasso);
      appProvider.openQuickMenu(_anchor);

      appProvider.pickQuickMenuSlot(lasso);

      expect(appProvider.selectedTool, ToolKind.selector);
      expect(appProvider.selectorModel.mode, SelectorMode.lasso);
      expect(appProvider.quickMenuModel.isOpen, isFalse);
      expect(appProvider.isQuickMenuSlotSelected(lasso, inSubmenu: true), isTrue);
      expect(appProvider.isQuickMenuSlotSelected(_select, inSubmenu: false), isTrue);
    });

    test('selection math, invert, and cancel are disabled without a selection', () {
      for (final QuickMenuSlot slot in <QuickMenuSlot>[_selectAdd, _selectRemove, _invert, _cancel]) {
        expect(appProvider.isQuickMenuSlotEnabled(slot, inSubmenu: true), isFalse);
      }
    });

    test('Cancel is enabled while the selector is armed, even with no marquee', () {
      appProvider.activateSelectorMode(SelectorMode.rectangle);

      expect(appProvider.isQuickMenuSlotEnabled(_cancel, inSubmenu: true), isTrue);
      expect(appProvider.isQuickMenuSlotEnabled(_selectAdd, inSubmenu: true), isFalse);
    });

    test('Add and Remove toggle the math and keep the selection ring open', () {
      makeSelection();
      appProvider.openQuickMenu(_anchor);
      appProvider.pickQuickMenuSlot(_select);

      expect(appProvider.isQuickMenuSlotEnabled(_selectAdd, inSubmenu: true), isTrue);

      appProvider.pickQuickMenuSlot(_selectAdd);

      expect(appProvider.selectorModel.math, SelectorMath.add);
      expect(appProvider.isQuickMenuSlotSelected(_selectAdd, inSubmenu: true), isTrue);
      expect(appProvider.quickMenuModel.submenu, QuickMenuSubmenu.selection);

      appProvider.pickQuickMenuSlot(_selectRemove);

      expect(appProvider.selectorModel.math, SelectorMath.remove);
      expect(appProvider.isQuickMenuSlotSelected(_selectAdd, inSubmenu: true), isFalse);

      appProvider.pickQuickMenuSlot(_selectRemove);

      expect(appProvider.selectorModel.math, SelectorMath.replace);
    });

    test('Cancel clears the selection, restores the previous tool, and closes', () {
      appProvider.activateSelectorMode(SelectorMode.rectangle);
      makeSelection();
      appProvider.openQuickMenu(_anchor);

      appProvider.pickQuickMenuSlot(_cancel);

      expect(appProvider.selectorModel.isVisible, isFalse);
      expect(appProvider.selectedTool, ToolKind.brush);
      expect(appProvider.quickMenuModel.isOpen, isFalse);
    });

    test('Invert flips the selection against the canvas and closes', () {
      makeSelection();
      final Rect before = appProvider.selectorModel.path1!.getBounds();
      appProvider.openQuickMenu(_anchor);

      appProvider.pickQuickMenuSlot(_invert);

      expect(appProvider.selectorModel.path1!.getBounds(), isNot(before));
      expect(appProvider.quickMenuModel.isOpen, isFalse);
    });

    test('a tool slot is selected only while it is the active tool', () {
      appProvider.activateTool(_eraser);

      expect(appProvider.isQuickMenuSlotSelected(const QuickMenuSlot.tool(_eraser), inSubmenu: false), isTrue);
      expect(appProvider.isQuickMenuSlotSelected(const QuickMenuSlot.tool(_brush), inSubmenu: false), isFalse);
    });
  });

  group('selection brush', () {
    test('the brush size applies while the selector paints with a brush', () {
      appProvider.activateSelectorMode(SelectorMode.lasso);
      expect(appProvider.isSelectionBrushActive, isFalse);
      expect(appProvider.canAdjustBrushSize, isFalse);

      appProvider.activateSelectorMode(SelectorMode.brush);

      expect(appProvider.isSelectionBrushActive, isTrue);
      expect(appProvider.canAdjustBrushSize, isTrue);
    });

    test('the selection ring offers the selection brush', () {
      expect(
        appProvider.quickMenuSubmenuSlots(QuickMenuSubmenu.selection).map((QuickMenuSlot slot) => slot.selectorMode),
        contains(SelectorMode.brush),
      );
    });
  });

  group('applyEffectStrengthDrag', () {
    test('dragging up strengthens the armed effect', () {
      appProvider.activateTool(_blur);

      appProvider.applyEffectStrengthDrag(startStrength: AppEffects.minIntensity, screenDy: -_strengthDragPixels / 2);

      expect(appProvider.effectBrushModel.strength, closeTo(0.5, _strengthTolerance));
    });

    test('a unipolar effect clamps at zero', () {
      appProvider.activateTool(_blur);

      appProvider.applyEffectStrengthDrag(startStrength: AppEffects.minIntensity, screenDy: _strengthDragPixels);

      expect(appProvider.effectBrushModel.strength, AppEffects.minIntensity);
    });

    test('a bipolar effect can go negative down to its floor', () {
      appProvider.activateTool(_brightness);

      appProvider.applyEffectStrengthDrag(startStrength: AppEffects.minIntensity, screenDy: _strengthDragPixels * 3);

      expect(appProvider.effectBrushModel.strength, -AppEffects.maxIntensity);
    });

    test('does nothing without an armed effect', () {
      final double before = appProvider.effectBrushModel.strength;

      appProvider.applyEffectStrengthDrag(startStrength: AppEffects.minIntensity, screenDy: -_strengthDragPixels);

      expect(appProvider.effectBrushModel.strength, before);
    });
  });
}
