import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _viewSize = Size(1200, 800);

/// Matches the (private) smudge/blur marquee painter by its runtime type name.
bool _isMarqueePaint(final Widget widget) =>
    widget is CustomPaint && widget.painter.runtimeType.toString() == '_PixelBrushGestureMarqueePainter';

/// Matches the (private) processing-shimmer overlay by its runtime type name.
bool _isShimmer(final Widget widget) => widget.runtimeType.toString() == '_PixelBrushProcessingShimmer';

void main() {
  late AppPreferences preferences;
  late AppProvider appProvider;
  late ShellProvider shellProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    appProvider.undoProvider.clear();
    shellProvider = ShellProvider();
    shellProvider.shellMode = ShellMode.full;
  });

  Future<void> pumpMainView(final WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = _viewSize;
    await tester.pumpWidget(
      InheritedControllerScope<AppPreferences>(
        controller: preferences,
        child: InheritedControllerScope<AppProvider>(
          controller: appProvider,
          child: InheritedControllerScope<LayersProvider>(
            controller: appProvider.layers,
            child: InheritedControllerScope<ShellProvider>(
              controller: shellProvider,
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: MainView(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a swept smudge/blur stroke paints the marquee band', (final WidgetTester tester) async {
    appProvider.showPixelBrushGesture(
      points: const <Offset>[Offset(20, 20), Offset(60, 40), Offset(90, 120)],
      size: 24,
    );
    await pumpMainView(tester);

    expect(appProvider.isPixelBrushGestureVisible, isTrue);
    expect(find.byWidgetPredicate(_isMarqueePaint), findsOneWidget);
    // Painting the swept marquee band must not throw.
    expect(tester.takeException(), isNull);
  });

  testWidgets('a single-point tap paints the marquee footprint', (final WidgetTester tester) async {
    appProvider.showPixelBrushGesture(points: const <Offset>[Offset(50, 50)], size: 30);
    await pumpMainView(tester);

    expect(find.byWidgetPredicate(_isMarqueePaint), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no marquee is painted when no gesture is active', (final WidgetTester tester) async {
    await pumpMainView(tester);

    expect(appProvider.isPixelBrushGestureVisible, isFalse);
    expect(find.byWidgetPredicate(_isMarqueePaint), findsNothing);
  });

  testWidgets('an armed effect brush paints over a live selection instead of starting a new one', (
    final WidgetTester tester,
  ) async {
    // Selector tool active with a completed selection (the modifier), then an
    // effect is armed as a brush.
    appProvider.selectorModel
      ..isVisible = true
      ..path1 = (Path()..addRect(const Rect.fromLTWH(50, 50, 300, 300)));
    appProvider.selectedAction = ActionType.selector;
    appProvider.armEffectBrush(SelectionEffect.blur);
    expect(appProvider.effectBrushModel.isArmed, isTrue);

    await pumpMainView(tester);

    // Pressing on the canvas must begin an effect-brush stroke (a pixel-brush
    // gesture), not restart the selection.
    final TestGesture gesture = await tester.startGesture(const Offset(600, 400));
    await tester.pump();
    await gesture.moveTo(const Offset(640, 430));
    await tester.pump();

    expect(appProvider.isPixelBrushGestureVisible, isTrue);
    expect(appProvider.selectorModel.isDrawing, isFalse);
    // The selection (the clip modifier) is preserved.
    expect(appProvider.selectorModel.isVisible, isTrue);

    // Release via touch-cancel so no async one-shot commit runs in the test.
    await gesture.cancel();
    await tester.pump();
  });

  testWidgets('committing shows the processing shimmer instead of the static marquee', (
    final WidgetTester tester,
  ) async {
    appProvider.showPixelBrushGesture(
      points: const <Offset>[Offset(20, 20), Offset(60, 40), Offset(90, 120)],
      size: 24,
    );
    appProvider.setPixelBrushCommitting(committing: true);
    await pumpMainView(tester);

    // The shimmer replaces the static marquee while the commit runs.
    expect(find.byWidgetPredicate(_isShimmer), findsOneWidget);
    expect(find.byWidgetPredicate(_isMarqueePaint), findsNothing);

    // The sweep animates across frames without throwing.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    // Finishing the commit clears the shimmer.
    appProvider.clearPixelBrushGesture();
    await tester.pump();
    expect(find.byWidgetPredicate(_isShimmer), findsNothing);
  });
}
