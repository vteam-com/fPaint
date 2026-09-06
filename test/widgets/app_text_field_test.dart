import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/widgets/app_text_field.dart';

void main() {
  group('AppTextField', () {
    testWidgets('creates own controller when none provided', (WidgetTester tester) async {
      String? changedValue;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppTextField(
            hintText: 'Enter text',
            onChanged: (String value) => changedValue = value,
          ),
        ),
      );

      expect(find.byType(AppTextField), findsOneWidget);

      // Type some text.
      await tester.enterText(find.byType(EditableText), 'Hello');
      await tester.pump();
      expect(changedValue, 'Hello');
    });

    testWidgets('uses provided controller', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(text: 'Initial');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppTextField(controller: controller),
        ),
      );

      expect(controller.text, 'Initial');
      controller.dispose();
    });

    testWidgets('didUpdateWidget handles controller change', (WidgetTester tester) async {
      final TextEditingController controller1 = TextEditingController(text: 'One');
      final TextEditingController controller2 = TextEditingController(text: 'Two');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppTextField(controller: controller1),
        ),
      );

      // Rebuild with a different controller.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppTextField(controller: controller2),
        ),
      );

      // Rebuild with no controller (should create its own).
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: AppTextField(),
        ),
      );

      controller1.dispose();
      controller2.dispose();
    });

    testWidgets('onSubmitted fires', (WidgetTester tester) async {
      String? submitted;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppTextField(
            onSubmitted: (String value) => submitted = value,
          ),
        ),
      );

      await tester.enterText(find.byType(EditableText), 'Submit me');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(submitted, 'Submit me');
    });

    testWidgets('hint text hides while typing and returns when cleared', (WidgetTester tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: AppTextField(hintText: 'Enter text'),
        ),
      );

      expect(find.text('Enter text'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'Hello');
      await tester.pump();

      expect(find.text('Enter text'), findsNothing);

      await tester.enterText(find.byType(EditableText), '');
      await tester.pump();

      expect(find.text('Enter text'), findsOneWidget);
    });
  });

  group('AppTextField selection', () {
    testWidgets('uses the app text selection highlight color', (WidgetTester tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: AppTextField(),
        ),
      );

      final EditableText editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.selectionColor, AppColors.textSelection);
    });

    testWidgets('ctrl+A selects the entire text', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppTextField(controller: controller),
        ),
      );

      await tester.enterText(find.byType(EditableText), 'Hello world');
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(controller.selection.baseOffset, 0);
      expect(controller.selection.extentOffset, controller.text.length);
      controller.dispose();
    });

    testWidgets('tap focuses the field and places the cursor', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(text: '1024');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppTextField(controller: controller),
        ),
      );

      await tester.tap(find.byType(AppTextField));
      await tester.pump();

      final EditableTextState editable = tester.state<EditableTextState>(find.byType(EditableText));
      expect(editable.widget.focusNode.hasFocus, isTrue);
      expect(controller.selection.isValid, isTrue);
      expect(controller.selection.isCollapsed, isTrue);
      controller.dispose();
    });

    testWidgets('selectAllOnFocus selects everything on first click only', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(text: '1024');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppTextField(
            controller: controller,
            selectAllOnFocus: true,
          ),
        ),
      );

      await tester.tap(find.byType(AppTextField));
      await tester.pump();

      expect(controller.selection.baseOffset, 0);
      expect(controller.selection.extentOffset, controller.text.length);

      // A second click on the already focused field places the cursor instead.
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byType(AppTextField));
      await tester.pump();

      expect(controller.selection.isCollapsed, isTrue);
      controller.dispose();
    });
  });
}
