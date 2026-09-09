import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/hatch_marks.dart';
import 'package:fpaint/widgets/hatch_marks_picker.dart';
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

  testWidgets('HatchMarksControls reports every edited field', (WidgetTester tester) async {
    final List<HatchMarks> changes = <HatchMarks>[];
    await tester.pumpWidget(host(HatchMarksControls(marks: const HatchMarks(), onChanged: changes.add)));

    expect(find.text('Length'), findsOneWidget);
    expect(find.text('Taper'), findsOneWidget);
    expect(find.text('Curve'), findsOneWidget);

    tester.widget<AppSlider>(find.byKey(Keys.hatchMarksAngleSlider)).onChanged!(270);
    tester.widget<AppSlider>(find.byKey(Keys.hatchMarksSpacingSlider)).onChanged!(9);
    tester.widget<AppSlider>(find.byKey(Keys.hatchMarksLengthSlider)).onChanged!(80);
    tester.widget<AppSlider>(find.byKey(Keys.hatchMarksTaperSlider)).onChanged!(50);
    tester.widget<AppSlider>(find.byKey(Keys.hatchMarksCurveSlider)).onChanged!(-30);
    await tester.pump();

    expect(
      changes.last,
      const HatchMarks(angleDegrees: 270, spacing: 9, length: 80, taperPercent: 50, curvePercent: -30),
    );
    expect(find.text('80 px'), findsOneWidget);
    expect(find.text('-30%'), findsOneWidget);
  });

  testWidgets('showHatchMarksPicker opens a titled sheet', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (BuildContext context) {
            return AppButtonPrimary(
              text: 'Open',
              onPressed: () => showHatchMarksPicker(
                context: context,
                marks: const HatchMarks(),
                onChanged: (HatchMarks _) {},
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Hatch marks'), findsOneWidget);
    expect(find.byType(HatchMarksControls), findsOneWidget);
  });
}
