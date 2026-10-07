import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/panels/side_panel/top_menu_and_layers_panel.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enough layers that the list overflows [_panelSize] several times over.
const int _layerCount = 30;

/// A side-panel slot far shorter than the layer list.
const Size _panelSize = Size(400, 300);

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

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      InheritedControllerScope<ShellProvider>(
        controller: shellProvider,
        child: InheritedControllerScope<AppPreferences>(
          controller: preferences,
          child: InheritedControllerScope<AppProvider>(
            controller: appProvider,
            child: InheritedControllerScope<LayersProvider>(
              controller: appProvider.layers,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox.fromSize(
                    size: _panelSize,
                    child: const TopMenuAndLayersPanel(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Settles the reveal animation, then drains the debounced thumbnail
  /// rebuilds so no timer outlives the test.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(AppDefaults.thumbnailDebounceDuration);
    await tester.pumpAndSettle();
  }

  bool isRowFullyVisible(WidgetTester tester, LayerProvider layer) {
    final Finder row = find.byKey(GlobalObjectKey(layer));
    if (row.evaluate().isEmpty) {
      return false;
    }
    final Rect viewport = tester.getRect(find.byType(ListView));
    final Rect rowRect = tester.getRect(row);
    return rowRect.top >= viewport.top && rowRect.bottom <= viewport.bottom;
  }

  testWidgets('scrolls an off-screen selected layer into view', (WidgetTester tester) async {
    for (int i = 1; i < _layerCount; i++) {
      appProvider.layers.addTop(name: 'Layer $i');
    }
    appProvider.layers.selectedLayerIndex = 0;
    await pumpPanel(tester);

    final LayerProvider bottomLayer = appProvider.layers.get(appProvider.layers.length - 1);
    expect(isRowFullyVisible(tester, bottomLayer), isFalse);

    // What the on-canvas layer picker does when it lands on a buried layer.
    appProvider.layers.selectedLayerIndex = appProvider.layers.length - 1;
    await settle(tester);

    expect(isRowFullyVisible(tester, bottomLayer), isTrue);
  });

  testWidgets('leaves the list alone when the selected layer is already visible', (WidgetTester tester) async {
    for (int i = 1; i < _layerCount; i++) {
      appProvider.layers.addTop(name: 'Layer $i');
    }
    appProvider.layers.selectedLayerIndex = 0;
    await pumpPanel(tester);

    final ScrollPosition position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    final double offsetBefore = position.pixels;

    appProvider.layers.selectedLayerIndex = 1;
    await settle(tester);

    expect(position.pixels, offsetBefore);
  });
}
