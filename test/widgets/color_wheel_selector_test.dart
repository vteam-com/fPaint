import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/widgets/color_selector.dart';
import 'package:fpaint/widgets/color_wheel_selector.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/widget_test_harness.dart';

const Color _initialColor = Color(0xFFFF0000);
const Color _replacementColor = Color(0xFF0000FF);
const double _ringMidRadius = AppLayout.colorWheelDiameter / 2 - AppLayout.colorWheelRingThickness / 2;
const Offset _ringDragDelta = Offset(0, 60);
const Offset _triangleDragDelta = Offset(-20, 10);
const Offset _alphaDragDelta = Offset(-60, 0);
const Duration _ringDragDuration = Duration(milliseconds: 200);
const Duration _gestureStepDuration = Duration(milliseconds: 16);

void main() {
  late List<Color> reported;
  late Color hostColor;
  late StateSetter hostSetState;

  setUp(() {
    reported = <Color>[];
    hostColor = _initialColor;
  });

  Future<void> pumpWheel(WidgetTester tester) {
    return tester.pumpWidget(
      buildLocalizedScaffoldTestApp(
        bodyBuilder: (BuildContext _) => Center(
          child: StatefulBuilder(
            builder: (BuildContext _, StateSetter setState) {
              hostSetState = setState;
              return ColorWheelSelector(
                color: hostColor,
                onColorChanged: reported.add,
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets('dragging along the hue ring reports colors with a new hue', (WidgetTester tester) async {
    await pumpWheel(tester);
    final Offset center = tester.getCenter(find.byKey(Keys.colorPickerWheelSelector));

    await tester.timedDragFrom(center + const Offset(_ringMidRadius, 0), _ringDragDelta, _ringDragDuration);
    await tester.pump();

    expect(reported, isNotEmpty);
    expect(reported.last, isNot(_initialColor));

    reported.clear();
    await tester.tapAt(center + const Offset(-_ringMidRadius, 0));
    await tester.pump();
    expect(reported, isNotEmpty);
  });

  testWidgets('dragging inside the triangle and cancelling a gesture keep the wheel stable', (
    WidgetTester tester,
  ) async {
    await pumpWheel(tester);
    final Offset center = tester.getCenter(find.byKey(Keys.colorPickerWheelSelector));

    await tester.dragFrom(center, _triangleDragDelta);
    await tester.pump();
    final int afterTriangleDrag = reported.length;
    expect(afterTriangleDrag, greaterThan(0));

    final TestGesture cancelled = await tester.startGesture(center);
    await tester.pump(_gestureStepDuration);
    await cancelled.cancel();
    await tester.pump();

    // Rebuilding with the same color repaints nothing new and keeps state.
    hostSetState(() {});
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('alpha slider reports translucent colors and a new host color resyncs', (
    WidgetTester tester,
  ) async {
    await pumpWheel(tester);

    await tester.drag(find.byType(AlphaGradientSlider), _alphaDragDelta);
    await tester.pump();
    expect(reported, isNotEmpty);
    expect(reported.last.a, lessThan(AppVisual.full));

    reported.clear();
    hostSetState(() => hostColor = _replacementColor);
    await tester.pump();
    await tester.drag(find.byType(AlphaGradientSlider), _alphaDragDelta);
    await tester.pump();
    expect(reported.last.b, greaterThan(reported.last.r));
  });
}
