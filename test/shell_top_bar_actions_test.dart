import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/panels/side_panel/recent_files_dialog.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/shell_top_bar.dart';
import 'package:fpaint/widgets/app_bottom_sheet.dart';
import 'package:fpaint/widgets/app_tooltip.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/widget_test_harness.dart';

const Size _roomyViewSize = Size(1400, 600);

void main() {
  late AppPreferences preferences;
  late AppProvider appProvider;
  late ShellProvider shellProvider;
  late AppLocalizations l10n;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    shellProvider = ShellProvider();
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<void> pumpTopBar(WidgetTester tester) async {
    tester.view.physicalSize = _roomyViewSize;
    tester.view.devicePixelRatio = AppMath.one.toDouble();
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      InheritedControllerScope<AppPreferences>(
        controller: preferences,
        child: InheritedControllerScope<ShellProvider>(
          controller: shellProvider,
          child: InheritedControllerScope<AppProvider>(
            controller: appProvider,
            child: InheritedControllerScope<LayersProvider>(
              controller: appProvider.layers,
              child: buildLocalizedScaffoldTestApp(
                bodyBuilder: (BuildContext _) => Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: AppLayout.shellTopBarHeight,
                    child: ShellTopBar(appProvider: appProvider, shellProvider: shellProvider),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder tooltipButton(String message) {
    return find.byWidgetPredicate((Widget widget) => widget is AppTooltip && widget.message == message);
  }

  /// Lets a clipboard probe run into its timeout (the test host has no
  /// clipboard plugin), then settles any route it opened.
  Future<void> settleClipboardProbe(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(AppDefaults.clipboardAccessTimeout);
    await tester.pumpAndSettle();
  }

  testWidgets('Start new opens the canvas size dialog', (WidgetTester tester) async {
    await pumpTopBar(tester);

    await tester.tap(tooltipButton(l10n.startOverTooltip));
    await settleClipboardProbe(tester);

    expect(find.text(l10n.newCanvasSize), findsOneWidget);
  });

  testWidgets('Import opens the import sheet', (WidgetTester tester) async {
    await pumpTopBar(tester);

    await tester.tap(tooltipButton(l10n.importTooltip));
    await settleClipboardProbe(tester);

    expect(find.byType(ImportDialog), findsOneWidget);
  });

  testWidgets('Export opens the share sheet', (WidgetTester tester) async {
    await pumpTopBar(tester);

    await tester.tap(find.byKey(Keys.sidePanelExportButton));
    await tester.pumpAndSettle();

    expect(find.byType(AppBottomSheetContent), findsOneWidget);
  });

  testWidgets('Paste with an empty clipboard leaves the canvas untouched', (WidgetTester tester) async {
    await pumpTopBar(tester);

    await tester.tap(find.byKey(Keys.floatActionPaste));
    await settleClipboardProbe(tester);

    expect(appProvider.transformModel.isVisible, isFalse);
  });

  testWidgets('small-device menu toggle reveals a hidden shell, then toggles the menu', (
    WidgetTester tester,
  ) async {
    shellProvider.deviceSizeSmall = true;
    shellProvider.shellMode = ShellMode.hidden;
    await pumpTopBar(tester);

    await tester.tap(find.byKey(Keys.floatActionMenuToggle));
    await tester.pump();
    expect(shellProvider.shellMode, ShellMode.full);
    expect(shellProvider.showMenu, isTrue);

    await tester.tap(find.byKey(Keys.floatActionMenuToggle));
    await tester.pump();
    expect(shellProvider.showMenu, isFalse);
  });

  testWidgets('the ShellTopBar widget preview builds inside a shell scope', (WidgetTester tester) async {
    // The preview creates its own providers but its MainMenu still resolves
    // ShellProvider from the tree, so the preview only builds inside a scope.
    await tester.pumpWidget(
      InheritedControllerScope<ShellProvider>(
        controller: shellProvider,
        child: buildLocalizedScaffoldTestApp(bodyBuilder: (BuildContext _) => shellTopBarPreview()),
      ),
    );

    expect(find.byType(ShellTopBar), findsOneWidget);
  });
}
