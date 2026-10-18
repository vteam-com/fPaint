import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/shortcut_tooltip.dart';
import 'package:fpaint/helpers/shortcuts_constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_command.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/tool_family.dart';
import 'package:fpaint/models/tool_kind.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('AppCommand', () {
    test('every command has an icon and shortcut-less commands keep the bare label', () {
      for (final AppCommand command in AppCommand.values) {
        expect(command.icon, isA<AppIcon>());
        if (command.shortcut == null) {
          expect(command.tooltip('label'), 'label');
        } else {
          expect(command.tooltip('label'), contains(command.shortcut));
        }
      }
    });

    test('undo, redo and zoom advertise their primary-modifier bindings', () {
      expect(AppCommand.undo.shortcut, primaryModifiedShortcut(ShortcutKeys.z));
      expect(AppCommand.redo.shortcut, primaryModifiedShortcut(ShortcutKeys.y));
      expect(AppCommand.zoomIn.shortcut, primaryModifiedShortcut(ShortcutKeys.plus));
      expect(AppCommand.zoomOut.shortcut, primaryModifiedShortcut(ShortcutKeys.minus));
      expect(AppCommand.paste.shortcut, primaryModifiedShortcut(ShortcutKeys.v));
    });

    test('selector reuses the tool shortcut table', () {
      expect(AppCommand.selector.shortcut, toolShortcutLabel(ToolKind.selector));
    });
  });

  group('ToolKind.brushSizeRange', () {
    test('pencil starts at one pixel and caps at the paint range', () {
      final BrushSizeRange range = ToolKind.pencil.brushSizeRange();
      expect(range.min, AppMath.one.toDouble());
      expect(range.max, AppLimits.percentMax.toDouble());
    });

    test('pixel brushes use the large pixel-brush range', () {
      for (final ToolKind action in <ToolKind>[ToolKind.smudge, ToolKind.blurBrush]) {
        final BrushSizeRange range = action.brushSizeRange();
        expect(range.min, AppInteraction.minCanvasScale);
        expect(range.max, AppLimits.pixelBrushSizeMax.toDouble());
      }
    });

    test('an armed effect overrides the underlying tool range', () {
      final BrushSizeRange range = ToolKind.pencil.brushSizeRange(effectArmed: true);
      expect(range.min, AppInteraction.minCanvasScale);
      expect(range.max, AppLimits.pixelBrushSizeMax.toDouble());
    });
  });

  testWidgets('formatFractionPercent renders a localized rounded percentage', (WidgetTester tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('en'),
        delegates: AppLocalizations.localizationsDelegates,
        child: Builder(
          builder: (BuildContext context) {
            l10n = context.l10n;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(formatFractionPercent(l10n, 0.5), '50%');
    expect(formatFractionPercent(l10n, -0.25), '-25%');
  });
}
