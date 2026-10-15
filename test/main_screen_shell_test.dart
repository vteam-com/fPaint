import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/panels/side_panel/side_panel.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_snackbar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _desktopViewSize = Size(1600, 900);

/// A phone-class width (below [AppLayout.desktopBreakpoint]) wide enough that
/// the responsive top bar fits; narrower phones currently overflow it.
const Size _phoneViewSize = Size(500, 800);
const String _unsupportedDropPath = '/tmp/dropped.unsupported';
const String _unsupportedDropMessage = 'File format .unsupported is not supported';
const Offset _phoneOverlayTapPoint = Offset(10, 400);
const Duration _snackBarDismissWait = Duration(seconds: 5);

void main() {
  late AppPreferences preferences;
  late AppProvider appProvider;
  late ShellProvider shellProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    shellProvider = ShellProvider();
  });

  Future<void> pumpMainScreen(WidgetTester tester, Size viewSize) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = AppMath.one.toDouble();
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      InheritedControllerScope<ShellProvider>(
        controller: shellProvider,
        child: InheritedControllerScope<AppPreferences>(
          controller: preferences,
          child: InheritedControllerScope<AppProvider>(
            controller: appProvider,
            child: InheritedControllerScope<LayersProvider>(
              controller: appProvider.layers,
              child: MaterialApp(
                navigatorKey: appSnackBarNavigatorKey,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const MainScreen(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Lets debounced thumbnail rebuilds and notifications run out.
  Future<void> drainTimers(WidgetTester tester) async {
    await tester.pump(AppDefaults.thumbnailDebounceDuration);
    await tester.pump(_snackBarDismissWait);
  }

  testWidgets('double-tapping the split divider toggles the side panel', (WidgetTester tester) async {
    await pumpMainScreen(tester, _desktopViewSize);
    final bool expandedBefore = shellProvider.isSidePanelExpanded;

    tester
        .widget<MultiSplitView>(
          find.byWidgetPredicate((Widget widget) => widget is MultiSplitView && widget.axis == Axis.horizontal),
        )
        .onDividerDoubleTap!(0);
    await tester.pump();

    expect(shellProvider.isSidePanelExpanded, !expandedBefore);
    await drainTimers(tester);
  });

  testWidgets('dropping files skips empty paths and handles only the first real file', (
    WidgetTester tester,
  ) async {
    await pumpMainScreen(tester, _desktopViewSize);

    tester.widget<DropTarget>(find.byType(DropTarget)).onDragDone!(
      DropDoneDetails(
        files: <DropItem>[DropItemFile(''), DropItemFile(_unsupportedDropPath)],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.pump();

    expect(find.text(_unsupportedDropMessage), findsOneWidget);
    await drainTimers(tester);
  });

  testWidgets('on phones, tapping the dimmed backdrop closes the menu overlay', (WidgetTester tester) async {
    shellProvider.showMenu = true;
    await pumpMainScreen(tester, _phoneViewSize);
    expect(find.byType(SidePanel), findsOneWidget);

    await tester.tapAt(_phoneOverlayTapPoint);
    await tester.pump();

    expect(shellProvider.showMenu, isFalse);
    expect(find.byType(SidePanel), findsNothing);
    await drainTimers(tester);
  });
}
