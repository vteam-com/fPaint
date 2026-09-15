import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/panels/layers/layer_selector.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:material_ui/material_ui.dart';

/// Regression test: tapping the eye toggle must repaint the icon on the next
/// frame.
///
/// The layers panel builds each row inside a `ListenableBuilder` on the
/// LayerProvider, but `layersToggleVisibility` only notified the parent
/// LayersProvider. The row therefore kept the stale icon until some unrelated
/// interaction rebuilt it — selecting another layer and coming back. The
/// visibility setter now notifies the layer itself.
void main() {
  testWidgets('toggling visibility flips the eye icon on the next frame', (
    WidgetTester tester,
  ) async {
    final UndoProvider undo = UndoProvider();
    final LayersProvider layers = LayersProvider(undoProvider: undo)..size = const Size(64, 64);
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

    final LayerProvider layer = layers.list.first;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            // Mirrors the real panel: the row rebuilds off the layer's own
            // notifier, not the LayersProvider's.
            body: ListenableBuilder(
              listenable: layer,
              builder: (BuildContext _, Widget? _) => LayerSelector(
                context: context,
                layers: layers,
                layer: layer,
                minimal: false,
                isSelected: true,
                allowRemoveLayer: false,
              ),
            ),
          ),
        ),
      ),
    );

    AppSvgIcon eyeIcon() => tester
        .widgetList<AppSvgIcon>(find.byType(AppSvgIcon))
        .firstWhere(
          (AppSvgIcon i) => i.icon == AppIcon.visibility || i.icon == AppIcon.visibilityOff,
        );

    expect(layer.isVisible, isTrue);
    expect(eyeIcon().icon, AppIcon.visibility);
    expect(eyeIcon().color, AppColors.primary);

    // Toggle through the provider WITHOUT touching the button: tapping it
    // rebuilds AppButton's own hover/pressed state, which would drag the icon
    // along and mask a missing notification.
    layers.layersToggleVisibility(layer);
    await tester.pump();

    expect(layer.isVisible, isFalse);
    expect(eyeIcon().icon, AppIcon.visibilityOff);
    expect(eyeIcon().color, AppColors.layerHiddenWarning);

    layers.layersToggleVisibility(layer);
    await tester.pump();

    expect(layer.isVisible, isTrue);
    expect(eyeIcon().icon, AppIcon.visibility);
    expect(eyeIcon().color, AppColors.primary);

    // Drain the debounced thumbnail rebuild so no timer outlives the tree.
    await tester.pump(AppDefaults.thumbnailDebounceDuration);
    await tester.pumpAndSettle();
  });
}
