import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/panels/side_panel/top_menu_and_layers_panel.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _panelSize = Size(400, 600);
const String _topLayerName = 'Top';
const String _swappedLayerName = 'Swapped';
const Duration _dragStepDuration = Duration(milliseconds: 20);
const Duration _doubleTapGap = Duration(milliseconds: 50);
const int _dragSteps = 5;

void main() {
  late AppPreferences preferences;
  late AppProvider appProvider;
  late ShellProvider shellProvider;
  late LayersProvider scopedLayers;
  late StateSetter hostSetState;
  late GlobalKey panelKey;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    shellProvider = ShellProvider();
    scopedLayers = appProvider.layers;
    panelKey = GlobalKey();
    appProvider.layers.addTop(name: _topLayerName);
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      InheritedControllerScope<ShellProvider>(
        controller: shellProvider,
        child: InheritedControllerScope<AppPreferences>(
          controller: preferences,
          child: InheritedControllerScope<AppProvider>(
            controller: appProvider,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Align(
                alignment: Alignment.topLeft,
                child: StatefulBuilder(
                  builder: (BuildContext _, StateSetter setState) {
                    hostSetState = setState;
                    return InheritedControllerScope<LayersProvider>(
                      controller: scopedLayers,
                      child: SizedBox.fromSize(
                        size: _panelSize,
                        // A stable non-const key: each host rebuild hands the
                        // panel a fresh widget so it re-reads the scope.
                        child: TopMenuAndLayersPanel(key: panelKey),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Drains the debounced thumbnail rebuilds so no timer outlives the test.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(AppDefaults.thumbnailDebounceDuration);
    await tester.pumpAndSettle();
  }

  Finder rowOf(LayersProvider layers, int index) => find.byKey(GlobalObjectKey(layers.get(index)));

  Future<void> dragRow(WidgetTester tester, {required int from, required int to, Duration? hold}) async {
    final Offset start = tester.getCenter(rowOf(appProvider.layers, from));
    final Offset end = tester.getCenter(rowOf(appProvider.layers, to));
    final TestGesture gesture = await tester.startGesture(start);
    if (hold != null) {
      await tester.pump(hold);
    }
    final Offset step = (end - start) / _dragSteps.toDouble();
    for (int i = 0; i < _dragSteps; i++) {
      await gesture.moveBy(step);
      await tester.pump(_dragStepDuration);
    }
    await gesture.up();
    await tester.pump();
  }

  testWidgets('double-tapping a layer row toggles its visibility', (WidgetTester tester) async {
    await pumpPanel(tester);
    final LayerProvider topLayer = appProvider.layers.get(0);
    expect(topLayer.isVisible, isTrue);

    final Offset rowCenter = tester.getCenter(rowOf(appProvider.layers, 0));
    await tester.tapAt(rowCenter);
    await tester.pump(_doubleTapGap);
    await tester.tapAt(rowCenter);
    await settle(tester);

    expect(topLayer.isVisible, isFalse);
  });

  testWidgets('desktop pointer drag reorders layers immediately', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await pumpPanel(tester);
      final LayerProvider topLayer = appProvider.layers.get(0);

      await dragRow(tester, from: 0, to: 1);
      await settle(tester);

      expect(appProvider.layers.get(1), same(topLayer));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('touch long-press drag reorders layers', (WidgetTester tester) async {
    await pumpPanel(tester);
    final LayerProvider topLayer = appProvider.layers.get(0);

    await dragRow(tester, from: 0, to: 1, hold: kLongPressTimeout + _dragStepDuration);
    await settle(tester);

    expect(appProvider.layers.get(1), same(topLayer));
  });

  testWidgets('swapping the layers provider rebinds the list', (WidgetTester tester) async {
    await pumpPanel(tester);

    final LayersProvider replacement = LayersProvider(undoProvider: UndoProvider());
    replacement.addTop(name: _swappedLayerName);
    hostSetState(() => scopedLayers = replacement);
    await settle(tester);

    expect(find.text(_swappedLayerName), findsWidgets);
    expect(find.text(_topLayerName), findsNothing);
  });

  testWidgets('layer picker header button arms and disarms the picker', (WidgetTester tester) async {
    await pumpPanel(tester);

    await tester.tap(find.byKey(Keys.layerPickerToggleButton));
    await tester.pump();
    expect(appProvider.layerPickerPosition, isNotNull);

    await tester.tap(find.byKey(Keys.layerPickerToggleButton));
    await tester.pump();
    expect(appProvider.layerPickerPosition, isNull);
    await settle(tester);
  });
}
