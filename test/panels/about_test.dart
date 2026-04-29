import 'package:flutter/material.dart' show MaterialApp, Scaffold;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/panels/side_panel/about.dart';
import 'package:fpaint/widgets/material_free.dart';

void main() {
  group('showAboutBox', () {
    setUp(() {
      // Mock PackageInfo platform channel.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/package_info'),
        (final MethodCall methodCall) async {
          if (methodCall.method == 'getAll') {
            return <String, dynamic>{
              'appName': 'fPaint',
              'packageName': 'com.vteam.fpaint',
              'version': '1.0.0',
              'buildNumber': '1',
              'buildSignature': '',
              'installerStore': '',
            };
          }
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/package_info'),
        null,
      );
    });

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
      expect(find.textContaining('fPaint'), findsWidgets);

      // Dismiss.
      final AppLocalizations l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
    });
  });
}
