import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/dependency_versions.dart';
import 'package:fpaint/models/version.dart';
import 'package:fpaint/panels/side_panel/about.dart';
import 'package:fpaint/panels/side_panel/attribution_dialog.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:material_ui/material_ui.dart' show MaterialApp, Scaffold;

const String _expandablePackage = 'args';
const String _firstLicenseParagraph = 'Copyright 2019 Args Authors.';
const String _secondLicenseParagraph = 'Licensed under the Args Terms.';
const String _otherLicense = 'Args alternate notice without a date.';

void main() {
  group('showAboutBox', () {
    testWidgets('shows about dialog and dismisses', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
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
      expect(find.textContaining('fPaint $packageVersion'), findsOneWidget);
      expect(find.text('Attribution'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.textContaining('fPaint'), findsWidgets);

      // Dismiss.
      final AppLocalizations l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.close));
      await tester.pumpAndSettle();
    });

    testWidgets('opens flutter attribution dialog and closes it', (WidgetTester tester) async {
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
              builder: (BuildContext context) {
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
      expect(find.text('archive (v${dependencyVersions['archive']})'), findsOneWidget);

      final AppLocalizations l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.close), findsOneWidget);
      await tester.tap(find.text(l10n.close));
      await tester.pumpAndSettle();
    });
  });
  group('showAttributionDialog', () {
    testWidgets('tapping a package heading expands and collapses its license texts', (WidgetTester tester) async {
      LicenseRegistry.addLicense(() async* {
        yield const LicenseEntryWithLineBreaks(
          <String>[_expandablePackage],
          '$_firstLicenseParagraph\n\n$_secondLicenseParagraph',
        );
        yield const LicenseEntryWithLineBreaks(<String>[_expandablePackage], _otherLicense);
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return GestureDetector(
                  onTap: () => showAttributionDialog(context),
                  child: const AppText('Show Attribution'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Attribution'));
      await tester.pumpAndSettle();

      final String heading = '$_expandablePackage (v${dependencyVersions[_expandablePackage]})';
      expect(find.text(_otherLicense), findsNothing);

      await tester.tap(find.text(heading));
      await tester.pumpAndSettle();
      expect(find.text('$_firstLicenseParagraph\n$_secondLicenseParagraph'), findsOneWidget);
      expect(find.text(_otherLicense), findsOneWidget);

      await tester.tap(find.text(heading));
      await tester.pumpAndSettle();
      expect(find.text(_otherLicense), findsNothing);
    });
  });
}
