import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/widgets/brush_intensity_picker.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/widget_test_harness.dart';

const String _pickerTitle = 'Strength';
const double _initialIntensity = 0.5;
const String _initialIntensityLabel = '50%';

void main() {
  group('BrushIntensityPicker', () {
    testWidgets('renders the slider over the effect intensity range with a percent label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildLocalizedTestApp(
          home: Scaffold(
            body: BrushIntensityPicker(
              title: _pickerTitle,
              value: _initialIntensity,
              onChanged: (double _) {},
            ),
          ),
        ),
      );

      final AppSlider slider = tester.widget<AppSlider>(find.byType(AppSlider));
      expect(slider.min, AppEffects.minIntensity);
      expect(slider.max, AppEffects.maxIntensity);
      expect(slider.value, _initialIntensity);
      expect(find.textContaining(_initialIntensityLabel), findsWidgets);
    });

    testWidgets('showBrushIntensityPicker opens a bottom sheet with the picker', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildLocalizedScaffoldTestApp(
          bodyBuilder: (BuildContext context) => Center(
            child: GestureDetector(
              onTap: () => showBrushIntensityPicker(
                context: context,
                title: _pickerTitle,
                value: _initialIntensity,
                onChanged: (double _) {},
              ),
              child: const Text(_pickerTitle),
            ),
          ),
        ),
      );

      await tester.tap(find.text(_pickerTitle));
      await tester.pumpAndSettle();

      expect(find.byType(BrushIntensityPicker), findsOneWidget);
    });
  });
}
