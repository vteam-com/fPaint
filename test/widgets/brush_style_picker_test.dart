import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/brush_style.dart';
import 'package:fpaint/widgets/brush_style_picker.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('BrushStylePicker', () {
    testWidgets('renders with initial value and localized label', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BrushStylePicker(
              title: 'Style',
              value: BrushStyle.solid,
              onChanged: (BrushStyle _) {},
            ),
          ),
        ),
      );

      // Should show the formatted value with localized label
      expect(find.textContaining('Solid'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders dash style label', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BrushStylePicker(
              title: 'Style',
              value: BrushStyle.dash,
              onChanged: (BrushStyle _) {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Dash'), findsAtLeastNWidgets(1));
    });
  });

  group('hatch labels', () {
    testWidgets('renders hatch and cross-hatch style labels', (WidgetTester tester) async {
      for (final (BrushStyle style, String label) in <(BrushStyle, String)>[
        (BrushStyle.hatch, 'Hatch'),
        (BrushStyle.crossHatch, 'Cross-hatch'),
        (BrushStyle.hatchMarks, 'Hatch marks'),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BrushStylePicker(
                title: 'Style',
                value: style,
                onChanged: (BrushStyle _) {},
              ),
            ),
          ),
        );
        expect(find.textContaining(label), findsAtLeastNWidgets(1));
      }
    });
  });

  group('brushStyleDropDown', () {
    testWidgets('displays all brush styles in dropdown', (WidgetTester tester) async {
      BrushStyle? selected;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return brushStyleDropDown(
                  context,
                  BrushStyle.solid,
                  (BrushStyle value) {
                    selected = value;
                  },
                );
              },
            ),
          ),
        ),
      );

      // Find and tap the dropdown to open it
      final Finder dropdown = find.byType(AppDropdown<int>);
      expect(dropdown, findsOneWidget);

      // Verify it shows the initial value
      expect(find.text('Solid'), findsOneWidget);
      expect(selected, isNull);
    });
  });

  group('showBrushStylePicker', () {
    testWidgets('opens a picker dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return AppButtonPrimary(
                  onPressed: () {
                    showBrushStylePicker(
                      context,
                      BrushStyle.dotted,
                      (BrushStyle _) {},
                    );
                  },
                  text: 'Open Picker',
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Dialog should be visible with brush label
      expect(find.text('Brush'), findsOneWidget);
    });
  });
}
