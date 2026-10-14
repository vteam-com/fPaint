import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/panels/layers/layer_selector.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:fpaint/widgets/app_buttons.dart';
import 'package:material_ui/material_ui.dart';

/// Regression: dismissing the layer blend-mode menu must not reset the
/// layer to Normal (srcOver).
void main() {
  late UndoProvider undo;
  late LayersProvider layers;
  late AppProvider app;

  Future<void> pumpSelector(WidgetTester tester) async {
    undo = UndoProvider();
    layers = LayersProvider(undoProvider: undo)..size = const Size(800, 800);
    app = AppProvider(
      preferences: AppPreferences(),
      layersProvider: layers,
      undoProvider: undo,
    );
    addTearDown(() {
      app.dispose();
      layers.dispose();
      undo.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: LayerSelector(
              context: context,
              layers: layers,
              layer: layers.list.first,
              minimal: false,
              isSelected: true,
              allowRemoveLayer: true,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openBlendMenu(WidgetTester tester) async {
    await tester.tap(
      find.byWidgetPredicate(
        (Widget widget) => widget is AppButtonIcon && widget.icon == AppIcon.blender,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Multiply'), findsWidgets);
  }

  Future<void> drainThumbnailTimer(WidgetTester tester) async {
    await tester.pump(AppDefaults.thumbnailDebounceDuration);
    await tester.pumpAndSettle();
  }

  testWidgets('cancelling the blend menu keeps the current blend mode', (
    WidgetTester tester,
  ) async {
    await pumpSelector(tester);
    layers.list.first.blendMode = BlendMode.multiply;
    await tester.pumpAndSettle();

    await openBlendMenu(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(layers.list.first.blendMode, BlendMode.multiply);
    await drainThumbnailTimer(tester);
  });

  testWidgets('choosing a blend mode applies it to the layer', (
    WidgetTester tester,
  ) async {
    await pumpSelector(tester);

    await openBlendMenu(tester);
    await tester.tap(find.text('Screen').last);
    await tester.pumpAndSettle();

    expect(layers.list.first.blendMode, BlendMode.screen);
    await drainThumbnailTimer(tester);
  });
}
