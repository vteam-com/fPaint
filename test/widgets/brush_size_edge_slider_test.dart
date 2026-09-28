import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_harness.dart';

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

  Future<void> pumpMainView(WidgetTester tester) async {
    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump();
  }

  /// Drags the slider vertically by [dy] (negative = up) while holding the
  /// pointer [strayDx] pixels sideways, returning the resulting brush size.
  Future<double> dragSlider(WidgetTester tester, {required double dy, double strayDx = 0}) async {
    final Offset start = tester.getCenter(find.byKey(Keys.brushSizeEdgeSlider));
    final TestGesture gesture = await tester.startGesture(start);
    await gesture.moveBy(Offset(strayDx, 0));
    await gesture.moveBy(Offset(0, dy));
    await gesture.up();
    await tester.pump(AppDefaults.brushSizePreviewDuration);
    return appProvider.brushSize;
  }

  testWidgets('is shown for sized paint tools and hidden for tools without a brush size', (
    WidgetTester tester,
  ) async {
    appProvider.selectedAction = ActionType.brush;
    await pumpMainView(tester);
    expect(find.byKey(Keys.brushSizeEdgeSlider), findsOneWidget);

    appProvider.selectedAction = ActionType.fill;
    appProvider.update();
    await tester.pump();
    expect(find.byKey(Keys.brushSizeEdgeSlider), findsNothing);
  });

  testWidgets('is shown for every brush-sized tool, including the line and shape tools', (
    WidgetTester tester,
  ) async {
    await pumpMainView(tester);

    for (final ActionType tool in <ActionType>[
      ActionType.pencil,
      ActionType.brush,
      ActionType.eraser,
      ActionType.smudge,
      ActionType.blurBrush,
      ActionType.line,
      ActionType.rectangle,
      ActionType.circle,
    ]) {
      appProvider.selectedAction = tool;
      await tester.pump();
      expect(find.byKey(Keys.brushSizeEdgeSlider), findsOneWidget, reason: '$tool');
    }
  });

  testWidgets('is shown for an armed effect brush, even over a tool without a brush size', (
    WidgetTester tester,
  ) async {
    appProvider.selectedAction = ActionType.selector;
    await pumpMainView(tester);
    expect(find.byKey(Keys.brushSizeEdgeSlider), findsNothing);

    appProvider.armEffectBrush(SelectionEffect.blur);
    await tester.pump();
    expect(find.byKey(Keys.brushSizeEdgeSlider), findsOneWidget);
    expect(appProvider.activeBrushSizeMax, AppLimits.pixelBrushSizeMax.toDouble());

    appProvider.disarmEffectBrush();
    await tester.pump();
    expect(find.byKey(Keys.brushSizeEdgeSlider), findsNothing);
  });

  testWidgets('dragging up grows the brush and dragging down shrinks it', (WidgetTester tester) async {
    appProvider.selectedAction = ActionType.brush;
    appProvider.brushSize = 10;
    await pumpMainView(tester);

    final double grown = await dragSlider(tester, dy: -60);
    expect(grown, greaterThan(10));

    final double shrunk = await dragSlider(tester, dy: 120);
    expect(shrunk, lessThan(grown));
    expect(shrunk, greaterThanOrEqualTo(appProvider.activeBrushSizeMin));
  });

  testWidgets('shows a numeric readout and the size ring only while dragging', (WidgetTester tester) async {
    appProvider.selectedAction = ActionType.brush;
    appProvider.brushSize = 10;
    await pumpMainView(tester);
    await tester.pump(AppDefaults.brushSizePreviewDuration);
    expect(find.byKey(Keys.brushSizeEdgeSliderReadout), findsNothing);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byKey(Keys.brushSizeEdgeSlider)),
    );
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();

    expect(find.byKey(Keys.brushSizeEdgeSliderReadout), findsOneWidget);
    expect(find.text(appProvider.brushSize.toStringAsFixed(1)), findsOneWidget);
    expect(find.byKey(Keys.brushSizePreviewOverlay), findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(find.byKey(Keys.brushSizeEdgeSliderReadout), findsNothing);

    await tester.pump(AppDefaults.brushSizePreviewDuration);
  });

  testWidgets('straying sideways from the track slows the change for fine control', (
    WidgetTester tester,
  ) async {
    appProvider.selectedAction = ActionType.brush;
    appProvider.brushSize = 10;
    await pumpMainView(tester);
    final double coarse = await dragSlider(tester, dy: -60) - 10;

    appProvider.brushSize = 10;
    await tester.pump(AppDefaults.brushSizePreviewDuration);
    final double fine = await dragSlider(tester, dy: -60, strayDx: 120) - 10;

    expect(fine, greaterThan(0));
    expect(fine, lessThan(coarse));
  });

  testWidgets('dragging the slider does not paint on the canvas', (WidgetTester tester) async {
    appProvider.selectedAction = ActionType.brush;
    await pumpMainView(tester);
    final int before = appProvider.layers.selectedLayer.actionStack.length;

    await dragSlider(tester, dy: -60);

    expect(appProvider.layers.selectedLayer.actionStack.length, before);
  });
}
