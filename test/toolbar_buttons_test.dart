import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/shell_top_bar.dart';
import 'package:fpaint/widgets/app_buttons.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/app_tooltip.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _testImageDimension = 12;
const double _narrowToolbarWidth = 170.0;
const double _wideToolbarWidth = 720.0;
const double _selectionOverflowToolbarWidth = 627.0;
const double _wideToolbarDistributedGapLowerBound = AppLayout.toolbarButtonSize + AppSpacing.large;
const double _wideToolbarPrimaryGroupGapLowerBound = AppSpacing.large;
const double _wideToolbarHistorySelectorGroupGapLowerBound = AppSpacing.large;

Future<ui.Image> _createTestImage() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, _testImageDimension.toDouble(), _testImageDimension.toDouble()),
    ui.Paint()..color = const Color(0xFF000000),
  );
  return recorder.endRecording().toImage(_testImageDimension, _testImageDimension);
}

void main() {
  late AppProvider appProvider;
  late ShellProvider shellProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppPreferences preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    appProvider.undoProvider.clear();
    shellProvider = ShellProvider();
  });

  Widget buildTestWidget({required final Widget child}) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Localizations(
          locale: const Locale('en'),
          delegates: AppLocalizations.localizationsDelegates,
          child: child,
        ),
      ),
    );
  }

  Element? findOverlaySurfaceAncestor(final WidgetTester tester, final Finder finder) {
    if (finder.evaluate().isEmpty) {
      return null;
    }

    final Element element = tester.element(finder);
    Element? matchingAncestor;

    element.visitAncestorElements((final Element ancestor) {
      final Widget widget = ancestor.widget;
      if (widget is DecoratedBox) {
        final Decoration decoration = widget.decoration;
        if (decoration is BoxDecoration && decoration.borderRadius != null && decoration.boxShadow != null) {
          matchingAncestor = ancestor;
          return false;
        }
      }
      return true;
    });

    return matchingAncestor;
  }

  Widget fabUnderTest() {
    return Builder(
      builder: (final BuildContext context) {
        return buildCanvasToolbarActions(context, shellProvider, appProvider);
      },
    );
  }

  Widget shellTopBarUnderTest({required final double width}) {
    return ChangeNotifierProvider<ShellProvider>.value(
      value: shellProvider,
      child: ChangeNotifierProvider<AppProvider>.value(
        value: appProvider,
        child: SizedBox(
          width: width,
          child: ShellTopBar(
            appProvider: appProvider,
            shellProvider: shellProvider,
          ),
        ),
      ),
    );
  }

  Future<void> pumpFloatingButtons(
    final WidgetTester tester, {
    final bool? isSmall,
    final bool? showMenu,
  }) async {
    if (isSmall != null) {
      shellProvider.deviceSizeSmall = isSmall;
    }
    if (showMenu != null) {
      shellProvider.showMenu = showMenu;
    }

    await tester.pumpWidget(
      buildTestWidget(
        child: fabUnderTest(),
      ),
    );
    await tester.pump();
  }

  Future<void> pumpShellTopBar(
    final WidgetTester tester, {
    required final double width,
    final bool? isSmall,
    final bool? showMenu,
  }) async {
    if (isSmall != null) {
      shellProvider.deviceSizeSmall = isSmall;
    }
    if (showMenu != null) {
      shellProvider.showMenu = showMenu;
    }

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(size: Size(width, AppLayout.toolbarButtonSize)),
          child: Localizations(
            locale: const Locale('en'),
            delegates: AppLocalizations.localizationsDelegates,
            child: shellTopBarUnderTest(width: width),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('buildCanvasToolbarActions - toolbar layout', () {
    testWidgets('renders undo button dimmed when undo is unavailable', (final WidgetTester tester) async {
      await pumpFloatingButtons(tester, isSmall: false);

      expect(find.byKey(Keys.floatActionUndo), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(Keys.floatActionUndo),
          matching: find.byWidgetPredicate(
            (final Widget widget) => widget is Opacity && widget.opacity == AppVisual.disabled,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders undo button when undo is available', (final WidgetTester tester) async {
      appProvider.undoProvider.executeAction(
        name: 'undo-test',
        forward: () {},
        backward: () {},
      );

      await pumpFloatingButtons(tester, isSmall: false);

      expect(find.byKey(Keys.floatActionUndo), findsOneWidget);
    });

    testWidgets('renders redo button dimmed when redo is unavailable', (final WidgetTester tester) async {
      await pumpFloatingButtons(tester, isSmall: false);

      expect(find.byKey(Keys.floatActionRedo), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(Keys.floatActionRedo),
          matching: find.byWidgetPredicate(
            (final Widget widget) => widget is Opacity && widget.opacity == AppVisual.disabled,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders redo button when redo is available', (final WidgetTester tester) async {
      appProvider.undoProvider.executeAction(
        name: 'redo-test',
        forward: () {},
        backward: () {},
      );
      appProvider.undoProvider.undo();

      await pumpFloatingButtons(tester, isSmall: false);

      expect(find.byKey(Keys.floatActionUndo), findsOneWidget);
      expect(find.byKey(Keys.floatActionRedo), findsOneWidget);
    });

    testWidgets('renders selector button with correct key', (final WidgetTester tester) async {
      await pumpFloatingButtons(tester, isSmall: false);

      expect(find.byKey(Keys.floatActionSelector), findsOneWidget);
    });

    testWidgets('renders paste button with correct key on the top toolbar', (final WidgetTester tester) async {
      await pumpShellTopBar(
        tester,
        width: _wideToolbarWidth,
        isSmall: false,
        showMenu: false,
      );

      expect(find.byKey(Keys.floatActionPaste), findsOneWidget);
    });

    testWidgets('shows paste shortcut inside the paste tooltip', (final WidgetTester tester) async {
      await pumpShellTopBar(
        tester,
        width: _wideToolbarWidth,
        isSmall: false,
        showMenu: false,
      );

      final Finder pasteTooltip = find.descendant(
        of: find.byKey(Keys.floatActionPaste),
        matching: find.byType(AppTooltip),
      );

      expect(pasteTooltip, findsOneWidget);
      expect(tester.widget<AppTooltip>(pasteTooltip).message, 'Paste (Ctrl V)');
    });

    testWidgets('shows shortcut inside undo tooltip when undo is available', (final WidgetTester tester) async {
      appProvider.undoProvider.executeAction(
        name: 'undo-shortcut-check',
        forward: () {},
        backward: () {},
      );

      await pumpShellTopBar(
        tester,
        width: _wideToolbarWidth,
        isSmall: false,
        showMenu: false,
      );

      final Finder undoTooltip = find.descendant(
        of: find.byKey(Keys.floatActionUndo),
        matching: find.byType(AppTooltip),
      );

      expect(undoTooltip, findsOneWidget);
      expect(tester.widget<AppTooltip>(undoTooltip).message, contains('(Ctrl Z)'));
    });

    testWidgets('shows selector key inside selector tooltip when selector is inactive', (
      final WidgetTester tester,
    ) async {
      appProvider.selectedAction = ActionType.brush;
      appProvider.selectorModel.isVisible = false;

      await pumpShellTopBar(
        tester,
        width: _wideToolbarWidth,
        isSmall: false,
        showMenu: false,
      );

      final Finder selectorTooltip = find.descendant(
        of: find.byKey(Keys.floatActionSelector),
        matching: find.byType(AppTooltip),
      );

      expect(selectorTooltip, findsOneWidget);
      expect(tester.widget<AppTooltip>(selectorTooltip).message, contains('(S)'));
    });

    testWidgets('renders zoom in button with correct key', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(Keys.floatActionZoomIn), findsOneWidget);
    });

    testWidgets('renders zoom out button with correct key', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(Keys.floatActionZoomOut), findsOneWidget);
    });

    testWidgets('shows zoom-group tooltips', (final WidgetTester tester) async {
      await pumpShellTopBar(
        tester,
        width: _wideToolbarWidth,
        isSmall: false,
        showMenu: false,
      );

      final Finder zoomInTooltip = find.descendant(
        of: find.byKey(Keys.floatActionZoomIn),
        matching: find.byType(AppTooltip),
      );
      final Finder zoomOutTooltip = find.descendant(
        of: find.byKey(Keys.floatActionZoomOut),
        matching: find.byType(AppTooltip),
      );
      final Finder resetZoomTooltip = find.descendant(
        of: find.byKey(Keys.floatActionCenter),
        matching: find.byType(AppTooltip),
      );

      expect(zoomInTooltip, findsOneWidget);
      expect(zoomOutTooltip, findsOneWidget);
      expect(resetZoomTooltip, findsOneWidget);
      expect(tester.widget<AppTooltip>(zoomInTooltip).message, 'Zoom In (Ctrl +)');
      expect(tester.widget<AppTooltip>(zoomOutTooltip).message, 'Zoom Out (Ctrl -)');
      expect(
        tester.widget<AppTooltip>(resetZoomTooltip).message,
        'Reset Zoom (Ctrl 0)\n100%\n1024\n768',
      );
    });

    testWidgets('renders center button with correct key', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(Keys.floatActionCenter), findsOneWidget);
    });

    testWidgets('does not render desktop shell toggle button in canvas toolbar', (
      final WidgetTester tester,
    ) async {
      shellProvider.deviceSizeSmall = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(Keys.floatActionToggle), findsNothing);
    });

    testWidgets('center button displays only zoom percentage', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      // Scale is 1.0 (100%), and the center button now only shows percentage.
      final Finder centerButtonText = find.descendant(
        of: find.byKey(Keys.floatActionCenter),
        matching: find.byType(Text),
      );
      expect(centerButtonText, findsOneWidget);
      expect(tester.widget<Text>(centerButtonText).data, '100%');
      expect(find.text('1024'), findsNothing);
      expect(find.text('768'), findsNothing);
    });

    testWidgets('selector button enables selector mode on tap', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = false;
      appProvider.selectedAction = ActionType.brush;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(Keys.floatActionSelector));
      await tester.pump();

      expect(appProvider.selectedAction, ActionType.selector);
    });

    testWidgets('selector cancel tap restores previous tool when selector is active without marquee', (
      final WidgetTester tester,
    ) async {
      shellProvider.deviceSizeSmall = false;
      appProvider.selectedAction = ActionType.pencil;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(Keys.floatActionSelector));
      await tester.pump();
      expect(appProvider.selectedAction, ActionType.selector);
      expect(appProvider.selectorModel.isVisible, isFalse);

      await tester.tap(find.byKey(Keys.floatActionSelector));
      await tester.pump();

      expect(appProvider.selectedAction, ActionType.pencil);
      expect(appProvider.selectorModel.isVisible, isFalse);
    });

    testWidgets('selector button clears active selection without changing active tool', (
      final WidgetTester tester,
    ) async {
      shellProvider.deviceSizeSmall = false;
      appProvider.selectedAction = ActionType.pencil;
      appProvider.selectorModel.isVisible = true;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(Keys.floatActionSelector));
      await tester.pump();

      expect(appProvider.selectedAction, ActionType.pencil);
      expect(appProvider.selectorModel.isVisible, isFalse);
    });

    testWidgets('selector button switches icon based on active selection', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      AppSvgIcon selectorIcon = tester.widget<AppSvgIcon>(
        find.descendant(
          of: find.byKey(Keys.floatActionSelector),
          matching: find.byType(AppSvgIcon),
        ),
      );
      expect(selectorIcon.icon, AppIcon.selector);

      appProvider.selectorModel.isVisible = true;
      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      selectorIcon = tester.widget<AppSvgIcon>(
        find.descendant(
          of: find.byKey(Keys.floatActionSelector),
          matching: find.byType(AppSvgIcon),
        ),
      );
      expect(selectorIcon.icon, AppIcon.selectorCancel);
    });

    testWidgets('undo and redo are positioned left of selector in toolbar layout', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = false;
      appProvider.undoProvider.executeAction(
        name: 'desktop-order-test-a',
        forward: () {},
        backward: () {},
      );
      appProvider.undoProvider.executeAction(
        name: 'desktop-order-test-b',
        forward: () {},
        backward: () {},
      );
      appProvider.undoProvider.undo();

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      final Finder undoFinder = find.byKey(Keys.floatActionUndo);
      final Finder redoFinder = find.byKey(Keys.floatActionRedo);
      final Finder selectorFinder = find.byKey(Keys.floatActionSelector);

      expect(undoFinder, findsOneWidget);
      expect(redoFinder, findsOneWidget);
      expect(selectorFinder, findsOneWidget);

      final double undoX = tester.getCenter(undoFinder).dx;
      final double redoX = tester.getCenter(redoFinder).dx;
      final double selectorX = tester.getCenter(selectorFinder).dx;

      expect(undoX, lessThan(selectorX));
      expect(redoX, lessThan(selectorX));
    });

    testWidgets('zoom in changes canvas placement to manual', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = false;
      shellProvider.canvasPlacement = CanvasAutoPlacement.fit;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(Keys.floatActionZoomIn));
      await tester.pump();

      expect(shellProvider.canvasPlacement, CanvasAutoPlacement.manual);
    });

    testWidgets('zoom out changes canvas placement to manual', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = false;
      shellProvider.canvasPlacement = CanvasAutoPlacement.fit;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(Keys.floatActionZoomOut));
      await tester.pump();

      expect(shellProvider.canvasPlacement, CanvasAutoPlacement.manual);
    });

    testWidgets('center button resets canvas placement to fit', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = false;
      shellProvider.canvasPlacement = CanvasAutoPlacement.manual;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(Keys.floatActionCenter));
      await tester.pump();
      // The center button schedules a delayed update (100ms) — flush it
      await tester.pump(const Duration(milliseconds: 200));

      expect(shellProvider.canvasPlacement, CanvasAutoPlacement.fit);
    });

    testWidgets('viewport repaint updates zoom readout without provider notify', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      int notifyCount = 0;
      appProvider.addListener(() {
        notifyCount++;
      });

      appProvider.applyScaleToCanvas(
        scaleDelta: 2.0,
        notifyListener: false,
        notifyViewport: true,
      );
      await tester.pump();

      final String expectedZoomPercentage = '${(appProvider.layers.scale * AppLimits.percentMax).toInt()}%';
      final Finder centerButtonText = find.descendant(
        of: find.byKey(Keys.floatActionCenter),
        matching: find.byType(Text),
      );

      expect(notifyCount, 0);
      expect(centerButtonText, findsOneWidget);
      expect(tester.widget<Text>(centerButtonText).data, expectedZoomPercentage);
    });
  });

  group('buildCanvasToolbarActions - small-screen layout', () {
    testWidgets('renders Row layout when deviceSizeSmall is true', (final WidgetTester tester) async {
      await pumpFloatingButtons(tester, isSmall: true, showMenu: false);

      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('shows undo and redo dimmed without history', (final WidgetTester tester) async {
      await pumpFloatingButtons(tester, isSmall: true, showMenu: false);

      expect(find.byKey(Keys.floatActionUndo), findsOneWidget);
      expect(find.byKey(Keys.floatActionRedo), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(Keys.floatActionUndo),
          matching: find.byWidgetPredicate(
            (final Widget widget) => widget is Opacity && widget.opacity == AppVisual.disabled,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(Keys.floatActionRedo),
          matching: find.byWidgetPredicate(
            (final Widget widget) => widget is Opacity && widget.opacity == AppVisual.disabled,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows selector button on small screens', (final WidgetTester tester) async {
      await pumpFloatingButtons(tester, isSmall: true, showMenu: false);

      expect(find.byKey(Keys.floatActionSelector), findsOneWidget);
    });

    testWidgets('shows shell toggle button on small screens', (final WidgetTester tester) async {
      await pumpFloatingButtons(tester, isSmall: true, showMenu: false);

      expect(find.byKey(Keys.floatActionToggle), findsOneWidget);
    });

    testWidgets('small-screen shell toggle hides shell on tap', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = true;
      shellProvider.shellMode = ShellMode.full;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(Keys.floatActionToggle));
      await tester.pump();

      expect(shellProvider.shellMode, ShellMode.hidden);
    });

    testWidgets('small-screen shell toggle restores shell when it is hidden', (
      final WidgetTester tester,
    ) async {
      shellProvider.deviceSizeSmall = true;
      shellProvider.shellMode = ShellMode.hidden;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(Keys.floatActionToggle));
      await tester.pump();

      expect(shellProvider.shellMode, ShellMode.full);
    });

    testWidgets('selector button enables selector mode and clears active selection on small screens', (
      final WidgetTester tester,
    ) async {
      shellProvider.deviceSizeSmall = true;
      appProvider.selectedAction = ActionType.brush;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(Keys.floatActionSelector));
      await tester.pump();
      expect(appProvider.selectedAction, ActionType.selector);

      appProvider.selectedAction = ActionType.pencil;
      appProvider.selectorModel.isVisible = true;
      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(Keys.floatActionSelector));
      await tester.pump();
      expect(appProvider.selectedAction, ActionType.pencil);
      expect(appProvider.selectorModel.isVisible, isFalse);
    });

    testWidgets('shows undo and redo with history on small screens', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = true;
      appProvider.undoProvider.executeAction(
        name: 'mobile-redo-test',
        forward: () {},
        backward: () {},
      );
      appProvider.undoProvider.undo();

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(Keys.floatActionUndo), findsOneWidget);
      expect(find.byKey(Keys.floatActionRedo), findsOneWidget);
    });

    testWidgets('undo and redo stay left of selector on small screens', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = true;
      appProvider.undoProvider.executeAction(
        name: 'mobile-order-test-a',
        forward: () {},
        backward: () {},
      );
      appProvider.undoProvider.executeAction(
        name: 'mobile-order-test-b',
        forward: () {},
        backward: () {},
      );
      appProvider.undoProvider.undo();

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return buildCanvasToolbarActions(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      final Finder undoFinder = find.byKey(Keys.floatActionUndo);
      final Finder redoFinder = find.byKey(Keys.floatActionRedo);
      final Finder selectorFinder = find.byKey(Keys.floatActionSelector);

      expect(undoFinder, findsOneWidget);
      expect(redoFinder, findsOneWidget);
      expect(selectorFinder, findsOneWidget);

      final double undoX = tester.getCenter(undoFinder).dx;
      final double redoX = tester.getCenter(redoFinder).dx;
      final double selectorX = tester.getCenter(selectorFinder).dx;

      expect(undoX, lessThan(selectorX));
      expect(redoX, lessThan(selectorX));
    });
  });

  group('ShellTopBar - responsive width', () {
    testWidgets('keeps first last and important actions when width is narrow', (final WidgetTester tester) async {
      await pumpShellTopBar(
        tester,
        width: _narrowToolbarWidth,
        isSmall: true,
        showMenu: false,
      );

      expect(find.byKey(Keys.floatActionMenuToggle), findsOneWidget);
      expect(find.byKey(Keys.floatActionToggle), findsNothing);
      expect(find.byKey(Keys.mainMenuButton), findsOneWidget);
      expect(find.byKey(Keys.floatActionUndo), findsOneWidget);
      expect(find.byKey(Keys.floatActionPaste), findsNothing);
      expect(find.byKey(Keys.floatActionSelector), findsOneWidget);
      expect(find.byKey(Keys.sidePanelExportButton), findsNothing);
    });

    testWidgets('restores lower-priority actions on wider desktop widths', (final WidgetTester tester) async {
      await pumpShellTopBar(
        tester,
        width: _wideToolbarWidth,
        isSmall: false,
        showMenu: false,
      );

      expect(find.byKey(Keys.floatActionToggle), findsOneWidget);
      expect(find.byKey(Keys.mainMenuButton), findsOneWidget);
      expect(find.byKey(Keys.floatActionRedo), findsOneWidget);
      expect(find.byKey(Keys.floatActionPaste), findsOneWidget);
      expect(find.byKey(Keys.sidePanelExportButton), findsOneWidget);
      expect(find.byKey(Keys.floatActionZoomOut), findsOneWidget);

      final Finder flipVerticalIconFinder = find.byWidgetPredicate(
        (final Widget widget) => widget is AppSvgIcon && widget.icon == AppIcon.flipVertical,
      );
      final Finder exportIconFinder = find.byKey(Keys.sidePanelExportButton);
      final Finder rotateIconFinder = find.byWidgetPredicate(
        (final Widget widget) => widget is AppSvgIcon && widget.icon == AppIcon.rotate90DegreesCw,
      );
      final double redoX = tester.getCenter(find.byKey(Keys.floatActionRedo)).dx;
      final double selectorX = tester.getCenter(find.byKey(Keys.floatActionSelector)).dx;
      final double flipVerticalX = tester.getCenter(flipVerticalIconFinder).dx;
      final double undoX = tester.getCenter(find.byKey(Keys.floatActionUndo)).dx;
      final double exportX = tester.getCenter(exportIconFinder).dx;
      final double pasteX = tester.getCenter(find.byKey(Keys.floatActionPaste)).dx;
      final double rotateX = tester.getCenter(rotateIconFinder).dx;

      expect(flipVerticalIconFinder, findsOneWidget);
      expect(rotateIconFinder, findsOneWidget);
      expect(undoX - flipVerticalX, greaterThan(_wideToolbarDistributedGapLowerBound));
      expect(pasteX, greaterThan(exportX));
      expect(rotateX, greaterThan(pasteX));
      expect(rotateX - exportX, greaterThan(_wideToolbarPrimaryGroupGapLowerBound));
      expect(selectorX - redoX, greaterThan(_wideToolbarHistorySelectorGroupGapLowerBound));
    });

    testWidgets('shows Tab shortcut inside desktop top-left chevron tooltip', (final WidgetTester tester) async {
      await pumpShellTopBar(
        tester,
        width: _wideToolbarWidth,
        isSmall: false,
        showMenu: false,
      );

      final Finder shellToggleTooltip = find.descendant(
        of: find.byKey(Keys.floatActionToggle),
        matching: find.byType(AppTooltip),
      );

      expect(shellToggleTooltip, findsOneWidget);
      expect(tester.widget<AppTooltip>(shellToggleTooltip).message, 'Menu (Tab)');
    });

    testWidgets('keeps zoom controls grouped when selection mode activates the responsive toolbar', (
      final WidgetTester tester,
    ) async {
      await pumpShellTopBar(
        tester,
        width: _wideToolbarWidth,
        isSmall: false,
        showMenu: false,
      );

      await tester.tap(find.byKey(Keys.floatActionSelector));
      await tester.pump();

      final Element? selectionSurface = findOverlaySurfaceAncestor(
        tester,
        find.byKey(Keys.toolSelectorModeRectangle),
      );
      final Element? zoomOutSurface = findOverlaySurfaceAncestor(
        tester,
        find.byKey(Keys.floatActionZoomOut),
      );
      final Element? centerSurface = findOverlaySurfaceAncestor(
        tester,
        find.byKey(Keys.floatActionCenter),
      );
      final Element? zoomInSurface = findOverlaySurfaceAncestor(
        tester,
        find.byKey(Keys.floatActionZoomIn),
      );

      expect(selectionSurface, isNotNull);
      expect(zoomOutSurface, isNotNull);
      expect(centerSurface, same(zoomOutSurface));
      expect(zoomInSurface, same(zoomOutSurface));
      expect(selectionSurface, isNot(same(zoomOutSurface)));
    });

    testWidgets('keeps the visible selection domain horizontally scrollable without overflowing', (
      final WidgetTester tester,
    ) async {
      appProvider.selectedAction = ActionType.selector;
      appProvider.selectorModel.isVisible = true;

      await pumpShellTopBar(
        tester,
        width: _selectionOverflowToolbarWidth,
        isSmall: false,
        showMenu: false,
      );

      final Finder selectionScrollView = find.ancestor(
        of: find.byKey(Keys.toolSelectorModeRectangle),
        matching: find.byType(SingleChildScrollView),
      );

      expect(selectionScrollView, findsOneWidget);
      expect(
        find.ancestor(
          of: selectionScrollView,
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(find.byKey(Keys.floatActionCenter), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  Widget buildFloatingIconButtonForTest({
    final Key? key,
    final AppIcon? icon,
    final Color foregroundColor = AppColors.white,
    final String? tooltip,
    required final VoidCallback onPressed,
    final Widget? child,
  }) {
    return AppButton(
      key: key,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: AppLayout.toolbarButtonSize,
        height: AppLayout.toolbarButtonSize,
      ),
      onPressed: () {
        Future<void>.microtask(onPressed);
      },
      child: SizedBox(
        width: AppLayout.toolbarButtonSize,
        height: AppLayout.toolbarButtonSize,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.floatingButtonBackground,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: child ?? AppSvgIcon(icon: icon!, color: foregroundColor),
          ),
        ),
      ),
    );
  }

  group('floating action AppButtonIcon', () {
    testWidgets('keeps floating controls visible while transform overlay is active', (
      final WidgetTester tester,
    ) async {
      final ui.Image image = await _createTestImage();
      addTearDown(image.dispose);
      appProvider.transformModel.start(
        image: image,
        bounds: Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        ),
      );

      await pumpFloatingButtons(tester, isSmall: false);

      expect(find.byKey(Keys.floatActionSelector), findsOneWidget);
      expect(find.byKey(Keys.floatActionZoomIn), findsOneWidget);
      expect(find.byKey(Keys.floatActionToggle), findsNothing);
    });
    testWidgets('renders with icon', (final WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: buildFloatingIconButtonForTest(
            icon: AppIcon.undo,
            onPressed: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('renders with custom child widget', (final WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: buildFloatingIconButtonForTest(
            onPressed: () {},
            child: const Text('Test'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('calls onPressed callback when tapped', (final WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        buildTestWidget(
          child: buildFloatingIconButtonForTest(
            icon: AppIcon.redo,
            onPressed: () => pressed = true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('applies key when provided', (final WidgetTester tester) async {
      const Key testKey = Key('test-float-btn');
      await tester.pumpWidget(
        buildTestWidget(
          child: buildFloatingIconButtonForTest(
            key: testKey,
            icon: AppIcon.zoomIn,
            onPressed: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(testKey), findsOneWidget);
    });

    testWidgets('wraps in tooltip when tooltip is provided', (final WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: buildFloatingIconButtonForTest(
            icon: AppIcon.undo,
            tooltip: 'Undo action',
            onPressed: () {},
          ),
        ),
      );
      await tester.pump();

      // With tooltip, the widget is wrapped in AppTooltip
      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('has circular decoration', (final WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: buildFloatingIconButtonForTest(
            icon: AppIcon.redo,
            onPressed: () {},
          ),
        ),
      );
      await tester.pump();

      final DecoratedBox decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final BoxDecoration decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, AppColors.floatingButtonBackground);
    });

    testWidgets('has correct button size', (final WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: buildFloatingIconButtonForTest(
            icon: AppIcon.undo,
            onPressed: () {},
          ),
        ),
      );
      await tester.pump();

      final SizedBox sizedBox = tester.widget<SizedBox>(
        find.byType(SizedBox).first,
      );
      expect(sizedBox.width, AppLayout.toolbarButtonSize);
      expect(sizedBox.height, AppLayout.toolbarButtonSize);
    });
  });
}
