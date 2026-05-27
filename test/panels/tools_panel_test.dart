import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/panels/tools/tools_panel.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/app_buttons.dart';
import 'package:fpaint/widgets/app_slider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppProvider appProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppPreferences preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    appProvider.selectedAction = ActionType.fill;
  });

  Future<void> pumpToolsPanel(final WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<LayersProvider>.value(
        value: appProvider.layers,
        child: ChangeNotifierProvider<AppProvider>.value(
          value: appProvider,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ToolsPanel(minimal: false),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('ToolsPanel fill halftone slider', () {
    const int halfHalftonePercent = AppLimits.percentMax ~/ AppMath.pair;

    testWidgets('is shown for solid and gradient fill modes', (final WidgetTester tester) async {
      await pumpToolsPanel(tester);

      expect(find.byKey(Keys.toolFillHalftoneSlider), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (final Widget widget) => widget is AppButtonIcon && widget.icon == AppIcon.halftone,
        ),
        findsOneWidget,
      );

      appProvider.fillModel.mode = FillMode.linear;
      appProvider.update();
      await tester.pump();

      expect(find.byKey(Keys.toolFillHalftoneSlider), findsOneWidget);

      appProvider.fillModel.mode = FillMode.radial;
      appProvider.update();
      await tester.pump();

      expect(find.byKey(Keys.toolFillHalftoneSlider), findsOneWidget);
    });

    testWidgets('does not show a second solid color control when halftone is enabled', (
      final WidgetTester tester,
    ) async {
      await pumpToolsPanel(tester);

      expect(find.byKey(Keys.toolPanelHalftoneDotColor), findsNothing);

      await tester.tap(find.byKey(Keys.toolFillHalftoneToggle));
      await tester.pump();

      final AppSlider halftoneSlider = tester.widget<AppSlider>(find.byKey(Keys.toolFillHalftoneSlider));
      halftoneSlider.onChanged!(halfHalftonePercent.toDouble());
      await tester.pump();

      expect(find.byKey(Keys.toolPanelHalftoneDotColor), findsNothing);

      appProvider.fillModel.mode = FillMode.linear;
      appProvider.update();
      await tester.pump();

      expect(find.byKey(Keys.toolPanelHalftoneDotColor), findsNothing);
    });

    testWidgets('starts disabled with a retained default slider value', (final WidgetTester tester) async {
      await pumpToolsPanel(tester);

      final AppSlider halftoneSlider = tester.widget<AppSlider>(find.byKey(Keys.toolFillHalftoneSlider));

      expect(appProvider.fillModel.halftoneMaxDotSizePercent, AppHalftone.defaultDotSizePercent);
      expect(appProvider.fillModel.halftoneEnabled, isFalse);
      expect(halftoneSlider.value, AppHalftone.defaultDotSizePercent.toDouble());
      expect(halftoneSlider.onChanged, isNull);
    });

    testWidgets('retains the slider value when halftone is toggled off', (final WidgetTester tester) async {
      await pumpToolsPanel(tester);

      await tester.tap(find.byKey(Keys.toolFillHalftoneToggle));
      await tester.pump();

      AppSlider halftoneSlider = tester.widget<AppSlider>(find.byKey(Keys.toolFillHalftoneSlider));
      halftoneSlider.onChanged!(halfHalftonePercent.toDouble());
      await tester.pump();

      expect(appProvider.fillModel.halftoneMaxDotSizePercent, halfHalftonePercent);
      expect(appProvider.fillModel.halftoneEnabled, isTrue);

      await tester.tap(find.byKey(Keys.toolFillHalftoneToggle));
      await tester.pump();

      halftoneSlider = tester.widget<AppSlider>(find.byKey(Keys.toolFillHalftoneSlider));

      expect(appProvider.fillModel.halftoneMaxDotSizePercent, halfHalftonePercent);
      expect(appProvider.fillModel.halftoneEnabled, isFalse);
      expect(halftoneSlider.value, halfHalftonePercent.toDouble());
      expect(halftoneSlider.onChanged, isNull);

      await tester.tap(find.byKey(Keys.toolFillHalftoneToggle));
      await tester.pump();

      halftoneSlider = tester.widget<AppSlider>(find.byKey(Keys.toolFillHalftoneSlider));

      expect(appProvider.fillModel.halftoneMaxDotSizePercent, halfHalftonePercent);
      expect(appProvider.fillModel.halftoneEnabled, isTrue);
      expect(halftoneSlider.onChanged, isNotNull);
    });
  });
}
