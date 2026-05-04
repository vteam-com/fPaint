import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/widgets/app_text_field.dart';

void main() {
  group('AppTextField', () {
    testWidgets('creates own controller when none provided', (final WidgetTester tester) async {
      String? changedValue;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppTextField(
            hintText: 'Enter text',
            onChanged: (final String value) => changedValue = value,
          ),
        ),
      );

      expect(find.byType(AppTextField), findsOneWidget);

      // Type some text.
      await tester.enterText(find.byType(EditableText), 'Hello');
      await tester.pump();
      expect(changedValue, 'Hello');
    });

    testWidgets('uses provided controller', (final WidgetTester tester) async {
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

    testWidgets('didUpdateWidget handles controller change', (final WidgetTester tester) async {
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

    testWidgets('onSubmitted fires', (final WidgetTester tester) async {
      String? submitted;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppTextField(
            onSubmitted: (final String value) => submitted = value,
          ),
        ),
      );

      await tester.enterText(find.byType(EditableText), 'Submit me');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(submitted, 'Submit me');
    });

    testWidgets('hint text hides while typing and returns when cleared', (final WidgetTester tester) async {
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
}
