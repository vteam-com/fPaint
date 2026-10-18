import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/shortcut_tooltip.dart';
import 'package:fpaint/helpers/shortcuts_constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/tool_descriptor.dart';
import 'package:fpaint/models/tool_family.dart';
import 'package:fpaint/models/tool_kind.dart';

void main() {
  late AppLocalizations l10n;

  setUp(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('gesture tools', () {
    test('every rail gesture tool, including smudge, carries a tool', () {
      final List<ToolKind?> gestureTools = <ToolDescriptor>[
        ...brushSectionTools(),
        ...elementSectionTools(),
      ].where((ToolDescriptor d) => d.tool != null).map((ToolDescriptor d) => d.tool).toList();
      expect(gestureTools, contains(ToolKind.smudge));
    });

    test('blur is not a rail gesture tool (it appears as an effect)', () {
      expect(kGestureToolOrder, contains(ToolKind.smudge));
      expect(kGestureToolOrder, isNot(contains(ToolKind.blurBrush)));
    });
  });

  group('ToolKind.label', () {
    test('maps rail actions to their localized labels', () {
      expect(ToolKind.pencil.label(l10n), l10n.toolPencil);
      expect(ToolKind.brush.label(l10n), l10n.toolBrush);
      expect(ToolKind.smudge.label(l10n), l10n.toolSmudge);
      expect(ToolKind.line.label(l10n), l10n.toolLine);
      expect(ToolKind.rectangle.label(l10n), l10n.toolRectangle);
      expect(ToolKind.circle.label(l10n), l10n.toolCircle);
      expect(ToolKind.fill.label(l10n), l10n.toolPaintBucket);
      expect(ToolKind.eraser.label(l10n), l10n.toolEraser);
      expect(ToolKind.text.label(l10n), l10n.toolText);
    });

    test('localizes the selector, which is not on the rail', () {
      expect(ToolKind.selector.label(l10n), l10n.toolSelector);
    });
  });

  group('rail composition across sections', () {
    List<ToolDescriptor> fullRail() => <ToolDescriptor>[...brushSectionTools(), ...elementSectionTools()];

    test('the two sections together contain every gesture tool and every effect', () {
      expect(fullRail().length, kGestureToolOrder.length + SelectionEffect.values.length);
    });

    test('every gesture tool is covered exactly once across the sections', () {
      final List<ToolDescriptor> gestures = fullRail().where((ToolDescriptor d) => d.tool != null).toList();
      expect(gestures.length, kGestureToolOrder.length);
    });

    test('effects live only in the Brush section and cover every effect', () {
      final List<ToolDescriptor> effects = fullRail().where((ToolDescriptor d) => d.effect != null).toList();
      expect(effects.length, SelectionEffect.values.length);
      expect(elementSectionTools().where((ToolDescriptor d) => d.effect != null), isEmpty);
    });
  });

  group('brush and element sections', () {
    List<ToolKind> gestureToolsOf(List<ToolDescriptor> tools) =>
        tools.where((ToolDescriptor d) => d.tool != null).map((ToolDescriptor d) => d.tool!).toList();

    test('Brush section holds the freehand painters plus every effect', () {
      final List<ToolDescriptor> tools = brushSectionTools();
      expect(gestureToolsOf(tools), kBrushToolOrder);
      expect(
        gestureToolsOf(tools),
        containsAll(<ToolKind>[ToolKind.pencil, ToolKind.brush, ToolKind.smudge, ToolKind.eraser]),
      );
      // Effects live in the Brush section.
      final List<ToolDescriptor> effects = tools.where((ToolDescriptor d) => d.effect != null).toList();
      expect(effects.length, SelectionEffect.values.length);
    });

    test('Elements section is exactly the placement / shape tools', () {
      expect(gestureToolsOf(elementSectionTools()), kElementToolOrder);
      expect(
        kElementToolOrder,
        <ToolKind>[ToolKind.line, ToolKind.rectangle, ToolKind.circle, ToolKind.fill, ToolKind.text],
      );
      // The Elements section carries no effects.
      expect(elementSectionTools().where((ToolDescriptor d) => d.effect != null), isEmpty);
    });

    test('the two sections are disjoint and together cover every gesture tool', () {
      final Set<ToolKind> brush = kBrushToolOrder.toSet();
      final Set<ToolKind> element = kElementToolOrder.toSet();
      expect(brush.intersection(element), isEmpty);
      expect(<ToolKind>{...brush, ...element}, kGestureToolOrder.toSet());
      expect(kGestureToolOrder, <ToolKind>[...kBrushToolOrder, ...kElementToolOrder]);
    });
  });

  group('descriptors expose icon and label', () {
    test('gesture descriptor mirrors its action', () {
      const ToolDescriptor descriptor = ToolDescriptor.gesture(ToolKind.smudge);
      expect(descriptor.tool, ToolKind.smudge);
      expect(descriptor.effect, isNull);
      expect(descriptor.icon, ToolKind.smudge.icon);
      expect(descriptor.label(l10n), l10n.toolSmudge);
    });

    test('effect descriptor mirrors its effect', () {
      const ToolDescriptor descriptor = ToolDescriptor.adjust(SelectionEffect.blur);
      expect(descriptor.effect, SelectionEffect.blur);
      expect(descriptor.tool, isNull);
      expect(descriptor.icon, SelectionEffect.blur.icon);
      expect(descriptor.label(l10n), l10n.effectBlur);
    });
  });

  group('tool shortcuts shown in rail tooltips', () {
    test('maps the bound tools to their bare key', () {
      expect(toolShortcutLabel(ToolKind.brush), ShortcutKeys.b);
      expect(toolShortcutLabel(ToolKind.eraser), ShortcutKeys.e);
      expect(toolShortcutLabel(ToolKind.selector), ShortcutKeys.s);
      expect(toolShortcutLabel(ToolKind.fill), ShortcutKeys.f);
      expect(toolShortcutLabel(ToolKind.text), ShortcutKeys.t);
    });

    test('returns null for tools reachable from the rail only', () {
      for (final ToolKind action in <ToolKind>[
        ToolKind.pencil,
        ToolKind.smudge,
        ToolKind.blurBrush,
        ToolKind.line,
        ToolKind.rectangle,
        ToolKind.circle,
      ]) {
        expect(toolShortcutLabel(action), isNull, reason: '${action.name} has no keyboard binding');
      }
    });

    test('a gesture descriptor exposes its key, an effect never does', () {
      expect(const ToolDescriptor.gesture(ToolKind.fill).shortcut, ShortcutKeys.f);
      expect(const ToolDescriptor.gesture(ToolKind.pencil).shortcut, isNull);
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

  group('equality', () {
    test('descriptors for the same tool are equal and hash alike', () {
      expect(const ToolDescriptor.gesture(ToolKind.brush), const ToolDescriptor.gesture(ToolKind.brush));
      expect(
        const ToolDescriptor.adjust(SelectionEffect.blur).hashCode,
        const ToolDescriptor.adjust(SelectionEffect.blur).hashCode,
      );
    });

    test('descriptors for different tools are not equal', () {
      expect(const ToolDescriptor.gesture(ToolKind.brush), isNot(const ToolDescriptor.gesture(ToolKind.eraser)));
      expect(const ToolDescriptor.adjust(SelectionEffect.blur), isNot(const ToolDescriptor.gesture(ToolKind.brush)));
    });
  });
}
