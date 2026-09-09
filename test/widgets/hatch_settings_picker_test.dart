import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/hatch_pattern.dart';
import 'package:fpaint/widgets/hatch_settings_picker.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group('HatchSettingsControls', () {
    testWidgets('reports every edited field as a whole pattern', (WidgetTester tester) async {
      final List<HatchPattern> changes = <HatchPattern>[];
      await tester.pumpWidget(
        host(
          HatchSettingsControls(
            pattern: const HatchPattern(),
            onChanged: changes.add,
          ),
        ),
      );

      expect(find.text('Angle'), findsOneWidget);
      expect(find.text('Spacing'), findsOneWidget);
      expect(find.text('Line weight'), findsOneWidget);
      expect(find.text('${AppHatch.defaultAngleDegrees}°'), findsOneWidget);

      tester.widget<AppSlider>(find.byKey(Keys.hatchAngleSlider)).onChanged!(90);
      await tester.pump();
      expect(changes.last.angleDegrees, 90);
      expect(find.text('90°'), findsOneWidget);

      tester.widget<AppSlider>(find.byKey(Keys.hatchSpacingSlider)).onChanged!(12);
      await tester.pump();
      expect(changes.last.spacing, 12);
      expect(changes.last.angleDegrees, 90);

      tester.widget<AppSlider>(find.byKey(Keys.hatchLineWidthSlider)).onChanged!(3);
      await tester.pump();
      expect(changes.last.lineWidth, 3);

      await tester.tap(find.byKey(Keys.hatchCrossedToggle));
      await tester.pump();
      expect(changes.last.crossed, isTrue);
      expect(tester.widget<AppSwitch>(find.byKey(Keys.hatchCrossedToggle)).value, isTrue);
    });

    testWidgets('follows a new pattern pushed by the parent', (WidgetTester tester) async {
      final ValueNotifier<HatchPattern> pattern = ValueNotifier<HatchPattern>(const HatchPattern());
      addTearDown(pattern.dispose);
      await tester.pumpWidget(
        host(
          ValueListenableBuilder<HatchPattern>(
            valueListenable: pattern,
            builder: (BuildContext _, HatchPattern value, Widget? _) {
              return HatchSettingsControls(pattern: value, onChanged: (HatchPattern _) {});
            },
          ),
        ),
      );
      pattern.value = const HatchPattern(spacing: 20);
      await tester.pump();
      expect(find.text('20 px'), findsOneWidget);
    });
  });

  group('showHatchSettingsPicker', () {
    testWidgets('opens a titled sheet with the controls', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (BuildContext context) {
              return AppButtonPrimary(
                text: 'Open',
                onPressed: () => showHatchSettingsPicker(
                  context: context,
                  pattern: const HatchPattern(),
                  onChanged: (HatchPattern _) {},
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Hatching'), findsOneWidget);
      expect(find.byType(HatchSettingsControls), findsOneWidget);
    });
  });
}
