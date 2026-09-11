import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/text_tool_state.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/text_editor_dialog.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('TextEditorDialog', () {
    testWidgets('renders and can enter text', (WidgetTester tester) async {
      TextObject? result;
      await tester.pumpWidget(
        _buildDialog(
          onSubmitted: (TextObject obj) {
            result = obj;
          },
        ),
      );
      await tester.pump();

      final Finder textField = find.byType(AppTextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'Hello');
      await tester.pump();

      final Finder addTextButton = find.widgetWithText(AppButtonPrimary, 'Add Text');
      expect(addTextButton, findsOneWidget);
      await tester.tap(addTextButton);
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.text, 'Hello');
      expect(result!.color, Colors.black);
      expect(result!.size, 24);
    });

    testWidgets('cancel does not call onSubmitted', (WidgetTester tester) async {
      TextObject? result;
      await tester.pumpWidget(
        _buildDialog(
          onSubmitted: (TextObject obj) {
            result = obj;
          },
        ),
      );
      await tester.pump();

      final Finder cancelButton = find.widgetWithText(AppButtonText, 'Cancel');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pump();

      expect(result, isNull);
    });

    testWidgets('bold toggle changes font weight', (WidgetTester tester) async {
      TextObject? result;
      await tester.pumpWidget(
        _buildDialog(
          onSubmitted: (TextObject obj) {
            result = obj;
          },
        ),
      );
      await tester.pump();

      final Finder boldButton = find.byKey(Keys.textEditorBoldButton);
      expect(boldButton, findsOneWidget);
      await tester.tap(boldButton);
      await tester.pump();

      await tester.enterText(find.byType(AppTextField), 'Bold');
      await tester.pump();

      await tester.tap(find.widgetWithText(AppButtonPrimary, 'Add Text'));
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.fontWeight, FontWeight.bold);
    });

    testWidgets('alignment dropdown changes text alignment', (WidgetTester tester) async {
      TextObject? result;
      await tester.pumpWidget(
        _buildDialog(
          onSubmitted: (TextObject obj) {
            result = obj;
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(Keys.textEditorAlignmentDropdown));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Center').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(AppTextField), 'Centered');
      await tester.pump();

      await tester.tap(find.widgetWithText(AppButtonPrimary, 'Add Text'));
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.textAlign, TextAlign.center);
    });

    testWidgets('add text with empty text does not call onSubmitted', (WidgetTester tester) async {
      TextObject? result;
      await tester.pumpWidget(
        _buildDialog(
          onSubmitted: (TextObject obj) {
            result = obj;
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(AppButtonPrimary, 'Add Text'));
      await tester.pump();

      expect(result, isNull);
    });

    testWidgets('font size slider updates the submitted canvas text size', (WidgetTester tester) async {
      TextObject? result;
      await tester.pumpWidget(
        _buildDialog(
          onSubmitted: (TextObject obj) {
            result = obj;
          },
        ),
      );
      await tester.pump();

      final AppSlider slider = tester.widget<AppSlider>(find.byType(AppSlider));
      slider.onChanged!.call(48);
      await tester.pump();
      final EditableText editableText = tester.widget<EditableText>(find.byType(EditableText));
      expect(editableText.style.fontSize, AppTextStyle.input.fontSize);
      await tester.enterText(find.byType(AppTextField), 'Large');
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButtonPrimary, 'Add Text'));
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.size, 48);
    });

    testWidgets('editor text stays white for a dark canvas text color', (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildDialog(
          onSubmitted: (TextObject _) {},
        ),
      );
      await tester.pump();

      final EditableText editableText = tester.widget<EditableText>(find.byType(EditableText));
      expect(editableText.style.color, AppColors.white);
    });
  });
}

Widget _buildDialog({
  required ValueChanged<TextObject> onSubmitted,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: TextEditorDialog(
        title: 'Add Text',
        submitLabel: 'Add Text',
        position: const Offset(50, 50),
        initialText: '',
        initialStyle: TextToolState(size: 24, color: Colors.black),
        onSubmitted: onSubmitted,
      ),
    ),
  );
}
