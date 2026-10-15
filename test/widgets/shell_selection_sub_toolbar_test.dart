import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/shell_selection_sub_toolbar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_harness.dart';

const Size _testViewSize = Size(1200, 600);
const SelectionEffect _previewedEffect = SelectionEffect.blur;

void main() {
  late AppProvider appProvider;
  late ShellProvider shellProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppPreferences preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    shellProvider = ShellProvider();
    appProvider.selectorModel.isVisible = true;
  });

  Future<void> pumpToolbar(WidgetTester tester) async {
    tester.view.physicalSize = _testViewSize;
    tester.view.devicePixelRatio = AppMath.one.toDouble();
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      InheritedControllerScope<ShellProvider>(
        controller: shellProvider,
        child: InheritedControllerScope<AppProvider>(
          controller: appProvider,
          child: InheritedControllerScope<LayersProvider>(
            controller: appProvider.layers,
            child: buildLocalizedTestApp(
              home: Builder(
                builder: (BuildContext context) => Align(
                  alignment: Alignment.topCenter,
                  child: buildSelectionSubToolbar(
                    context: context,
                    shellProvider: shellProvider,
                    appProvider: appProvider,
                    interactionProfile: shellProvider.interactionLayoutProfile,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder iconButton(AppIcon icon) {
    return find.byWidgetPredicate((Widget widget) => widget is AppSvgIcon && widget.icon == icon);
  }

  testWidgets('cut on a locked layer, invert and crop without a path run as deferred actions', (
    WidgetTester tester,
  ) async {
    appProvider.layers.selectedLayer.isLocked = true;
    await pumpToolbar(tester);

    await tester.tap(find.byKey(Keys.toolSelectorCut));
    await tester.pump();
    // A locked layer refuses the cut, leaving the selection in place.
    expect(appProvider.selectorModel.isVisible, isTrue);

    await tester.tap(iconButton(AppIcon.selectorMathInvert));
    await tester.pump();
    expect(appProvider.selectorModel.isVisible, isTrue);

    shellProvider.canvasPlacement = CanvasAutoPlacement.fit;
    await tester.tap(iconButton(AppIcon.canvasCrop));
    await tester.pump();
    expect(shellProvider.canvasPlacement, CanvasAutoPlacement.manual);

    await tester.tap(iconButton(AppIcon.selectorMathAdd));
    await tester.pump();
    expect(appProvider.selectorModel.math, SelectorMath.add);
  });

  testWidgets('copy schedules a region copy of the selection', (WidgetTester tester) async {
    await pumpToolbar(tester);

    await tester.tap(find.byKey(Keys.toolSelectorCopy));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('picking the effect already being previewed cancels that preview', (WidgetTester tester) async {
    appProvider.effectPreviewModel.effect = _previewedEffect;
    appProvider.effectPreviewModel.isVisible = true;
    await pumpToolbar(tester);

    await tester.tap(find.byKey(Keys.effectsButton));
    await tester.pumpAndSettle();
    await tester.tap(iconButton(_previewedEffect.icon).last);
    await tester.pumpAndSettle();

    expect(appProvider.effectPreviewModel.isVisible, isFalse);
  });
}
