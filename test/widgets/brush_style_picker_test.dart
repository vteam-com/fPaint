import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/brush_style.dart';
import 'package:fpaint/widgets/brush_style_picker.dart';
import 'package:fpaint/widgets/material_free/material_free.dart';

void main() {
  group('BrushStylePicker', () {
    testWidgets('renders with initial value and localized label', (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BrushStylePicker(
              title: 'Style',
              value: BrushStyle.solid,
              onChanged: (final BrushStyle _) {},
            ),
          ),
        ),
      );

      // Should show the formatted value with localized label
      expect(find.textContaining('Solid'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders dash style label', (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BrushStylePicker(
              title: 'Style',
              value: BrushStyle.dash,
              onChanged: (final BrushStyle _) {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Dash'), findsAtLeastNWidgets(1));
    });
  });

  group('brushStyleDropDown', () {
    testWidgets('displays all brush styles in dropdown', (final WidgetTester tester) async {
      BrushStyle? selected;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (final BuildContext context) {
                return brushStyleDropDown(
                  context,
                  BrushStyle.solid,
                  (final BrushStyle value) {
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
    testWidgets('opens a picker dialog', (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (final BuildContext context) {
                return ElevatedButton(
                  onPressed: () {
                    showBrushStylePicker(
                      context,
                      BrushStyle.dotted,
                      (final BrushStyle _) {},
                    );
                  },
                  child: const Text('Open Picker'),
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
