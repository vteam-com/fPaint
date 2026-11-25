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

  group('BrushLibrary', () {
    testWidgets('lists every style as a tile under its category heading', (WidgetTester tester) async {
      BrushStyle? selected;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: BrushLibrary(
                value: BrushStyle.solid,
                onChanged: (BrushStyle value) => selected = value,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final BrushStyle style in BrushStyle.values) {
        expect(find.byKey(ValueKey<BrushStyle>(style)), findsOneWidget);
      }
      expect(find.text('Lines'), findsOneWidget);
      expect(find.text('Sketching'), findsOneWidget);
      expect(find.text('Inking'), findsOneWidget);
      expect(find.byType(BrushStrokePreview), findsNWidgets(BrushStyle.values.length));

      await tester.ensureVisible(find.byKey(const ValueKey<BrushStyle>(BrushStyle.grain)));
      await tester.tap(find.byKey(const ValueKey<BrushStyle>(BrushStyle.grain)));
      expect(selected, BrushStyle.grain);
    });

    test('every style belongs to exactly one category', () {
      final List<BrushStyle> listed = BrushStyleCategory.values
          .expand((BrushStyleCategory category) => category.styles)
          .toList();
      expect(listed.toSet(), BrushStyle.values.toSet());
      expect(listed.length, BrushStyle.values.length);
    });

    test('preview path stays inside the preview bounds', () {
      const Size size = Size(100, 40);
      final Rect bounds = brushPreviewPath(size).getBounds();
      expect((Offset.zero & size).contains(bounds.topLeft), isTrue);
      expect((Offset.zero & size).contains(bounds.bottomRight), isTrue);
    });
  });

  group('BrushStyleSwatch', () {
    testWidgets('shows the style name and reports taps', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BrushStyleSwatch(value: BrushStyle.soft, onTap: () => taps++),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Soft'), findsOneWidget);
      await tester.tap(find.byType(BrushStyleSwatch));
      expect(taps, 1);
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

      // The sheet should show the brush library.
      expect(find.text('Brush library'), findsOneWidget);
      expect(find.byType(BrushLibrary), findsOneWidget);
    });
  });
}
