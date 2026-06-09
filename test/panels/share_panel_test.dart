import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/panels/side_panel/menu.dart';
import 'package:fpaint/panels/side_panel/share_panel.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _exportPanelTransitionPumpCount = 4;
const Duration _exportPanelTransitionPumpDuration = Duration(milliseconds: 50);
const String _loadedImagePath = '/tmp/examples/reference-image.png';

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

  Widget buildHarness() {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppPreferences>.value(value: preferences),
        ChangeNotifierProvider<LayersProvider>.value(value: appProvider.layers),
        ChangeNotifierProvider<ShellProvider>.value(value: shellProvider),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: MainMenu(),
          ),
        ),
      ),
    );
  }

  Future<void> pumpExportPanelTransition(final WidgetTester tester) async {
    for (int index = 0; index < _exportPanelTransitionPumpCount; index++) {
      await tester.pump(_exportPanelTransitionPumpDuration);
    }
  }

  Future<void> openExportPanel(final WidgetTester tester) async {
    await tester.tap(find.byKey(Keys.mainMenuButton));
    await pumpExportPanelTransition(tester);

    final BuildContext context = tester.element(find.byType(MainMenu));
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    await tester.tap(find.text(l10n.exportLabel));
    await pumpExportPanelTransition(tester);
  }

  group('sharePanel', () {
    testWidgets('shows the loaded image path at the top when one is available', (final WidgetTester tester) async {
      shellProvider.loadedFileName = _loadedImagePath;

      await tester.pumpWidget(buildHarness());
      await tester.pump();

      await openExportPanel(tester);

      final Finder bottomSheet = find.byType(AppBottomSheetContent);
      expect(bottomSheet, findsOneWidget);
      expect(
        find.descendant(of: bottomSheet, matching: find.text(_loadedImagePath)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: bottomSheet,
          matching: find.byWidgetPredicate(
            (final Widget widget) => widget is AppSvgIcon && widget.icon == AppIcon.image,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('omits the loaded image path header when no file is loaded', (final WidgetTester tester) async {
      await tester.pumpWidget(buildHarness());
      await tester.pump();

      await openExportPanel(tester);

      final Finder bottomSheet = find.byType(AppBottomSheetContent);
      expect(bottomSheet, findsOneWidget);
      expect(
        find.descendant(of: bottomSheet, matching: find.text(_loadedImagePath)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: bottomSheet,
          matching: find.byWidgetPredicate(
            (final Widget widget) => widget is AppSvgIcon && widget.icon == AppIcon.image,
          ),
        ),
        findsNothing,
      );
    });

    late AppLocalizations l10n;

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('textAction returns an AppText widget', () {
      final Widget widget = textAction('image.PNG', l10n);
      expect(widget, isA<AppText>());
    });

    test('textAction contains the file name', () {
      final AppText widget = textAction('image.PNG', l10n) as AppText;
      expect(widget.data, contains('image.PNG'));
    });

    test('textAction contains the file name for JPG', () {
      final AppText widget = textAction('image.JPG', l10n) as AppText;
      expect(widget.data, contains('image.JPG'));
    });

    test('textAction contains the file name for ORA', () {
      final AppText widget = textAction('image.ORA', l10n) as AppText;
      expect(widget.data, contains('image.ORA'));
    });
  });
}
