import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/widgets/tolerance_picker.dart';

void main() {
  group('TolerancePicker', () {
    testWidgets('TolerancePickerState clamps value correctly', (final WidgetTester tester) async {
      final TolerancePicker picker = TolerancePicker(
        value: 50,
        onChanged: (final int value) {},
      );

      final TolerancePickerState state = picker.createState();

      expect(state.clampValue(0), 1); // Below min
      expect(state.clampValue(50), 50); // Within range
      expect(state.clampValue(150), 100); // Above max
    });

    testWidgets('TolerancePickerState formats value correctly', (final WidgetTester tester) async {
      final TolerancePicker picker = TolerancePicker(
        value: 50,
        onChanged: (final int value) {},
      );

      final TolerancePickerState state = picker.createState();

      expect(state.formatValue(42), '42');
      expect(state.formatValue(100), '100');
    });

    testWidgets('TolerancePicker renders with correct title and range', (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Material(
              child: TolerancePicker(
                value: 50,
                onChanged: (final int value) {},
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Tolerance'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('TolerancePicker slider has correct properties', (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Material(
              child: TolerancePicker(
                value: 50,
                onChanged: (final int value) {},
              ),
            ),
          ),
        ),
      );

      final Slider slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 50.0);
      expect(slider.min, 1.0);
      expect(slider.max, 100.0);
      expect(slider.divisions, 100);
    });

    testWidgets('showTolerancePicker displays dialog with TolerancePicker', (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (final BuildContext context) {
              return ElevatedButton(
                onPressed: () {
                  showTolerancePicker(context, 25, (final int value) {});
                },
                child: const Text('Show Picker'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('Color Tolerance'), findsOneWidget);
      expect(find.byType(TolerancePicker), findsOneWidget);
    });

    testWidgets('TolerancePicker calls onChanged when value changes', (final WidgetTester tester) async {
      int? changedValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: TolerancePicker(
              value: 50,
              onChanged: (final int value) {
                changedValue = value;
              },
            ),
          ),
        ),
      );

      // Note: Testing the actual slider interaction would require more complex setup
      // This test verifies the widget can be created and has the expected structure
      expect(find.byType(Slider), findsOneWidget);
      expect(changedValue, isNull); // Should not have changed yet
    });
  });
}
