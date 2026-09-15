import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/shortcut_tooltip.dart';
import 'package:fpaint/helpers/shortcuts_constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/tool_descriptor.dart';
import 'package:fpaint/models/tool_family.dart';
import 'package:fpaint/models/user_action_drawing.dart';

void main() {
  late AppLocalizations l10n;

  setUp(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('gesture tools', () {
    test('every rail gesture tool, including smudge, carries an action', () {
      final List<ActionType?> gestureActions = <ToolDescriptor>[
        ...brushSectionTools(),
        ...elementSectionTools(),
      ].where((ToolDescriptor d) => d.action != null).map((ToolDescriptor d) => d.action).toList();
      expect(gestureActions, contains(ActionType.smudge));
    });

    test('blur is not a rail gesture tool (it appears as an effect)', () {
      expect(kGestureToolOrder, contains(ActionType.smudge));
      expect(kGestureToolOrder, isNot(contains(ActionType.blurBrush)));
    });
  });

  group('toolLabel', () {
    test('maps rail actions to their localized labels', () {
      expect(toolLabel(l10n, ActionType.pencil), l10n.toolPencil);
      expect(toolLabel(l10n, ActionType.brush), l10n.toolBrush);
      expect(toolLabel(l10n, ActionType.smudge), l10n.toolSmudge);
      expect(toolLabel(l10n, ActionType.line), l10n.toolLine);
      expect(toolLabel(l10n, ActionType.rectangle), l10n.toolRectangle);
      expect(toolLabel(l10n, ActionType.circle), l10n.toolCircle);
      expect(toolLabel(l10n, ActionType.fill), l10n.toolPaintBucket);
      expect(toolLabel(l10n, ActionType.eraser), l10n.toolEraser);
      expect(toolLabel(l10n, ActionType.text), l10n.toolText);
    });

    test('falls back to the enum name for non-rail actions', () {
      expect(toolLabel(l10n, ActionType.selector), ActionType.selector.name);
      expect(toolLabel(l10n, ActionType.region), ActionType.region.name);
      expect(toolLabel(l10n, ActionType.image), ActionType.image.name);
      expect(toolLabel(l10n, ActionType.cut), ActionType.cut.name);
    });
  });

  group('rail composition across sections', () {
    List<ToolDescriptor> fullRail() => <ToolDescriptor>[...brushSectionTools(), ...elementSectionTools()];

    test('the two sections together contain every gesture tool and every effect', () {
      expect(fullRail().length, kGestureToolOrder.length + SelectionEffect.values.length);
    });

    test('every gesture tool is covered exactly once across the sections', () {
      final List<ToolDescriptor> gestures = fullRail().where((ToolDescriptor d) => d.action != null).toList();
      expect(gestures.length, kGestureToolOrder.length);
    });

    test('effects live only in the Brush section and cover every effect', () {
      final List<ToolDescriptor> effects = fullRail().where((ToolDescriptor d) => d.effect != null).toList();
      expect(effects.length, SelectionEffect.values.length);
      expect(elementSectionTools().where((ToolDescriptor d) => d.effect != null), isEmpty);
    });
  });

  group('brush and element sections', () {
    List<ActionType> gestureActionsOf(List<ToolDescriptor> tools) =>
        tools.where((ToolDescriptor d) => d.action != null).map((ToolDescriptor d) => d.action!).toList();

    test('Brush section holds the freehand painters plus every effect', () {
      final List<ToolDescriptor> tools = brushSectionTools();
      expect(gestureActionsOf(tools), kBrushToolOrder);
      expect(
        gestureActionsOf(tools),
        containsAll(<ActionType>[ActionType.pencil, ActionType.brush, ActionType.smudge, ActionType.eraser]),
      );
      // Effects live in the Brush section.
      final List<ToolDescriptor> effects = tools.where((ToolDescriptor d) => d.effect != null).toList();
      expect(effects.length, SelectionEffect.values.length);
    });

    test('Elements section is exactly the placement / shape tools', () {
      expect(gestureActionsOf(elementSectionTools()), kElementToolOrder);
      expect(
        kElementToolOrder,
        <ActionType>[ActionType.line, ActionType.rectangle, ActionType.circle, ActionType.fill, ActionType.text],
      );
      // The Elements section carries no effects.
      expect(elementSectionTools().where((ToolDescriptor d) => d.effect != null), isEmpty);
    });

    test('the two sections are disjoint and together cover every gesture tool', () {
      final Set<ActionType> brush = kBrushToolOrder.toSet();
      final Set<ActionType> element = kElementToolOrder.toSet();
      expect(brush.intersection(element), isEmpty);
      expect(<ActionType>{...brush, ...element}, kGestureToolOrder.toSet());
      expect(kGestureToolOrder, <ActionType>[...kBrushToolOrder, ...kElementToolOrder]);
    });
  });

  group('descriptors expose icon and label', () {
    test('gesture descriptor mirrors its action', () {
      const ToolDescriptor descriptor = ToolDescriptor.gesture(ActionType.smudge);
      expect(descriptor.action, ActionType.smudge);
      expect(descriptor.effect, isNull);
      expect(descriptor.icon, ActionType.smudge.icon);
      expect(descriptor.label(l10n), l10n.toolSmudge);
    });

    test('effect descriptor mirrors its effect', () {
      const ToolDescriptor descriptor = ToolDescriptor.adjust(SelectionEffect.blur);
      expect(descriptor.effect, SelectionEffect.blur);
      expect(descriptor.action, isNull);
      expect(descriptor.icon, SelectionEffect.blur.icon);
      expect(descriptor.label(l10n), l10n.effectBlur);
    });
  });

  group('tool shortcuts shown in rail tooltips', () {
    test('maps the bound tools to their bare key', () {
      expect(toolShortcutLabel(ActionType.brush), ShortcutKeys.b);
      expect(toolShortcutLabel(ActionType.eraser), ShortcutKeys.e);
      expect(toolShortcutLabel(ActionType.selector), ShortcutKeys.s);
      expect(toolShortcutLabel(ActionType.fill), ShortcutKeys.f);
      expect(toolShortcutLabel(ActionType.text), ShortcutKeys.t);
    });

    test('returns null for tools reachable from the rail only', () {
      for (final ActionType action in <ActionType>[
        ActionType.pencil,
        ActionType.smudge,
        ActionType.blurBrush,
        ActionType.line,
        ActionType.rectangle,
        ActionType.circle,
      ]) {
        expect(toolShortcutLabel(action), isNull, reason: '${action.name} has no keyboard binding');
      }
    });

    test('a gesture descriptor exposes its key, an effect never does', () {
      expect(const ToolDescriptor.gesture(ActionType.fill).shortcut, ShortcutKeys.f);
      expect(const ToolDescriptor.gesture(ActionType.pencil).shortcut, isNull);
      expect(const ToolDescriptor.adjust(SelectionEffect.blur).shortcut, isNull);
    });

    test('every advertised key is a single uppercase character', () {
      for (final String key in kToolShortcutKeys.values) {
        expect(key, matches(RegExp(r'^[A-Z]$')), reason: '$key must render as one key cap');
      }
    });

    test('no two tools claim the same key', () {
      expect(kToolShortcutKeys.values.toSet().length, kToolShortcutKeys.length);
    });
  });

  group('tooltipWithShortcut', () {
    test('appends the key in parentheses when both are present', () {
      expect(tooltipWithShortcut('Brush', ShortcutKeys.b), 'Brush (B)');
    });

    test('leaves the tooltip untouched when the tool has no shortcut', () {
      expect(tooltipWithShortcut('Pencil', null), 'Pencil');
      expect(tooltipWithShortcut('Pencil', ''), 'Pencil');
    });

    test('returns null when there is no tooltip to decorate', () {
      expect(tooltipWithShortcut(null, ShortcutKeys.b), isNull);
    });
  });
}
