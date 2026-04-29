import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/widgets/container_slider.dart';
import 'package:fpaint/widgets/material_free.dart';

void main() {
  group('ContainerSlider', () {
    testWidgets('drag horizontally adjusts value', (final WidgetTester tester) async {
      double changedValue = 0.5;
      double endValue = -1;
      bool slideStarted = false;
      bool slideEnded = false;

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (final BuildContext context, final Widget? child) {
            return Center(
              child: SizedBox(
                width: 200,
                height: 50,
                child: ContainerSlider(
                  initialValue: 0.5,
                  onChanged: (final double v) => changedValue = v,
                  onChangeEnd: (final double v) => endValue = v,
                  onSlideStart: () => slideStarted = true,
                  onSlideEnd: () => slideEnded = true,
                  child: const AppText('Opacity'),
                ),
              ),
            );
          },
        ),
      );

      // Verify initial percentage display.
      expect(find.textContaining('50.0%'), findsOneWidget);

      // Perform horizontal drag.
      final Finder slider = find.byType(ContainerSlider);
      await tester.drag(slider, const Offset(100, 0));
      await tester.pump();

      expect(slideStarted, isTrue);
      expect(slideEnded, isTrue);
      expect(changedValue, isNot(0.5));
      expect(endValue, greaterThanOrEqualTo(0));
    });
  });
}
