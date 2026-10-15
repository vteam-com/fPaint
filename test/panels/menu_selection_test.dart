import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/menu_model.dart';
import 'package:fpaint/pages/settings_page.dart';
import 'package:fpaint/panels/side_panel/menu.dart';
import 'package:fpaint/panels/side_panel/recent_files_dialog.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/shortcuts_help.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_harness.dart';

const String _savedFileName = 'menu_save_test.png';
const String _tempDirPrefix = 'fpaint_menu_save_';
const Duration _realSavePollStep = Duration(milliseconds: 50);
const int _realSaveMaxPolls = 100;
const Duration _snackBarDismissWait = Duration(seconds: 5);

void main() {
  late AppPreferences preferences;
  late AppProvider appProvider;
  late ShellProvider shellProvider;
  late BuildContext menuContext;
  late AppLocalizations l10n;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    shellProvider = ShellProvider();
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<void> pumpHarness(WidgetTester tester) {
    return tester.pumpWidget(
      InheritedControllerScope<AppPreferences>(
        controller: preferences,
        child: InheritedControllerScope<AppProvider>(
          controller: appProvider,
          child: InheritedControllerScope<LayersProvider>(
            controller: appProvider.layers,
            child: InheritedControllerScope<ShellProvider>(
              controller: shellProvider,
              child: buildLocalizedScaffoldTestApp(
                bodyBuilder: (BuildContext context) {
                  menuContext = context;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Selects [menuId], letting any clipboard probe run into its timeout (the
  /// test host has no clipboard plugin) before the UI settles.
  Future<void> select(WidgetTester tester, int menuId) async {
    onDropDownMenuSelection(menuContext, menuId);
    await tester.pump();
    await tester.pump(AppDefaults.clipboardAccessTimeout);
    await tester.pumpAndSettle();
  }

  Future<void> popTopRoute(WidgetTester tester) async {
    Navigator.of(menuContext).pop();
    await tester.pumpAndSettle();
  }

  testWidgets('New opens the canvas size dialog', (WidgetTester tester) async {
    await pumpHarness(tester);

    await select(tester, MenuIds.newFile);
    expect(find.text(l10n.newCanvasSize), findsOneWidget);

    await popTopRoute(tester);
    expect(find.text(l10n.newCanvasSize), findsNothing);
  });

  testWidgets('Open shows the import sheet', (WidgetTester tester) async {
    await pumpHarness(tester);

    await select(tester, MenuIds.openFile);
    expect(find.byType(ImportDialog), findsOneWidget);

    await popTopRoute(tester);
  });

  testWidgets('New from clipboard with an empty clipboard leaves the document alone', (WidgetTester tester) async {
    await pumpHarness(tester);
    final LayerProvider layerBefore = appProvider.layers.selectedLayer;

    await select(tester, MenuIds.newFromClipboard);

    expect(appProvider.layers.selectedLayer, same(layerBefore));
  });

  testWidgets('Image size, keyboard shortcuts and About open their dialogs', (WidgetTester tester) async {
    await pumpHarness(tester);

    await select(tester, MenuIds.imageSize);
    expect(find.text(l10n.imageSizeTitle), findsWidgets);
    await popTopRoute(tester);

    await select(tester, MenuIds.keyboardShortcuts);
    expect(find.byType(ShortcutsHelpDialog), findsOneWidget);
    await popTopRoute(tester);

    await select(tester, MenuIds.about);
    expect(find.text(l10n.flutterAttribution), findsOneWidget);
    await popTopRoute(tester);
  });

  testWidgets('Settings in an embedded host pushes the page with the editor scopes', (WidgetTester tester) async {
    shellProvider.isEmbedded = true;
    await pumpHarness(tester);

    await select(tester, MenuIds.settings);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(
      InheritedControllerScope.maybeOf<AppProvider>(tester.element(find.byType(SettingsPage)), listen: false),
      same(appProvider),
    );

    await popTopRoute(tester);
  });

  testWidgets('Save writes the loaded document in place', (WidgetTester tester) async {
    final Directory tempDir = Directory.systemTemp.createTempSync(_tempDirPrefix);
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final String filePath = '${tempDir.path}/$_savedFileName';
    shellProvider.loadedFileName = filePath;
    await pumpHarness(tester);

    await tester.runAsync(() async {
      onDropDownMenuSelection(menuContext, MenuIds.save);
      for (int poll = 0; poll < _realSaveMaxPolls && !File(filePath).existsSync(); poll++) {
        await Future<void>.delayed(_realSavePollStep);
      }
    });
    await tester.pump();

    expect(File(filePath).existsSync(), isTrue);
    await tester.pump(_snackBarDismissWait);
  });
}
