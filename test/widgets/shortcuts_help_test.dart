import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/shortcuts.dart';
import 'package:fpaint/widgets/shortcuts_help.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Widget buildTestWidget() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Localizations(
          locale: const Locale('en'),
          delegates: AppLocalizations.localizationsDelegates,
          child: Navigator(
            onGenerateRoute: (final RouteSettings _) {
              return PageRouteDirectionality(
                builder: (final BuildContext context) {
                  return const ShortcutsHelpDialog();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildShortcutHandlerTestWidget({
    required final AppProvider appProvider,
    required final ShellProvider shellProvider,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Localizations(
          locale: const Locale('en'),
          delegates: AppLocalizations.localizationsDelegates,
          child: Navigator(
            onGenerateRoute: (final RouteSettings _) {
              return PageRouteDirectionality(
                builder: (final BuildContext context) {
                  return shortCutsForMainApp(
                    context,
                    shellProvider,
                    appProvider,
                    const SizedBox.shrink(),
                    onSave: () async {},
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  group('ShortcutsHelpDialog', () {
    testWidgets('renders the dialog', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byType(ShortcutsHelpDialog), findsOneWidget);
    });

    testWidgets('displays Keyboard Shortcuts title', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Keyboard Shortcuts'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows File Operations category', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('File Operations'), findsOneWidget);
    });

    testWidgets('shows Editing category', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Editing'), findsOneWidget);
    });

    testWidgets('shows View category', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('View'), findsOneWidget);
    });

    testWidgets('shows Tools category', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Tools'), findsOneWidget);
    });

    testWidgets('shows Layers category', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Layers'), findsOneWidget);
    });

    testWidgets('shows Save shortcut', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('shows Undo shortcut', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('shows Close button', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('shows platform modifier key', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Should find either Cmd or Ctrl depending on platform
      final bool hasCmd = find.textContaining('Cmd').evaluate().isNotEmpty;
      final bool hasCtrl = find.textContaining('Ctrl').evaluate().isNotEmpty;
      expect(hasCmd || hasCtrl, isTrue);
    });

    testWidgets('shows Brush Tool shortcut', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Brush Tool'), findsOneWidget);
    });

    testWidgets('shows Eraser Tool shortcut', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Eraser Tool'), findsOneWidget);
    });

    testWidgets('shows Tab shortcut for shell toggle', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Tab'), findsOneWidget);
      expect(find.text('Toggle Shell'), findsOneWidget);
    });

    testWidgets('shows F1 help shortcut entry', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Ctrl /, F1'), findsOneWidget);
      expect(find.text('Keyboard Shortcuts'), findsAtLeastNWidgets(2));
    });
  });

  group('shortCutsForMainApp', () {
    testWidgets('opens keyboard shortcuts dialog with F1', (final WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppPreferences preferences = AppPreferences();
      await preferences.getPref();
      final AppProvider appProvider = AppProvider(preferences: preferences);
      final ShellProvider shellProvider = ShellProvider();

      await tester.pumpWidget(
        buildShortcutHandlerTestWidget(
          appProvider: appProvider,
          shellProvider: shellProvider,
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pump();

      expect(find.byType(ShortcutsHelpDialog), findsOneWidget);
    });
  });
}

/// A simple PageRoute that provides Directionality.
class PageRouteDirectionality extends PageRoute<void> {
  PageRouteDirectionality({required this.builder});

  final WidgetBuilder builder;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Widget buildPage(
    final BuildContext context,
    final Animation<double> animation,
    final Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }
}
