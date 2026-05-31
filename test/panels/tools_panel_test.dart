import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/panels/tools/tools_panel.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/app_bottom_sheet.dart';
import 'package:fpaint/widgets/app_buttons.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/app_slider.dart';
import 'package:fpaint/widgets/halftone_size_picker.dart';
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

  Future<void> pumpToolsPanel(
    final WidgetTester tester, {
    final bool minimal = false,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<LayersProvider>.value(
        value: appProvider.layers,
        child: ChangeNotifierProvider<AppProvider>.value(
          value: appProvider,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ToolsPanel(minimal: minimal),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('ToolsPanel fill halftone slider', () {
    const int halfHalftonePercent = AppLimits.percentMax ~/ AppMath.pair;

    testWidgets('is available for solid and gradient fill modes while disabled', (final WidgetTester tester) async {
      await pumpToolsPanel(tester);

      expect(find.byKey(Keys.toolFillHalftoneToggle), findsOneWidget);
      expect(find.byKey(Keys.toolFillHalftoneSlider), findsNothing);
      expect(
        find.byWidgetPredicate(
          (final Widget widget) => widget is AppButtonIcon && widget.icon == AppIcon.halftone,
        ),
        findsOneWidget,
      );

      appProvider.setFillMode(FillMode.linear);
      await tester.pump();

      expect(find.byKey(Keys.toolFillHalftoneToggle), findsOneWidget);
      expect(find.byKey(Keys.toolFillHalftoneSlider), findsNothing);

      appProvider.setFillMode(FillMode.radial);
      await tester.pump();

      expect(find.byKey(Keys.toolFillHalftoneToggle), findsOneWidget);
      expect(find.byKey(Keys.toolFillHalftoneSlider), findsNothing);
    });

    testWidgets('does not show a second solid color control when halftone is enabled', (
      final WidgetTester tester,
    ) async {
      await pumpToolsPanel(tester);

      expect(find.byKey(Keys.toolPanelHalftoneDotColor), findsNothing);

      await tester.tap(find.byKey(Keys.toolFillHalftoneToggle));
      await tester.pumpAndSettle();

      final AppSlider halftoneSlider = tester.widget<AppSlider>(find.byKey(Keys.toolFillHalftoneSlider));
      halftoneSlider.onChanged!(halfHalftonePercent.toDouble());
      await tester.pump();

      expect(find.byKey(Keys.toolPanelHalftoneDotColor), findsNothing);

      appProvider.setFillMode(FillMode.linear);
      await tester.pump();

      expect(find.byKey(Keys.toolPanelHalftoneDotColor), findsNothing);
    });

    testWidgets('starts disabled with a retained default slider value', (final WidgetTester tester) async {
      await pumpToolsPanel(tester);

      expect(appProvider.fillModel.halftoneMaxDotSizePercent, AppHalftone.defaultDotSizePercent);
      expect(appProvider.fillModel.halftoneEnabled, isFalse);

      expect(find.byKey(Keys.toolFillHalftoneSlider), findsNothing);

      await tester.tap(find.byKey(Keys.toolFillHalftoneToggle));
      await tester.pumpAndSettle();

      final AppSlider halftoneSlider = tester.widget<AppSlider>(find.byKey(Keys.toolFillHalftoneSlider));

      expect(halftoneSlider.value, AppHalftone.defaultDotSizePercent.toDouble());
      expect(halftoneSlider.onChanged, isNotNull);
    });

    testWidgets('retains the slider value when halftone is toggled off', (final WidgetTester tester) async {
      await pumpToolsPanel(tester);

      await tester.tap(find.byKey(Keys.toolFillHalftoneToggle));
      await tester.pumpAndSettle();

      AppSlider halftoneSlider = tester.widget<AppSlider>(find.byKey(Keys.toolFillHalftoneSlider));
      halftoneSlider.onChanged!(halfHalftonePercent.toDouble());
      await tester.pump();

      expect(appProvider.fillModel.halftoneMaxDotSizePercent, halfHalftonePercent);
      expect(appProvider.fillModel.halftoneEnabled, isTrue);

      await tester.tap(find.byKey(Keys.toolFillHalftoneToggle));
      await tester.pumpAndSettle();

      expect(appProvider.fillModel.halftoneMaxDotSizePercent, halfHalftonePercent);
      expect(appProvider.fillModel.halftoneEnabled, isFalse);
      expect(find.byKey(Keys.toolFillHalftoneSlider), findsNothing);

      await tester.tap(find.byKey(Keys.toolFillHalftoneToggle));
      await tester.pumpAndSettle();

      halftoneSlider = tester.widget<AppSlider>(find.byKey(Keys.toolFillHalftoneSlider));

      expect(appProvider.fillModel.halftoneMaxDotSizePercent, halfHalftonePercent);
      expect(appProvider.fillModel.halftoneEnabled, isTrue);
      expect(halftoneSlider.onChanged, isNotNull);
    });
  });

  group('ToolsPanel minimal picker branding', () {
    testWidgets('shows the brush-size icon in the bottom-sheet header', (final WidgetTester tester) async {
      appProvider.selectedAction = ActionType.brush;

      await pumpToolsPanel(tester, minimal: true);

      await tester.tap(find.byKey(Keys.toolBrushSizeButton));
      await tester.pumpAndSettle();

      expect(find.byType(AppBottomSheetContent), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBottomSheetContent),
          matching: find.byWidgetPredicate(
            (final Widget widget) => widget is AppSvgIcon && widget.icon == AppIcon.lineWeight,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows and drives the halftone toggle inside the bottom sheet', (final WidgetTester tester) async {
      await pumpToolsPanel(tester, minimal: true);

      expect(appProvider.fillModel.halftoneEnabled, isFalse);

      await tester.tap(
        find.byWidgetPredicate(
          (final Widget widget) => widget is AppButtonIcon && widget.icon == AppIcon.halftone,
        ),
      );
      await tester.pumpAndSettle();

      final Finder sheet = find.byType(AppBottomSheetContent);
      final Finder sheetToggle = find.descendant(
        of: sheet,
        matching: find.byKey(Keys.toolFillHalftoneToggle),
      );

      expect(sheetToggle, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.byType(HalftoneSizePicker)),
        findsNothing,
      );

      await tester.tap(sheetToggle);
      await tester.pumpAndSettle();

      expect(appProvider.fillModel.halftoneEnabled, isTrue);
      expect(
        find.descendant(of: sheet, matching: find.byType(HalftoneSizePicker)),
        findsOneWidget,
      );

      await tester.tap(sheetToggle);
      await tester.pumpAndSettle();

      expect(appProvider.fillModel.halftoneEnabled, isFalse);
      expect(
        find.descendant(of: sheet, matching: find.byType(HalftoneSizePicker)),
        findsNothing,
      );
    });
  });

  group('ToolsPanel smudge tool', () {
    testWidgets('selects smudge and keeps brush-size controls available', (final WidgetTester tester) async {
      await pumpToolsPanel(tester);

      await tester.tap(find.byKey(Keys.toolSmudge));
      await tester.pumpAndSettle();

      expect(appProvider.selectedAction, ActionType.smudge);
      expect(find.byKey(Keys.toolBrushSizeTool), findsOneWidget);
      expect(find.byKey(Keys.toolBrushSizeButton), findsOneWidget);
    });

    testWidgets('updates tool button selection when selectedAction changes externally', (
      final WidgetTester tester,
    ) async {
      await pumpToolsPanel(tester);

      expect(tester.widget<AppButtonIcon>(find.byKey(Keys.toolFill)).isSelected, isTrue);
      expect(tester.widget<AppButtonIcon>(find.byKey(Keys.toolSmudge)).isSelected, isFalse);

      appProvider.selectedAction = ActionType.smudge;
      await tester.pump();

      expect(tester.widget<AppButtonIcon>(find.byKey(Keys.toolFill)).isSelected, isFalse);
      expect(tester.widget<AppButtonIcon>(find.byKey(Keys.toolSmudge)).isSelected, isTrue);
    });
  });
}
