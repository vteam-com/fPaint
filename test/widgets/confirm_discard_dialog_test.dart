import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/widgets/confirm_discard_dialog.dart';

void main() {
  group('confirmDiscardCurrentWork', () {
    testWidgets('shows dialog with discard and no buttons', (final WidgetTester tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (final BuildContext context) {
                savedContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      // Show dialog
      final Future<bool> resultFuture = confirmDiscardCurrentWork(savedContext);
      await tester.pumpAndSettle();

      // Should show both Discard and No buttons
      expect(find.text('Discard'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);

      // Tap No
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();

      final bool result = await resultFuture;
      expect(result, isFalse);
    });

    testWidgets('returns true when discard is tapped', (final WidgetTester tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (final BuildContext context) {
                savedContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      final Future<bool> resultFuture = confirmDiscardCurrentWork(savedContext);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      final bool result = await resultFuture;
      expect(result, isTrue);
    });
  });
}
