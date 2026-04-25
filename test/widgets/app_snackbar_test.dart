import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/widgets/material_free/app_snackbar.dart';

void main() {
  group('AppNotificationOverlay', () {
    testWidgets('shows and auto-dismisses notification', (final WidgetTester tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        MaterialApp(
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

      AppNotificationOverlay.show(savedContext, 'Test notification');
      await tester.pump();

      expect(find.text('Test notification'), findsOneWidget);

      // Fast-forward past the 4-second auto-dismiss
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(find.text('Test notification'), findsNothing);
    });

    testWidgets('shows notification with custom duration', (final WidgetTester tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        MaterialApp(
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

      AppNotificationOverlay.show(
        savedContext,
        'Quick message',
        duration: const Duration(seconds: 1),
      );
      await tester.pump();

      expect(find.text('Quick message'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(find.text('Quick message'), findsNothing);
    });

    testWidgets('replaces previous notification', (final WidgetTester tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        MaterialApp(
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

      AppNotificationOverlay.show(savedContext, 'First message');
      await tester.pump();
      expect(find.text('First message'), findsOneWidget);

      AppNotificationOverlay.show(savedContext, 'Second message');
      await tester.pump();
      expect(find.text('First message'), findsNothing);
      expect(find.text('Second message'), findsOneWidget);

      // Clean up
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    });
  });

  group('AppSnackBarBuildContextX', () {
    testWidgets('showSnackBarMessage displays notification', (final WidgetTester tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        MaterialApp(
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

      savedContext.showSnackBarMessage('Extension message');
      await tester.pump();

      expect(find.text('Extension message'), findsOneWidget);

      // Clean up
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    });
  });
}
