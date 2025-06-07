import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/widgets/brush_size_picker.dart';

void main() {
  group('BrushSizePicker Widget Tests', () {
    testWidgets('Initial rendering reflects input properties', (WidgetTester tester) async {
      const String title = 'Test Brush Size';
      const double initialValue = 15.0;
      const double minValue = 1.0;
      const double maxValue = 100.0;
      double changedValue = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrushSizePicker(
              title: title,
              value: initialValue,
              min: minValue,
              max: maxValue,
              onChanged: (value) {
                changedValue = value;
              },
            ),
          ),
        ),
      );

      expect(find.text('$title: ${initialValue.toStringAsFixed(1)}'), findsOneWidget);

      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);
      final Slider sliderWidget = tester.widget(slider);
      expect(sliderWidget.value, initialValue);
      expect(sliderWidget.min, minValue);
      expect(sliderWidget.max, maxValue);
    });

    testWidgets('Slider interaction calls onChanged and updates UI', (WidgetTester tester) async {
      const String title = 'My Size';
      double currentValue = 20.0;
      double? reportedValue;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return MaterialApp(
              home: Scaffold(
                body: BrushSizePicker(
                  title: title,
                  value: currentValue,
                  min: 5.0,
                  max: 50.0,
                  onChanged: (value) {
                    setState(() {
                      currentValue = value; // Simulate parent updating the state
                      reportedValue = value;
                    });
                  },
                ),
              ),
            );
          },
        ),
      );

      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      // Drag slider to a new value
      await tester.drag(sliderFinder, const Offset(100.0, 0.0)); // Drag right
      await tester.pumpAndSettle();

      expect(reportedValue, isNotNull);
      // currentValue should have been updated by the ValueChanged callback in StatefulBuilder
      expect(find.text('$title: ${currentValue.toStringAsFixed(1)}'), findsOneWidget);
      final Slider updatedSliderWidget = tester.widget(sliderFinder);
      expect(updatedSliderWidget.value, currentValue);


      // More precise value setting using onChanged directly
      final Slider sliderWidget = tester.widget(sliderFinder);
      sliderWidget.onChanged!(35.5);
      await tester.pumpAndSettle();

      expect(reportedValue, 35.5);
      expect(currentValue, 35.5);
      expect(find.text('$title: ${currentValue.toStringAsFixed(1)}'), findsOneWidget);
      final Slider finalSliderWidget = tester.widget(sliderFinder);
      expect(finalSliderWidget.value, 35.5);
    });

    testWidgets('didUpdateWidget updates slider if value changes', (WidgetTester tester) async {
      double value = 10.0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrushSizePicker(
              title: 'Test',
              value: value,
              min: 1.0,
              max: 50.0,
              onChanged: (v) {},
            ),
          ),
        ),
      );

      Slider sliderWidget = tester.widget(find.byType(Slider));
      expect(sliderWidget.value, 10.0);
      expect(find.text('Test: 10.0'), findsOneWidget);

      // Change value and rebuild
      value = 25.0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrushSizePicker(
              title: 'Test',
              value: value,
              min: 1.0,
              max: 50.0,
              onChanged: (v) {},
            ),
          ),
        ),
      );

      sliderWidget = tester.widget(find.byType(Slider));
      expect(sliderWidget.value, 25.0);
      expect(find.text('Test: 25.0'), findsOneWidget);
    });

    testWidgets('Value is clamped to min/max on init and update', (WidgetTester tester) async {
      // Test clamping on initial build
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrushSizePicker(
              title: 'Clamped',
              value: 0.0, // Below min
              min: 5.0,
              max: 20.0,
              onChanged: (v) {},
            ),
          ),
        ),
      );
      Slider sliderWidget = tester.widget(find.byType(Slider));
      expect(sliderWidget.value, 5.0); // Should be clamped to min
      expect(find.text('Clamped: 5.0'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrushSizePicker(
              title: 'Clamped',
              value: 30.0, // Above max
              min: 5.0,
              max: 20.0,
              onChanged: (v) {},
            ),
          ),
        ),
      );
      sliderWidget = tester.widget(find.byType(Slider));
      expect(sliderWidget.value, 20.0); // Should be clamped to max
      expect(find.text('Clamped: 20.0'), findsOneWidget);

      // Test clamping on update
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrushSizePicker(
              title: 'ClampedUpdate',
              value: 10.0,
              min: 5.0,
              max: 20.0,
              onChanged: (v) {},
            ),
          ),
        ),
      );
      sliderWidget = tester.widget(find.byType(Slider));
      expect(sliderWidget.value, 10.0);

      // Update with value below new min
       await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrushSizePicker(
              title: 'ClampedUpdate',
              value: 3.0,
              min: 4.0, // New min
              max: 20.0,
              onChanged: (v) {},
            ),
          ),
        ),
      );
      sliderWidget = tester.widget(find.byType(Slider));
      expect(sliderWidget.value, 4.0); // Clamped to new min
      expect(find.text('ClampedUpdate: 4.0'), findsOneWidget);
    });
  });

  group('showBrushSizePicker Utility', () {
    testWidgets('showBrushSizePicker calls showDialog with BrushSizePicker', (WidgetTester tester) async {
      double changedValue = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showBrushSizePicker(
                      context: context,
                      title: 'Dialog Test',
                      value: 25.0,
                      min: 1.0,
                      max: 50.0,
                      onChanged: (value) {
                        changedValue = value;
                      },
                    );
                  },
                  child: const Text('Show Size Picker'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Size Picker'));
      await tester.pumpAndSettle(); // Allow dialog to show

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Select Dialog Test'), findsOneWidget); // Dialog title
      expect(find.byType(BrushSizePicker), findsOneWidget);

      // Check if BrushSizePicker inside dialog has correct initial values
      final BrushSizePicker pickerInDialog = tester.widget(find.byType(BrushSizePicker));
      expect(pickerInDialog.title, 'Dialog Test');
      expect(pickerInDialog.value, 25.0);

      // Simulate changing value in the dialog's picker
      final sliderInDialog = find.descendant(of: find.byType(AlertDialog), matching: find.byType(Slider));
      expect(sliderInDialog, findsOneWidget);

      // Directly call onChanged on the slider inside the dialog
      final Slider sliderWidget = tester.widget(sliderInDialog);
      sliderWidget.onChanged!(33.0);
      await tester.pumpAndSettle(); // For AlertDialog content update if any

      expect(changedValue, 33.0); // Check if the callback was propagated

      // Close dialog
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
