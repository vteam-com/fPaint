import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/widgets/app_progress.dart';
import 'package:fpaint/widgets/app_snackbar.dart';
import 'package:material_ui/material_ui.dart';

Widget _buildSnackbarTestApp({
  required Widget child,
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

Widget _buildNestedOverlayTestApp({
  required Widget child,
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
                builder: (BuildContext context) => child,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The yellow Flutter underlines text with when it falls back to
/// [WidgetsApp.textStyle] for want of a [DefaultTextStyle] ancestor.
const Color _debugFallbackUnderline = Color(0xFFFFFF00);

void main() {
  group('AppNotificationOverlay', () {
    testWidgets('shows and auto-dismisses notification', (WidgetTester tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        _buildSnackbarTestApp(
          child: Builder(
            builder: (BuildContext context) {
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

    testWidgets('shows notification with custom duration', (WidgetTester tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        _buildSnackbarTestApp(
          child: Builder(
            builder: (BuildContext context) {
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

    testWidgets('replaces previous notification', (WidgetTester tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        _buildSnackbarTestApp(
          child: Builder(
            builder: (BuildContext context) {
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

    testWidgets('shows optional subtitle below the message', (WidgetTester tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        _buildSnackbarTestApp(
          child: Builder(
            builder: (BuildContext context) {
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

      // Read the style that is actually painted rather than the [Text]'s own
      // `style` field: the snackbar renders in an overlay, where text with no
      // inherited style gets Flutter's yellow debug underlines, so each label
      // is given a complete style through an ancestor [DefaultTextStyle].
      TextStyle paintedStyle(Finder text) => tester
          .widget<RichText>(
            find.descendant(of: text, matching: find.byType(RichText)),
          )
          .text
          .style!;

      final TextStyle titleStyle = paintedStyle(find.text('Saved'));
      final TextStyle subtitleStyle = paintedStyle(find.text('image.ora'));

      expect(titleStyle.color, AppColors.white);
      expect(subtitleStyle.fontSize, AppFontSize.medium);
      // The reason the wrapper exists. Without an enclosing [DefaultTextStyle]
      // these labels fall back to [WidgetsApp.textStyle], which MaterialApp
      // sets to a "consider putting your text in a Material" style drawn with
      // a doubled yellow underline — what the overlay was actually rendering.
      expect(titleStyle.decoration, isNot(TextDecoration.underline));
      expect(subtitleStyle.decoration, isNot(TextDecoration.underline));
      expect(titleStyle.decorationColor, isNot(_debugFallbackUnderline));
      expect(subtitleStyle.decorationColor, isNot(_debugFallbackUnderline));

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    });

    testWidgets('inserts the notification into the root overlay', (WidgetTester tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        _buildNestedOverlayTestApp(
          child: Builder(
            builder: (BuildContext context) {
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
    testWidgets('showSnackBarMessage displays notification', (WidgetTester tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        _buildSnackbarTestApp(
          child: Builder(
            builder: (BuildContext context) {
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
      WidgetTester tester,
    ) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        _buildSnackbarTestApp(
          child: Builder(
            builder: (BuildContext context) {
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
      WidgetTester tester,
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
      WidgetTester tester,
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
      WidgetTester tester,
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
      WidgetTester tester,
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
