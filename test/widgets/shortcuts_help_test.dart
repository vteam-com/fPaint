import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/widgets/shortcuts_help.dart';

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

  group('ShortcutsHelpDialog', () {
    testWidgets('renders the dialog', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byType(ShortcutsHelpDialog), findsOneWidget);
    });

    testWidgets('displays Keyboard Shortcuts title', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Keyboard Shortcuts'), findsOneWidget);
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
