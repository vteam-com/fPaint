import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/widgets/app_progress.dart';
import 'package:fpaint/widgets/app_snackbar.dart';

Widget _buildSnackbarTestApp({
  required final Widget child,
  final GlobalKey<NavigatorState>? navigatorKey,
}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

Widget _buildNestedOverlayTestApp({
  required final Widget child,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 120,
          height: 120,
          child: Overlay(
            initialEntries: <OverlayEntry>[
              OverlayEntry(
                builder: (final BuildContext context) => child,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('AppNotificationOverlay', () {
    testWidgets('shows and auto-dismisses notification', (final WidgetTester tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        _buildSnackbarTestApp(
          child: Builder(
            builder: (final BuildContext context) {
              savedContext = context;
              return const SizedBox();
            },
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
        _buildSnackbarTestApp(
          child: Builder(
            builder: (final BuildContext context) {
              savedContext = context;
              return const SizedBox();
            },
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
        _buildSnackbarTestApp(
          child: Builder(
            builder: (final BuildContext context) {
              savedContext = context;
              return const SizedBox();
            },
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

    testWidgets('shows optional subtitle below the message', (final WidgetTester tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        _buildSnackbarTestApp(
          child: Builder(
            builder: (final BuildContext context) {
              savedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      AppNotificationOverlay.show(
        savedContext,
        'Saved',
        subtitle: 'image.ora',
      );
      await tester.pump();

      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('image.ora'), findsOneWidget);

      final Text titleText = tester.widget<Text>(find.text('Saved'));
      final Text subtitleText = tester.widget<Text>(find.text('image.ora'));

      expect(titleText.style?.color, AppColors.white);
      expect(subtitleText.style?.fontSize, AppFontSize.medium);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    });

    testWidgets('inserts the notification into the root overlay', (final WidgetTester tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        _buildNestedOverlayTestApp(
          child: Builder(
            builder: (final BuildContext context) {
              savedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      AppNotificationOverlay.show(savedContext, 'Saved');
      await tester.pump();

      final double notificationTop = tester.getTopLeft(find.text('Saved')).dy;

      expect(notificationTop, greaterThan(200));

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    });
  });

  group('AppSnackBarBuildContextX', () {
    testWidgets('showSnackBarMessage displays notification', (final WidgetTester tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        _buildSnackbarTestApp(
          child: Builder(
            builder: (final BuildContext context) {
              savedContext = context;
              return const SizedBox();
            },
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

    testWidgets('showSavedFileSnackBar displays localized title and filename subtitle', (
      final WidgetTester tester,
    ) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        _buildSnackbarTestApp(
          child: Builder(
            builder: (final BuildContext context) {
              savedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      savedContext.showSavedFileSnackBar('/tmp/work/image.png');
      await tester.pump();

      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('image.png'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    });

    testWidgets('showGlobalSavedFileSnackBar displays localized title and filename subtitle', (
      final WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildSnackbarTestApp(
          navigatorKey: appSnackBarNavigatorKey,
          child: const SizedBox(),
        ),
      );

      showGlobalSavedFileSnackBar('/tmp/work/image.png');
      await tester.pump();

      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('image.png'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    });

    testWidgets('showGlobalSavingFileSnackBar stays visible with progress until dismissed', (
      final WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildSnackbarTestApp(
          navigatorKey: appSnackBarNavigatorKey,
          child: const SizedBox(),
        ),
      );

      showGlobalSavingFileSnackBar('/tmp/work/image.png');
      await tester.pump();

      expect(find.text('Saving...'), findsOneWidget);
      expect(find.text('image.png'), findsOneWidget);
      expect(find.byType(AppProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(find.text('Saving...'), findsOneWidget);

      dismissGlobalSnackBarMessage();
      await tester.pump();

      expect(find.text('Saving...'), findsNothing);
      expect(find.byType(AppProgressIndicator), findsNothing);
    });

    testWidgets('runWithGlobalFileSaveSnackBar shows progress then saved', (
      final WidgetTester tester,
    ) async {
      final Completer<void> completer = Completer<void>();

      await tester.pumpWidget(
        _buildSnackbarTestApp(
          navigatorKey: appSnackBarNavigatorKey,
          child: const SizedBox(),
        ),
      );

      final Future<void> task = runWithGlobalFileSaveSnackBar<void>(
        initialFilePath: '/tmp/work/image.png',
        completedFilePathBuilder: () => '/tmp/work/image.png',
        task: () => completer.future,
      );
      await tester.pump();

      expect(find.text('Saving...'), findsOneWidget);
      expect(find.byType(AppProgressIndicator), findsOneWidget);

      completer.complete();
      await task;
      await tester.pump();

      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('image.png'), findsOneWidget);
      expect(find.byType(AppProgressIndicator), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    });

    testWidgets('runWithGlobalFileSaveSnackBar dismisses progress on error', (
      final WidgetTester tester,
    ) async {
      final Completer<void> completer = Completer<void>();

      await tester.pumpWidget(
        _buildSnackbarTestApp(
          navigatorKey: appSnackBarNavigatorKey,
          child: const SizedBox(),
        ),
      );

      final Future<void> task = runWithGlobalFileSaveSnackBar<void>(
        initialFilePath: '/tmp/work/image.png',
        completedFilePathBuilder: () => '/tmp/work/image.png',
        task: () => completer.future,
      );
      await tester.pump();

      expect(find.text('Saving...'), findsOneWidget);

      completer.completeError(StateError('save failed'));
      await expectLater(task, throwsStateError);
      await tester.pump();

      expect(find.text('Saving...'), findsNothing);
      expect(find.text('Saved'), findsNothing);
      expect(find.byType(AppProgressIndicator), findsNothing);
    });
  });
}
