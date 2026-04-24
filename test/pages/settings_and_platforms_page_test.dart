import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/pages/platforms_page.dart';
import 'package:fpaint/pages/settings_page.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/widgets/material_free/material_free.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('SettingsPage updates preferences and opens shortcuts help', (final WidgetTester tester) async {
    final AppPreferences preferences = await _createPreferences();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppPreferences>.value(
        value: preferences,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings...'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Use Apple Pencil Only'), findsOneWidget);

    await tester.tap(find.byType(AppDropdown<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('French').last);
    await tester.pumpAndSettle();

    expect(preferences.languageCode, 'fr');

    await tester.tap(find.byType(AppToggleSwitch));
    await tester.pumpAndSettle();

    expect(preferences.useApplePencil, isTrue);

    await tester.tap(find.widgetWithText(AppTextButton, 'Keyboard Shortcuts'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('Keyboard Shortcuts'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('Close'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('PlatformsPage renders all supported platform cards', (final WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PlatformsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Available Platforms'), findsOneWidget);
    expect(find.byType(AppCard), findsNWidgets(6));
    expect(find.byType(ClipOval), findsNWidgets(6));
    expect(find.text('macOS'), findsOneWidget);
    expect(find.text('Windows'), findsOneWidget);
    expect(find.text('Linux'), findsOneWidget);
    expect(find.text('iOS'), findsOneWidget);
    expect(find.text('Android'), findsOneWidget);
    expect(find.text('Web Browser'), findsOneWidget);
  });
}

Future<AppPreferences> _createPreferences() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final AppPreferences preferences = AppPreferences();
  await preferences.getPref();
  return preferences;
}
