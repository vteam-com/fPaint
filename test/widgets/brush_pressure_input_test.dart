import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_harness.dart';

const int _pointer = 7;

Widget _buildHarness({
  required AppPreferences preferences,
  required AppProvider appProvider,
  required ShellProvider shellProvider,
}) {
  return InheritedControllerScope<AppPreferences>(
    controller: preferences,
    child: InheritedControllerScope<AppProvider>(
      controller: appProvider,
      child: InheritedControllerScope<LayersProvider>(
        controller: appProvider.layers,
        child: InheritedControllerScope<ShellProvider>(
          controller: shellProvider,
          child: buildLocalizedTestApp(
            home: const Scaffold(body: SizedBox.expand(child: MainView())),
          ),
        ),
      ),
    ),
  );
}

/// Draws a three-sample stroke from [start] with the given [kind], reporting
/// [pressures] (0..1 over a 0..1 device range) at each sample.
Future<void> _pressureStroke(
  WidgetTester tester,
  Offset start,
  PointerDeviceKind kind,
  List<double> pressures,
) async {
  const Offset step = Offset(30, 10);
  tester.binding.handlePointerEvent(
    PointerDownEvent(
      pointer: _pointer,
      kind: kind,
      position: start,
      pressure: pressures.first,
      pressureMin: 0,
      pressureMax: 1,
    ),
  );
  await tester.pump();
  for (int i = 1; i < pressures.length; i++) {
    tester.binding.handlePointerEvent(
      PointerMoveEvent(
        pointer: _pointer,
        kind: kind,
        position: start + step * i.toDouble(),
        delta: step,
        buttons: kPrimaryButton,
        pressure: pressures[i],
        pressureMin: 0,
        pressureMax: 1,
      ),
    );
    await tester.pump();
  }
  tester.binding.handlePointerEvent(
    PointerUpEvent(
      pointer: _pointer,
      kind: kind,
      position: start + step * (pressures.length - 1).toDouble(),
    ),
  );
  await tester.pump();
  await tester.pump(AppDefaults.thumbnailDebounceDuration);
  await tester.pump(AppDefaults.brushSizePreviewDuration);
}

void main() {
  late AppPreferences preferences;
  late AppProvider appProvider;
  late ShellProvider shellProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    shellProvider = ShellProvider();
  });

  Future<Offset> pumpCanvas(WidgetTester tester, ActionType tool) async {
    appProvider.selectedAction = tool;
    await tester.pumpWidget(
      _buildHarness(preferences: preferences, appProvider: appProvider, shellProvider: shellProvider),
    );
    await tester.pump();
    return tester.getCenter(find.byType(MainView));
  }

  StrokeAction lastStroke() => appProvider.layers.selectedLayer.actionStack.last as StrokeAction;

  testWidgets('a pen stroke with the Brush tool records one pressure sample per point', (
    WidgetTester tester,
  ) async {
    final Offset center = await pumpCanvas(tester, ActionType.brush);

    await _pressureStroke(tester, center, PointerDeviceKind.stylus, <double>[0.2, 0.5, 0.9]);

    final StrokeAction stroke = lastStroke();
    expect(stroke.action, ActionType.brush);
    expect(stroke.pressures, isNotNull);
    expect(stroke.pressures!.length, stroke.positions.length);
    expect(stroke.pressures!.first, closeTo(0.2, 1e-9));
    expect(stroke.pressures!.last, closeTo(0.9, 1e-9));
  });

  testWidgets('a mouse stroke with the Brush tool stays pressure-less', (WidgetTester tester) async {
    final Offset center = await pumpCanvas(tester, ActionType.brush);

    await _pressureStroke(tester, center, PointerDeviceKind.mouse, <double>[0.2, 0.5, 0.9]);

    expect(lastStroke().pressures, isNull);
  });

  testWidgets('lifting the pen off a fading press tapers the committed tip to the hairline', (
    WidgetTester tester,
  ) async {
    final Offset center = await pumpCanvas(tester, ActionType.brush);

    await _pressureStroke(tester, center, PointerDeviceKind.stylus, <double>[0.9, 0.5, 0.1]);

    final List<double> pressures = lastStroke().pressures!;
    expect(pressures.first, closeTo(0.9, 1e-9));
    expect(pressures.last, 0);
  });

  testWidgets('other tools ignore pen pressure', (WidgetTester tester) async {
    final Offset center = await pumpCanvas(tester, ActionType.pencil);

    await _pressureStroke(tester, center, PointerDeviceKind.stylus, <double>[0.2, 0.5, 0.9]);

    final StrokeAction stroke = lastStroke();
    expect(stroke.action, ActionType.pencil);
    expect(stroke.pressures, isNull);
  });
}
