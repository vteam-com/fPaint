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

  group('gesture tools', () {
    test('every rail gesture tool, including smudge, carries an action', () {
      final List<ActionType?> gestureActions = toolRail()
          .where((final ToolDescriptor d) => d.action != null)
          .map((final ToolDescriptor d) => d.action)
          .toList();
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

  group('toolRail and toolsInFamily', () {
    test('rail contains every gesture tool and every effect', () {
      expect(toolRail().length, kGestureToolOrder.length + SelectionEffect.values.length);
    });

    test('gesture entries come first and cover every gesture tool', () {
      final List<ToolDescriptor> gestures = toolRail().where((final ToolDescriptor d) => d.action != null).toList();
      expect(gestures.length, kGestureToolOrder.length);
      // Gesture tools lead the rail, effects follow.
      expect(toolRail().take(kGestureToolOrder.length).every((final ToolDescriptor d) => d.action != null), isTrue);
    });

    test('effect entries cover every effect', () {
      final List<ToolDescriptor> effects = toolRail().where((final ToolDescriptor d) => d.effect != null).toList();
      expect(effects.length, SelectionEffect.values.length);
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
}
