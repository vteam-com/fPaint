import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/panels/side_panel/canvas_settings.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppProvider appProvider;
  late ShellProvider shellProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppPreferences preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    appProvider.layers.size = const Size(800, 600);
    appProvider.layers.canvasResizeLockAspectRatio = true;
    shellProvider = ShellProvider();
  });

  Future<void> pumpCanvasSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      InheritedControllerScope<ShellProvider>(
        controller: shellProvider,
        child: InheritedControllerScope<LayersProvider>(
          controller: appProvider.layers,
          child: InheritedControllerScope<AppProvider>(
            controller: appProvider,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (BuildContext context) {
                    return GestureDetector(
                      key: const Key('openCanvasSettings'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => showCanvasSettings(context),
                      child: const SizedBox(width: 40, height: 40),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('openCanvasSettings')));
    await tester.pumpAndSettle();
  }

  Finder editableIn(Key fieldKey) {
    return find.descendant(
      of: find.byKey(fieldKey),
      matching: find.byType(EditableText),
    );
  }

  group('showCanvasSettings aspect ratio sync', () {
    testWidgets('editing width keeps the typed value and updates height', (WidgetTester tester) async {
      await pumpCanvasSettings(tester);

      expect(widthController.text, '800');
      expect(heightController.text, '600');

      await tester.enterText(editableIn(Keys.canvasSettingsWidthField), '400');
      await tester.pump();

      expect(widthController.text, '400');
      expect(heightController.text, '300');
    });

    testWidgets('editing height keeps the typed value and updates width', (WidgetTester tester) async {
      await pumpCanvasSettings(tester);

      await tester.enterText(editableIn(Keys.canvasSettingsHeightField), '150');
      await tester.pump();

      expect(heightController.text, '150');
      expect(widthController.text, '200');
    });

    testWidgets('incomplete input does not clobber the other field', (WidgetTester tester) async {
      await pumpCanvasSettings(tester);

      await tester.enterText(editableIn(Keys.canvasSettingsWidthField), '');
      await tester.pump();

      expect(widthController.text, '');
      expect(heightController.text, '600');
    });

    testWidgets('apply resizes the canvas to the entered dimensions', (WidgetTester tester) async {
      await pumpCanvasSettings(tester);

      await tester.enterText(editableIn(Keys.canvasSettingsWidthField), '400');
      await tester.pump();
      await tester.tap(find.byKey(Keys.canvasSettingsApplyButton));
      await tester.pumpAndSettle();

      expect(appProvider.layers.size, const Size(400, 300));

      // Drain timers started by the resize/update path so teardown is clean.
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
