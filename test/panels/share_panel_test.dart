import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/export_file_name.dart';
import 'package:fpaint/files/save.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/panels/side_panel/menu.dart';
import 'package:fpaint/panels/side_panel/share_panel.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/file_flow_harness.dart';

const int _exportPanelTransitionPumpCount = 4;
const Duration _exportPanelTransitionPumpDuration = Duration(milliseconds: 50);
const String _loadedImagePath = '/tmp/examples/reference-image.png';

const String _shareTempDirPrefix = 'fpaint_share_panel_';
const String _savedDocumentName = 'saved.png';
const String _exportedDocumentName = 'exported.png';

/// A format fPaint imports but cannot write back, so the panel exports only.
const String _unsupportedSavePath = '/tmp/examples/reference-image.psd';

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
    return InheritedControllerScope<AppPreferences>(
      controller: preferences,
      child: InheritedControllerScope<LayersProvider>(
        controller: appProvider.layers,
        child: InheritedControllerScope<ShellProvider>(
          controller: shellProvider,
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
        ),
      ),
    );
  }

  Future<void> pumpExportPanelTransition(WidgetTester tester) async {
    for (int index = 0; index < _exportPanelTransitionPumpCount; index++) {
      await tester.pump(_exportPanelTransitionPumpDuration);
    }
  }

  Future<void> openExportPanel(WidgetTester tester) async {
    await tester.tap(find.byKey(Keys.mainMenuButton));
    await pumpExportPanelTransition(tester);

    final BuildContext context = tester.element(find.byType(MainMenu));
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    await tester.tap(find.text(l10n.exportLabel));
    await pumpExportPanelTransition(tester);
  }

  group('sharePanel', () {
    testWidgets('offers Save over the loaded file, showing its full path', (WidgetTester tester) async {
      shellProvider.loadedFileName = _loadedImagePath;

      await tester.pumpWidget(buildHarness());
      await tester.pump();

      await openExportPanel(tester);

      final AppLocalizations panelL10n = AppLocalizations.of(tester.element(find.byType(MainMenu)))!;
      final Finder bottomSheet = find.byType(AppBottomSheetContent);
      expect(bottomSheet, findsOneWidget);
      expect(
        find.descendant(of: bottomSheet, matching: find.text(_loadedImagePath)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bottomSheet, matching: find.text(panelL10n.saveLabel)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: bottomSheet,
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is AppSvgIcon && widget.icon == AppIcon.checkCircle,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows the path without a Save action for an export-only format', (WidgetTester tester) async {
      shellProvider.loadedFileName = _unsupportedSavePath;

      await tester.pumpWidget(buildHarness());
      await tester.pump();

      await openExportPanel(tester);

      final AppLocalizations panelL10n = AppLocalizations.of(tester.element(find.byType(MainMenu)))!;
      final Finder bottomSheet = find.byType(AppBottomSheetContent);
      expect(
        find.descendant(of: bottomSheet, matching: find.text(_unsupportedSavePath)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bottomSheet, matching: find.text(panelL10n.saveLabel)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: bottomSheet,
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is AppSvgIcon && widget.icon == AppIcon.image,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('omits the loaded image path header when no file is loaded', (WidgetTester tester) async {
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
            (Widget widget) =>
                widget is AppSvgIcon && (widget.icon == AppIcon.image || widget.icon == AppIcon.checkCircle),
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

  group('sharePanel actions', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(_shareTempDirPrefix);
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    String pathOf(String name) => '${tempDirectory.path}${Platform.pathSeparator}$name';

    Future<AppLocalizations> openSharePanel(WidgetTester tester, FileFlowHost host) async {
      sharePanel(host.context);
      await pumpExportPanelTransition(tester);
      expect(find.byType(AppBottomSheetContent), findsOneWidget);
      return AppLocalizations.of(host.context)!;
    }

    bool sheetClosed() => find.byType(AppBottomSheetContent).evaluate().isEmpty;

    testWidgets('Save writes over the loaded file and closes the sheet', (WidgetTester tester) async {
      final FileFlowHost host = await pumpFileFlowHost(tester);
      final String savedPath = pathOf(_savedDocumentName);
      host.shell.loadedFileName = savedPath;
      host.layers.markAllChanged();

      final AppLocalizations l10n = await openSharePanel(tester, host);
      await tester.tap(find.text(l10n.saveLabel));
      await pumpRealUntil(tester, () => !host.layers.hasChanged && sheetClosed());

      expect(File(savedPath).existsSync(), isTrue);
      await drainFileFlowTimers(tester);
    });

    testWidgets('Copy to clipboard captures the canvas and closes the sheet', (WidgetTester tester) async {
      final FileFlowHost host = await pumpFileFlowHost(tester);

      final AppLocalizations l10n = await openSharePanel(tester, host);
      await tester.tap(find.text(l10n.copyToClipboard));
      await pumpRealUntil(tester, sheetClosed);

      await drainFileFlowTimers(tester);
    });

    testWidgets('an export format writes to the chosen destination', (WidgetTester tester) async {
      final String exportPath = pathOf(_exportedDocumentName);
      installFilePicker(FakeFilePicker(savePath: exportPath));
      final FileFlowHost host = await pumpFileFlowHost(tester);

      final AppLocalizations l10n = await openSharePanel(tester, host);
      await tester.tap(find.text(l10n.saveAsFile('$exportBaseFileName.${SaveFileFormat.png.displayName}')));
      await pumpRealUntil(tester, () => sheetClosed() && host.preferences.recentFiles.contains(exportPath));

      expect(File(exportPath).existsSync(), isTrue);
      await drainFileFlowTimers(tester);
    });
  });
}
