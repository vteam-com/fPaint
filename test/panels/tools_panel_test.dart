import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/panels/tools/tools_panel.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
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

  group('ToolsPanel fill halftone toggle', () {
    testWidgets('is shown for solid and gradient fill modes', (final WidgetTester tester) async {
      await pumpToolsPanel(tester);

      expect(find.byKey(Keys.toolFillHalftoneToggle), findsOneWidget);

      appProvider.fillModel.mode = FillMode.linear;
      appProvider.update();
      await tester.pump();

      expect(find.byKey(Keys.toolFillHalftoneToggle), findsOneWidget);

      appProvider.fillModel.mode = FillMode.radial;
      appProvider.update();
      await tester.pump();

      expect(find.byKey(Keys.toolFillHalftoneToggle), findsOneWidget);
    });

    testWidgets('does not show a second solid color control when halftone is enabled', (
      final WidgetTester tester,
    ) async {
      await pumpToolsPanel(tester);

      expect(find.byKey(Keys.toolPanelHalftoneDotColor), findsNothing);

      await tester.tap(find.byKey(Keys.toolFillHalftoneToggle));
      await tester.pump();

      expect(find.byKey(Keys.toolPanelHalftoneDotColor), findsNothing);

      appProvider.fillModel.mode = FillMode.linear;
      appProvider.update();
      await tester.pump();

      expect(find.byKey(Keys.toolPanelHalftoneDotColor), findsNothing);
    });

    testWidgets('updates the fill model when toggled', (final WidgetTester tester) async {
      await pumpToolsPanel(tester);

      expect(appProvider.fillModel.halftoneEnabled, isFalse);

      await tester.tap(find.byKey(Keys.toolFillHalftoneToggle));
      await tester.pump();

      expect(appProvider.fillModel.halftoneEnabled, isTrue);
    });
  });
}
