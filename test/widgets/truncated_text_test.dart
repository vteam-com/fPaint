import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/widgets/truncated_text.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('TruncatedTextWidget', () {
    testWidgets('displays short text without truncation', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TruncatedTextWidget(text: 'Short'),
        ),
      );

      expect(find.text('Short'), findsOneWidget);
    });

    testWidgets('truncates long text with ellipsis', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TruncatedTextWidget(text: 'VeryLongText', maxLength: 6),
        ),
      );

      expect(find.text('Ver…ext'), findsOneWidget);
    });

    testWidgets('uses default maxLength of 6', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TruncatedTextWidget(text: 'VeryLongText'),
        ),
      );

      expect(find.text('Ver…ext'), findsOneWidget);
    });

    testWidgets('handles very short maxLength', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TruncatedTextWidget(text: 'Test', maxLength: 2),
        ),
      );

      expect(find.text('T…t'), findsOneWidget);
    });

    testWidgets('handles empty text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TruncatedTextWidget(text: ''),
        ),
      );

      expect(find.text(''), findsOneWidget);
    });

    testWidgets('handles text exactly at maxLength', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TruncatedTextWidget(text: 'Exact', maxLength: 5),
        ),
      );

      expect(find.text('Exact'), findsOneWidget);
    });

    testWidgets('renders with correct styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TruncatedTextWidget(text: 'Test'),
        ),
      );

      final Text textWidget = tester.widget<Text>(find.text('Test'));
      expect(textWidget.style?.fontSize, AppFontSize.small);
      expect(textWidget.style?.color, AppColors.white);
    });

    testWidgets('uses SizedBox with infinite width', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TruncatedTextWidget(text: 'Test'),
        ),
      );

      final SizedBox sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, double.infinity);
    });
  });
}
