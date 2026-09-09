import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/panels/side_panel/image_size_settings.dart';
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
    shellProvider = ShellProvider();
  });

  Future<void> pumpImageSizeSettings(WidgetTester tester) async {
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
                      key: const Key('openImageSizeSettings'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => showImageSizeSettings(context),
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
    await tester.tap(find.byKey(const Key('openImageSizeSettings')));
    await tester.pumpAndSettle();
  }

  Finder editableIn(Key fieldKey) {
    return find.descendant(
      of: find.byKey(fieldKey),
      matching: find.byType(EditableText),
    );
  }

  String textIn(WidgetTester tester, Key fieldKey) {
    return tester.widget<EditableText>(editableIn(fieldKey)).controller.text;
  }

  group('showImageSizeSettings', () {
    testWidgets('opens pre-filled with the current size and the lock engaged', (WidgetTester tester) async {
      await pumpImageSizeSettings(tester);

      expect(textIn(tester, Keys.imageSizeWidthField), '800');
      expect(textIn(tester, Keys.imageSizeHeightField), '600');

      // Locked by default: editing width follows through to height.
      await tester.enterText(editableIn(Keys.imageSizeWidthField), '400');
      await tester.pump();
      expect(textIn(tester, Keys.imageSizeHeightField), '300');
    });

    testWidgets('editing height updates width while locked', (WidgetTester tester) async {
      await pumpImageSizeSettings(tester);

      await tester.enterText(editableIn(Keys.imageSizeHeightField), '150');
      await tester.pump();

      expect(textIn(tester, Keys.imageSizeHeightField), '150');
      expect(textIn(tester, Keys.imageSizeWidthField), '200');
    });

    testWidgets('unlocking lets the fields move independently, relocking recaptures the ratio', (
      WidgetTester tester,
    ) async {
      await pumpImageSizeSettings(tester);

      await tester.tap(find.byKey(Keys.imageSizeAspectRatioToggleButton));
      await tester.pump();
      await tester.enterText(editableIn(Keys.imageSizeWidthField), '600');
      await tester.pump();
      expect(textIn(tester, Keys.imageSizeHeightField), '600');

      // Relock at 1:1 and check the new ratio drives the sync.
      await tester.tap(find.byKey(Keys.imageSizeAspectRatioToggleButton));
      await tester.pump();
      await tester.enterText(editableIn(Keys.imageSizeWidthField), '300');
      await tester.pump();
      expect(textIn(tester, Keys.imageSizeHeightField), '300');
    });

    testWidgets('incomplete input does not clobber the other field', (WidgetTester tester) async {
      await pumpImageSizeSettings(tester);

      await tester.enterText(editableIn(Keys.imageSizeWidthField), '');
      await tester.pump();

      expect(textIn(tester, Keys.imageSizeWidthField), '');
      expect(textIn(tester, Keys.imageSizeHeightField), '600');
    });

    testWidgets('apply resamples the image to the entered dimensions', (WidgetTester tester) async {
      await pumpImageSizeSettings(tester);

      await tester.enterText(editableIn(Keys.imageSizeWidthField), '400');
      await tester.pump();
      await tester.tap(find.byKey(Keys.imageSizeApplyButton));
      await tester.pumpAndSettle();

      expect(appProvider.layers.size, const Size(400, 300));
      expect(shellProvider.canvasPlacement, CanvasAutoPlacement.manual);
      expect(find.byKey(Keys.imageSizeApplyButton), findsNothing);

      // Drain timers started by the resize/update path so teardown is clean.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('rejects non-numeric and non-positive sizes and stays open', (WidgetTester tester) async {
      await pumpImageSizeSettings(tester);

      await tester.enterText(editableIn(Keys.imageSizeWidthField), 'abc');
      await tester.pump();
      await tester.tap(find.byKey(Keys.imageSizeApplyButton));
      await tester.pump();
      expect(appProvider.layers.size, const Size(800, 600));
      expect(find.byKey(Keys.imageSizeApplyButton), findsOneWidget);

      await tester.enterText(editableIn(Keys.imageSizeWidthField), '0');
      await tester.pump();
      await tester.tap(find.byKey(Keys.imageSizeApplyButton));
      await tester.pump();
      expect(appProvider.layers.size, const Size(800, 600));
      expect(find.byKey(Keys.imageSizeApplyButton), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
    });
  });
}
