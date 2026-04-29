import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/text_editor_dialog.dart';

void main() {
  group('TextEditorDialog', () {
    testWidgets('renders and can enter text', (final WidgetTester tester) async {
      TextObject? result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TextEditorDialog(
              initialFontSize: 24,
              initialColor: Colors.black,
              position: const Offset(50, 50),
              onFinished: (final TextObject obj) {
                result = obj;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the text field and enter text.
      final Finder textField = find.byType(AppTextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'Hello');
      await tester.pump();

      // Tap Add Text button.
      final Finder addTextButton = find.widgetWithText(AppButtonText, 'Add Text');
      expect(addTextButton, findsOneWidget);
      await tester.tap(addTextButton);
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.text, 'Hello');
      expect(result!.color, Colors.black);
      expect(result!.size, 24);
    });

    testWidgets('cancel does not call onFinished', (final WidgetTester tester) async {
      TextObject? result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TextEditorDialog(
              initialFontSize: 24,
              initialColor: Colors.black,
              position: const Offset(50, 50),
              onFinished: (final TextObject obj) {
                result = obj;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap Cancel button.
      final Finder cancelButton = find.widgetWithText(AppButtonText, 'Cancel');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pump();

      expect(result, isNull);
    });

    testWidgets('bold toggle changes font weight', (final WidgetTester tester) async {
      TextObject? result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TextEditorDialog(
              initialFontSize: 24,
              initialColor: Colors.black,
              position: const Offset(50, 50),
              onFinished: (final TextObject obj) {
                result = obj;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Toggle bold.
      final Finder boldButton = find.byKey(Keys.textEditorBoldButton);
      expect(boldButton, findsOneWidget);
      await tester.tap(boldButton);
      await tester.pump();

      // Enter text and submit.
      final Finder textField = find.byType(AppTextField);
      await tester.enterText(textField, 'Bold');
      await tester.pump();

      final Finder addTextButton = find.widgetWithText(AppButtonText, 'Add Text');
      await tester.tap(addTextButton);
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.fontWeight, FontWeight.bold);
    });

    testWidgets('font size slider changes font size', (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TextEditorDialog(
              initialFontSize: 24,
              initialColor: Colors.black,
              position: const Offset(50, 50),
              onFinished: (final TextObject _) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the slider and drag it.
      final Finder slider = find.byType(AppSlider);
      expect(slider, findsOneWidget);

      // Drag the slider to change font size.
      await tester.drag(slider, const Offset(50, 0));
      await tester.pump();
    });

    testWidgets('add text with empty text does not call onFinished', (final WidgetTester tester) async {
      TextObject? result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TextEditorDialog(
              initialFontSize: 24,
              initialColor: Colors.black,
              position: const Offset(50, 50),
              onFinished: (final TextObject obj) {
                result = obj;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Don't enter text, just tap Add Text.
      final Finder addTextButton = find.widgetWithText(AppButtonText, 'Add Text');
      await tester.tap(addTextButton);
      await tester.pump();

      expect(result, isNull);
    });
  });
}
