import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart' show MaterialApp, Scaffold;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/panels/side_panel/about.dart';
import 'package:fpaint/widgets/material_free.dart';

void main() {
  group('showAboutBox', () {
    testWidgets('shows about dialog and dismisses', (final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (final BuildContext context) {
                return GestureDetector(
                  onTap: () => showAboutBox(context),
                  child: const AppText('Show About'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show About'));
      await tester.pumpAndSettle();

      // About dialog should be visible.
      expect(find.text('(c) 2025 VTeam'), findsOneWidget);
      expect(find.textContaining('fPaint 1.8.5'), findsOneWidget);
      expect(find.text('Attribution'), findsOneWidget);
      expect(find.textContaining('fPaint'), findsWidgets);

      // Dismiss.
      final AppLocalizations l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.close));
      await tester.pumpAndSettle();
    });

    testWidgets('opens flutter attribution dialog and closes it', (final WidgetTester tester) async {
      LicenseRegistry.addLicense(() async* {
        yield const LicenseEntryWithLineBreaks(
          <String>['archive'],
          'Copyright 2020 Example Authors.\nLicensed under Example Terms.',
        );
        yield const LicenseEntryWithLineBreaks(
          <String>['archive'],
          'Copyright 2021 Example Authors.\nLicensed under Example Terms.',
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (final BuildContext context) {
                return GestureDetector(
                  onTap: () => showAboutBox(context),
                  child: const AppText('Show About'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show About'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Attribution'));
      await tester.pumpAndSettle();

      // Attribution dialog should be visible with deduplicated versioned package heading.
      expect(find.textContaining('Attribution ('), findsOneWidget);
      expect(find.text('archive (v4.0.9)'), findsOneWidget);

      final AppLocalizations l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.close), findsOneWidget);
      await tester.tap(find.text(l10n.close));
      await tester.pumpAndSettle();
    });
  });
}
