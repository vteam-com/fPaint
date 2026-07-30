import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/panels/layers/layer_selector.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';

/// Regression test for the embedded-editor startup crash:
/// `No InheritedControllerScope<LayersProvider> found in context`.
///
/// A host app (e.g. story's PanelCanvasEditor) inserts the editor's
/// InheritedControllerScope below the app navigator/overlay. Any fpaint widget
/// built in an overlay subtree — rooted ABOVE that scope — cannot resolve
/// LayersProvider from context. [LayerSelector] therefore takes its
/// [LayersProvider] as a parameter (the parent already holds it) instead of
/// looking it up, so it renders wherever it is mounted.
void main() {
  testWidgets('LayerSelector renders without a LayersProvider scope ancestor', (
    final WidgetTester tester,
  ) async {
    final UndoProvider undo = UndoProvider();
    final LayersProvider layers = LayersProvider(undoProvider: undo)..size = const Size(800, 800);
    final AppProvider app = AppProvider(
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
        // No InheritedControllerScope anywhere in the tree, mimicking an overlay
        // subtree that roots above the editor's scope.
        home: Builder(
          builder: (final BuildContext context) => Scaffold(
            body: LayerSelector(
              context: context,
              layers: layers,
              layer: layers.list.first,
              minimal: false,
              isSelected: true,
              allowRemoveLayer: false,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(LayerSelector), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Drain the layer's debounced thumbnail rebuild so no timer outlives the
    // test tree at teardown.
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });
}
