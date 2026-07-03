import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
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

  group('tool families', () {
    test('every rail gesture tool, including smudge, is in the Draw family', () {
      final List<ActionType?> drawActions = toolsInFamily(
        ToolFamily.draw,
      ).map((final ToolDescriptor d) => d.action).toList();
      expect(drawActions, contains(ActionType.smudge));
      expect(
        toolsInFamily(ToolFamily.draw).every((final ToolDescriptor d) => d.action != null),
        isTrue,
      );
    });

    test('blur is not a rail gesture tool (it lives under Adjust)', () {
      expect(kGestureToolOrder, contains(ActionType.smudge));
      expect(kGestureToolOrder, isNot(contains(ActionType.blurBrush)));
    });
  });

  group('toolFamilyLabel', () {
    test('maps each family to its localized header', () {
      expect(toolFamilyLabel(l10n, ToolFamily.draw), l10n.toolFamilyDraw);
      expect(toolFamilyLabel(l10n, ToolFamily.adjust), l10n.toolFamilyAdjust);
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

  group('toolRail and toolsInFamily', () {
    test('rail contains every gesture tool and every effect', () {
      expect(toolRail().length, kGestureToolOrder.length + SelectionEffect.values.length);
    });

    test('draw family lists all gesture tools as gesture descriptors', () {
      final List<ToolDescriptor> draw = toolsInFamily(ToolFamily.draw);
      expect(draw.length, kGestureToolOrder.length);
      expect(draw.every((final ToolDescriptor d) => d.action != null), isTrue);
    });

    test('adjust family lists every effect as adjust descriptors', () {
      final List<ToolDescriptor> adjust = toolsInFamily(ToolFamily.adjust);
      expect(adjust.length, SelectionEffect.values.length);
      expect(adjust.every((final ToolDescriptor d) => d.effect != null), isTrue);
    });
  });

  group('descriptors expose family, icon, and label', () {
    test('gesture descriptor mirrors its action', () {
      const ToolDescriptor descriptor = ToolDescriptor.gesture(ActionType.smudge);
      expect(descriptor.family, ToolFamily.draw);
      expect(descriptor.icon, ActionType.smudge.icon);
      expect(descriptor.label(l10n), l10n.toolSmudge);
    });

    test('adjust descriptor mirrors its effect', () {
      const ToolDescriptor descriptor = ToolDescriptor.adjust(SelectionEffect.blur);
      expect(descriptor.family, ToolFamily.adjust);
      expect(descriptor.icon, SelectionEffect.blur.icon);
      expect(descriptor.label(l10n), l10n.effectBlur);
    });
  });
}
