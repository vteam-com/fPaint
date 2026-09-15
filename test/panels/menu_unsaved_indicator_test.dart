import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/panels/side_panel/menu.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Widget buildHarness() {
    return InheritedControllerScope<AppPreferences>(
      controller: preferences,
      child: InheritedControllerScope<LayersProvider>(
        controller: appProvider.layers,
        child: InheritedControllerScope<ShellProvider>(
          controller: shellProvider,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: MainMenu(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  AppSvgIcon menuIcon(WidgetTester tester) {
    return tester.widget<AppSvgIcon>(
      find.byWidgetPredicate(
        (Widget widget) => widget is AppSvgIcon && widget.icon == AppIcon.moreVert,
      ),
    );
  }

  testWidgets('a saved document leaves the menu icon untinted', (WidgetTester tester) async {
    await tester.pumpWidget(buildHarness());

    expect(menuIcon(tester).color, isNull);
    expect(find.byKey(Keys.mainMenuUnsavedIndicator), findsNothing);
  });

  testWidgets('an edited document tints the menu icon', (WidgetTester tester) async {
    await tester.pumpWidget(buildHarness());

    appProvider.layers.markAllChanged();
    await tester.pump();

    expect(menuIcon(tester).color, AppColors.unsavedChangesIndicator);
    expect(
      find.descendant(
        of: find.byType(MainMenu),
        matching: find.byKey(Keys.mainMenuUnsavedIndicator),
      ),
      findsWidgets,
    );
  });

  testWidgets('saving clears the tint again', (WidgetTester tester) async {
    await tester.pumpWidget(buildHarness());

    appProvider.layers.markAllChanged();
    await tester.pump();
    expect(menuIcon(tester).color, AppColors.unsavedChangesIndicator);

    appProvider.layers.clearHasChanged();
    await tester.pump();

    expect(menuIcon(tester).color, isNull);
    expect(find.byKey(Keys.mainMenuUnsavedIndicator), findsNothing);
  });
}
