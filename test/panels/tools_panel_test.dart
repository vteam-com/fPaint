import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/hatch_pattern.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/panels/tools/tools_panel.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/widgets/app_bottom_sheet.dart';
import 'package:fpaint/widgets/app_buttons.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/app_slider.dart';
import 'package:fpaint/widgets/halftone_size_picker.dart';
import 'package:fpaint/widgets/hatch_marks_picker.dart';
import 'package:fpaint/widgets/hatch_settings_picker.dart';
import 'package:material_ui/material_ui.dart';
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
    WidgetTester tester, {
    bool minimal = false,
  }) async {
    await tester.pumpWidget(
      InheritedControllerScope<LayersProvider>(
        controller: appProvider.layers,
        child: InheritedControllerScope<AppProvider>(
          controller: appProvider,
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

  group('ToolsPanel hatch options', () {
    testWidgets('brush shows the hatch row only for a hatch style and the sheet edits it', (
      WidgetTester tester,
    ) async {
      appProvider.selectedAction = ActionType.brush;
      await pumpToolsPanel(tester);
      expect(find.byKey(Keys.toolBrushHatchSlider), findsNothing);

      appProvider.brushStyle = BrushStyle.hatch;
      await tester.pumpAndSettle();
      expect(find.byKey(Keys.toolBrushHatchSlider), findsOneWidget);

      // The inline slider edits the shared spacing.
      tester.widget<AppSlider>(find.byKey(Keys.toolBrushHatchSlider)).onChanged!(12);
      await tester.pumpAndSettle();
      expect(appProvider.hatchPattern.spacing, 12);

      // The sheet's cross switch flips the brush style.
      await tester.tap(find.byKey(Keys.toolBrushHatchButton));
      await tester.pumpAndSettle();
      expect(find.byType(HatchSettingsControls), findsOneWidget);
      await tester.tap(find.byKey(Keys.hatchCrossedToggle));
      await tester.pumpAndSettle();
      expect(appProvider.brushStyle, BrushStyle.crossHatch);
      tester.widget<AppSlider>(find.byKey(Keys.hatchAngleSlider)).onChanged!(60);
      await tester.pumpAndSettle();
      expect(appProvider.hatchPattern.angleDegrees, 60);
      expect(appProvider.hatchPattern.spacing, 12);
    });

    testWidgets('hatch marks style shows its own row and sheet', (WidgetTester tester) async {
      appProvider.selectedAction = ActionType.brush;
      appProvider.brushStyle = BrushStyle.hatchMarks;
      await pumpToolsPanel(tester);
      expect(find.byKey(Keys.toolBrushHatchSlider), findsNothing);
      expect(find.byKey(Keys.toolBrushHatchMarksSlider), findsOneWidget);

      tester.widget<AppSlider>(find.byKey(Keys.toolBrushHatchMarksSlider)).onChanged!(75);
      await tester.pumpAndSettle();
      expect(appProvider.hatchMarks.length, 75);

      await tester.tap(find.byKey(Keys.toolBrushHatchMarksButton));
      await tester.pumpAndSettle();
      expect(find.byType(HatchMarksControls), findsOneWidget);
      tester.widget<AppSlider>(find.byKey(Keys.hatchMarksTaperSlider)).onChanged!(40);
      await tester.pumpAndSettle();
      expect(appProvider.hatchMarks.taperPercent, 40);
      expect(appProvider.hatchMarks.length, 75);
    });

    testWidgets('minimal brush panel shows the hatch button without a slider', (WidgetTester tester) async {
      appProvider.selectedAction = ActionType.brush;
      appProvider.brushStyle = BrushStyle.crossHatch;
      await pumpToolsPanel(tester, minimal: true);
      expect(find.byKey(Keys.toolBrushHatchButton), findsOneWidget);
      expect(find.byKey(Keys.toolBrushHatchSlider), findsNothing);
    });

    testWidgets('solid fill offers a hatch toggle that is exclusive with halftone', (WidgetTester tester) async {
      await pumpToolsPanel(tester);
      expect(find.byKey(Keys.toolFillHatchToggle), findsOneWidget);
      // Like halftone, the inline slider is collapsed while the pattern is off.
      expect(find.byKey(Keys.toolFillHatchSlider), findsNothing);

      await tester.tap(find.byKey(Keys.toolFillHalftoneToggle));
      await tester.pumpAndSettle();
      expect(appProvider.fillModel.halftoneEnabled, isTrue);

      await tester.tap(find.byKey(Keys.toolFillHatchToggle));
      await tester.pumpAndSettle();
      expect(appProvider.fillModel.hatchEnabled, isTrue);
      expect(appProvider.fillModel.halftoneEnabled, isFalse);

      final AppSlider slider = tester.widget<AppSlider>(find.byKey(Keys.toolFillHatchSlider));
      expect(slider.onChanged, isNotNull);
      slider.onChanged!(16);
      await tester.pumpAndSettle();
      expect(appProvider.hatchPattern.spacing, 16);

      // Editing through the sheet sets the fill's crossed flag, not the brush style.
      final BrushStyle styleBefore = appProvider.brushStyle;
      await tester.tap(
        find.byWidgetPredicate((Widget widget) => widget is AppButtonIcon && widget.icon == AppIcon.hatch),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Keys.hatchCrossedToggle));
      await tester.pumpAndSettle();
      expect(appProvider.fillModel.hatchCrossed, isTrue);
      expect(appProvider.brushStyle, styleBefore);
      expect(appProvider.hatchPattern, const HatchPattern(spacing: 16));
    });

    testWidgets('gradient fill modes do not offer the hatch pattern', (WidgetTester tester) async {
      appProvider.setFillMode(FillMode.linear);
      await pumpToolsPanel(tester);
      expect(find.byKey(Keys.toolFillHatchToggle), findsNothing);
    });
  });

  group('ToolsPanel fill halftone slider', () {
    const int halfHalftonePercent = AppLimits.percentMax ~/ AppMath.pair;

    testWidgets('is available for solid and gradient fill modes while disabled', (WidgetTester tester) async {
      await pumpToolsPanel(tester);

      expect(find.byKey(Keys.toolFillHalftoneToggle), findsOneWidget);
      expect(find.byKey(Keys.toolFillHalftoneSlider), findsNothing);
      expect(
        find.byWidgetPredicate(
          (Widget widget) => widget is AppButtonIcon && widget.icon == AppIcon.halftone,
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
      WidgetTester tester,
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

    testWidgets('starts disabled with a retained default slider value', (WidgetTester tester) async {
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

    testWidgets('retains the slider value when halftone is toggled off', (WidgetTester tester) async {
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
    testWidgets('shows the brush-size icon in the bottom-sheet header', (WidgetTester tester) async {
      appProvider.selectedAction = ActionType.brush;

      await pumpToolsPanel(tester, minimal: true);

      await tester.tap(find.byKey(Keys.toolBrushSizeButton));
      await tester.pumpAndSettle();

      expect(find.byType(AppBottomSheetContent), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBottomSheetContent),
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is AppSvgIcon && widget.icon == AppIcon.lineWeight,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows and drives the halftone toggle inside the bottom sheet', (WidgetTester tester) async {
      await pumpToolsPanel(tester, minimal: true);

      expect(appProvider.fillModel.halftoneEnabled, isFalse);

      await tester.tap(
        find.byWidgetPredicate(
          (Widget widget) => widget is AppButtonIcon && widget.icon == AppIcon.halftone,
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
    testWidgets('selects smudge and keeps size and intensity controls available', (WidgetTester tester) async {
      await pumpToolsPanel(tester);

      await tester.tap(find.byKey(Keys.toolSmudge));
      await tester.pumpAndSettle();

      expect(appProvider.selectedAction, ActionType.smudge);
      expect(find.byKey(Keys.toolBrushSizeTool), findsOneWidget);
      expect(find.byKey(Keys.toolBrushSizeButton), findsOneWidget);
      expect(find.byKey(Keys.toolBrushIntensityTool), findsOneWidget);
      expect(find.byKey(Keys.toolBrushIntensitySlider), findsOneWidget);
    });

    testWidgets('updates smudge intensity from the inline slider', (WidgetTester tester) async {
      await pumpToolsPanel(tester);

      appProvider.selectedAction = ActionType.smudge;
      await tester.pump();

      final AppSlider slider = tester.widget<AppSlider>(find.byKey(Keys.toolBrushIntensitySlider));
      slider.onChanged!(AppEffects.maxIntensity);
      await tester.pump();

      expect(appProvider.brushIntensity, greaterThan(AppInteraction.pixelBrushDefaultIntensity));
    });

    testWidgets('updates tool button selection when selectedAction changes externally', (
      WidgetTester tester,
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

  group('ToolsPanel Brush section', () {
    testWidgets('tapping an effect arms it as a brush and reveals its controls', (
      WidgetTester tester,
    ) async {
      await pumpToolsPanel(tester);

      expect(appProvider.effectBrushModel.isArmed, isFalse);
      expect(appProvider.selectorModel.isVisible, isFalse);

      final Finder blurEffect = find.byKey(const ValueKey<SelectionEffect>(SelectionEffect.blur));
      await tester.ensureVisible(blurEffect);
      await tester.tap(blurEffect);
      await tester.pumpAndSettle();

      // The effect arms as a brush — no whole-region preview, no selection.
      expect(appProvider.effectBrushModel.isArmed, isTrue);
      expect(appProvider.effectBrushModel.effect, SelectionEffect.blur);
      expect(appProvider.effectPreviewModel.isVisible, isFalse);
      expect(find.byKey(Keys.effectPaintStrengthSlider), findsOneWidget);
      expect(find.byKey(Keys.effectPaintSizeSlider), findsOneWidget);

      // Tapping the armed effect again disarms it.
      await tester.ensureVisible(blurEffect);
      await tester.tap(blurEffect);
      await tester.pumpAndSettle();
      expect(appProvider.effectBrushModel.isArmed, isFalse);
    });

    testWidgets('arming an effect deselects the gesture tool; picking one disarms it', (
      WidgetTester tester,
    ) async {
      await pumpToolsPanel(tester);

      // A gesture tool (fill, from setUp) is selected and no effect is armed.
      expect(tester.widget<AppButtonIcon>(find.byKey(Keys.toolFill)).isSelected, isTrue);

      final Finder blurEffect = find.byKey(const ValueKey<SelectionEffect>(SelectionEffect.blur));
      await tester.ensureVisible(blurEffect);
      await tester.tap(blurEffect);
      await tester.pumpAndSettle();

      // Effect armed → the gesture tool no longer shows as selected.
      expect(appProvider.effectBrushModel.isArmed, isTrue);
      expect(tester.widget<AppButtonIcon>(find.byKey(Keys.toolFill)).isSelected, isFalse);

      // Picking a gesture tool disarms the effect and reselects the tool.
      await tester.tap(find.byKey(Keys.toolFill));
      await tester.pumpAndSettle();
      expect(appProvider.effectBrushModel.isArmed, isFalse);
      expect(tester.widget<AppButtonIcon>(find.byKey(Keys.toolFill)).isSelected, isTrue);
    });
  });

  group('ToolsPanel sections', () {
    testWidgets('selection clipboard actions are not shown in side panel', (
      WidgetTester tester,
    ) async {
      await pumpToolsPanel(tester);

      expect(find.byKey(Keys.toolSelectorCopy), findsNothing);
      expect(find.byKey(Keys.toolSelectorCut), findsNothing);

      appProvider.activateSelectionAction();
      appProvider.selectorModel.isVisible = true;
      appProvider.selectorModel.path1 = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));
      appProvider.update();
      await tester.pumpAndSettle();

      expect(find.byKey(Keys.toolSelectorCopy), findsNothing);
      expect(find.byKey(Keys.toolSelectorCut), findsNothing);
    });

    testWidgets('selection mode buttons are not shown in side panel', (WidgetTester tester) async {
      await pumpToolsPanel(tester);

      expect(find.byKey(Keys.toolSelectorModeCircle), findsNothing);
      expect(find.byKey(Keys.toolSelectorModeRectangle), findsNothing);
      expect(find.byKey(Keys.toolSelectorModeLine), findsNothing);
      expect(find.byKey(Keys.toolSelectorModeLasso), findsNothing);
      expect(find.byKey(Keys.toolSelectorModeWand), findsNothing);
    });

    testWidgets('selection dismiss button is not shown in side panel', (WidgetTester tester) async {
      appProvider.selectedAction = ActionType.smudge;
      appProvider.activateSelectionAction();
      appProvider.setSelectorMode(SelectorMode.circle);
      appProvider.selectorModel.isVisible = true;
      appProvider.selectorModel.path1 = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));

      await pumpToolsPanel(tester);

      expect(find.byKey(Keys.toolSelectorCancel), findsNothing);
    });

    testWidgets('selection section no longer renders side-panel selector row', (WidgetTester tester) async {
      appProvider.selectedAction = ActionType.selector;
      appProvider.selectorModel.isVisible = true;
      appProvider.selectorModel.path1 = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));

      await pumpToolsPanel(tester);

      expect(find.byKey(Keys.toolSelector), findsNothing);
      expect(find.byKey(Keys.toolSelectorCancel), findsNothing);
    });
  });
}
