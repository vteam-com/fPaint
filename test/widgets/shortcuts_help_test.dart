import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/shortcuts_constants.dart';
import 'package:fpaint/helpers/viewport_transform_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/image_placement_layer_restore_state.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_dialog.dart';
import 'package:fpaint/widgets/app_text.dart';
import 'package:fpaint/widgets/shortcuts.dart';
import 'package:fpaint/widgets/shortcuts_help.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final bool isApplePlatform =
      defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
  // Apple platforms show the key glyphs printed on Apple keyboards; other platforms spell them out.
  final String primaryModifier = isApplePlatform ? '\u2318' : 'Ctrl';
  final String subtractModifier = isApplePlatform ? '\u2325' : 'Alt';
  // Duplicate-on-drag uses Option on Apple platforms but Control elsewhere.
  final String duplicateDragModifier = isApplePlatform ? '\u2325' : 'Ctrl';
  final String shiftModifier = isApplePlatform ? '\u21E7' : 'Shift';
  final String controlModifier = isApplePlatform ? '\u2303' : 'Ctrl';

  /// Returns the trailing key-cap labels on the row whose description is
  /// [description], using the [index]th row when a description repeats.
  /// [skipFirst] drops the leading match when the description also names the
  /// dialog title.
  List<String> capsForRow(
    WidgetTester tester,
    String description, {
    int index = 0,
    bool skipFirst = false,
  }) {
    final Finder descriptions = find.text(description);
    final int target = skipFirst ? index + 1 : index;
    // The row's own key Wrap is the innermost ancestor; the outermost is the
    // Wrap laying out the whole dialog.
    final Finder rowWrap = find
        .ancestor(
          of: descriptions.at(target),
          matching: find.byType(Row),
        )
        .first;
    final Finder keyWrap = find.descendant(of: rowWrap, matching: find.byType(Wrap)).first;
    return tester
        .widgetList<AppText>(
          find.descendant(of: keyWrap, matching: find.byType(AppText)),
        )
        .map((AppText text) => text.data)
        .where((String data) => data != description)
        .toList();
  }

  const String duplicateSameLayerDescription = 'Duplicate in Same Layer';
  const String duplicateNewLayerDescription = 'Duplicate on New Layer';

  LogicalKeyboardKey duplicateShortcutModifierKey() {
    return isApplePlatform ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft;
  }

  Widget buildTestWidget({Size size = const Size(1200, 900)}) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: Localizations(
          locale: const Locale('en'),
          delegates: AppLocalizations.localizationsDelegates,
          child: Navigator(
            onGenerateRoute: (RouteSettings _) {
              return PageRouteDirectionality(
                builder: (BuildContext context) {
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
    required AppProvider appProvider,
    required ShellProvider shellProvider,
    Future<void> Function()? onSave,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Localizations(
          locale: const Locale('en'),
          delegates: AppLocalizations.localizationsDelegates,
          child: Navigator(
            onGenerateRoute: (RouteSettings _) {
              return PageRouteDirectionality(
                builder: (BuildContext context) {
                  return shortCutsForMainApp(
                    context,
                    shellProvider,
                    appProvider,
                    const SizedBox.shrink(),
                    onSave: onSave ?? () async {},
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
    testWidgets('renders the dialog', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byType(ShortcutsHelpDialog), findsOneWidget);
    });

    testWidgets('displays Keyboard Shortcuts title', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Keyboard Shortcuts'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows File Operations category', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('File Operations'), findsOneWidget);
    });

    testWidgets('shows Editing category', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Editing'), findsOneWidget);
    });

    testWidgets('shows View category', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('View'), findsOneWidget);
    });

    testWidgets('lists the view rotation shortcuts', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text(ShortcutActions.rotateViewCounterClockwise), findsOneWidget);
      expect(find.text(ShortcutActions.rotateViewClockwise), findsOneWidget);
      expect(find.text(ShortcutActions.rotateViewTwist), findsOneWidget);

      // Rotation reset is folded into the canvas fit, with no binding of its own.
      expect(find.text(ShortcutActions.fitCanvasToView), findsOneWidget);
      expect(find.textContaining('Reset View Rotation'), findsNothing);
    });

    testWidgets('shows Tools category', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Tools'), findsOneWidget);
    });

    testWidgets('shows Layers category', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Layers'), findsOneWidget);
    });

    testWidgets('shows Selection category with modifier shortcuts', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Selection'), findsOneWidget);
      expect(find.text('Add to Selection'), findsOneWidget);
      expect(find.text('Subtract from Selection'), findsOneWidget);
      expect(find.text('Intersect with Selection'), findsOneWidget);
      expect(find.text('Edge Detection: Sample All Layers'), findsOneWidget);
      expect(find.text('Flood Fill: Sample All Layers'), findsOneWidget);
      // Shift key cap must appear for Add to Selection
      expect(find.text(shiftModifier), findsAtLeastNWidgets(1));
      // Platform subtract modifier: Option glyph on macOS/iOS, Alt on other platforms
      expect(find.textContaining(subtractModifier), findsAtLeastNWidgets(1));
      expect(find.textContaining(primaryModifier), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Save shortcut', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('shows Undo shortcut', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('shows Close button', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('shows platform modifier key', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Should find the Command glyph on Apple platforms and Ctrl elsewhere
      expect(find.textContaining(primaryModifier), findsAtLeastNWidgets(1));
      expect(find.textContaining(isApplePlatform ? 'Cmd' : '\u2318'), findsNothing);
    });

    testWidgets('shows Brush Tool shortcut', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Brush Tool'), findsOneWidget);
    });

    testWidgets('shows Eraser Tool shortcut', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Eraser Tool'), findsOneWidget);
    });

    testWidgets('shows Tab shortcut for shell toggle', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Tab'), findsOneWidget);
      expect(find.text('Toggle Shell'), findsOneWidget);
    });

    testWidgets('shows F1 help shortcut entry', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Both bindings are shown as caps, joined by "or" rather than a plus.
      expect(
        capsForRow(tester, 'Keyboard Shortcuts', skipFirst: true),
        <String>[controlModifier, '/', 'or', 'F1'],
      );
      expect(find.text('Keyboard Shortcuts'), findsAtLeastNWidgets(2));
    });

    testWidgets('shows same-layer and new-layer duplicate shortcut entries', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text(duplicateSameLayerDescription), findsNWidgets(2));
      expect(find.text(duplicateNewLayerDescription), findsNWidgets(2));

      // Each key gets its own cap, with no joining glyph between them.
      expect(capsForRow(tester, duplicateSameLayerDescription), <String>[primaryModifier, 'D']);
      expect(capsForRow(tester, duplicateNewLayerDescription), <String>[primaryModifier, shiftModifier, 'D']);
    });

    testWidgets('renders drag gestures as text rather than a key cap', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // The modifier is a real key so it gets a cap; the drag is not.
      expect(
        capsForRow(tester, duplicateSameLayerDescription, index: 1),
        <String>[duplicateDragModifier, 'Drag Selection'],
      );
    });

    testWidgets('uses a wider adaptive dialog on large screens', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(size: const Size(1400, 900)));
      await tester.pump();

      final Size dialogSize = tester.getSize(find.byType(AppDialog));
      expect(dialogSize.width, greaterThan(AppLayout.dialogWidth));
    });

    testWidgets('keeps long shortcut descriptions readable on phone-sized screens', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(size: const Size(360, 800)));
      await tester.pump();

      final Size descriptionSize = tester.getSize(find.text(duplicateSameLayerDescription).first);
      expect(descriptionSize.width, greaterThan(AppLayout.shortcutHelpReadableTextMinWidth));
    });

    testWidgets('puts the key caps to the right of the description', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // The caps must sit after the description ends, on the same line.
      final Rect descriptionRect = tester.getRect(find.text(ShortcutActions.save));
      final Rect capRect = tester.getRect(find.text('S').first);
      expect(capRect.left, greaterThan(descriptionRect.right));
      expect(capRect.top, lessThan(descriptionRect.bottom));
    });

    testWidgets('aligns descriptions in a column so rows read as pairs', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Rows in one group share a left edge regardless of how many caps they carry.
      final double shortRowLeft = tester.getTopLeft(find.text(ShortcutActions.undo)).dx;
      final double longRowLeft = tester.getTopLeft(find.text(duplicateNewLayerDescription).first).dx;
      expect(longRowLeft, shortRowLeft);
    });
  });

  group('ShortcutsHelpDialog modifier labels per platform', () {
    /// Renders the dialog as [platform] would, restoring the override before the
    /// test ends so the framework's debug-variable invariant check stays happy.
    Future<void> pumpDialogAsPlatform(WidgetTester tester, TargetPlatform platform) async {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    }

    testWidgets('uses Apple key glyphs on macOS', (WidgetTester tester) async {
      await pumpDialogAsPlatform(tester, TargetPlatform.macOS);

      expect(capsForRow(tester, 'Save'), <String>['\u2318', 'S']);
      expect(capsForRow(tester, 'Duplicate on New Layer'), <String>['\u2318', '\u21E7', 'D']);
      expect(capsForRow(tester, 'Keyboard Shortcuts', skipFirst: true), <String>['\u2303', '/', 'or', 'F1']);
      expect(find.textContaining('Cmd'), findsNothing);
      expect(find.textContaining('Option'), findsNothing);
      // No row glues keys together with a separator glyph.
      expect(find.textContaining(' + '), findsNothing);
    });

    testWidgets('spells modifiers out on Windows', (WidgetTester tester) async {
      await pumpDialogAsPlatform(tester, TargetPlatform.windows);

      expect(capsForRow(tester, 'Save'), <String>['Ctrl', 'S']);
      expect(capsForRow(tester, 'Duplicate on New Layer'), <String>['Ctrl', 'Shift', 'D']);
      expect(capsForRow(tester, 'Subtract from Selection'), <String>['Alt']);
      expect(find.textContaining('\u2318'), findsNothing);
      expect(find.textContaining(' + '), findsNothing);
    });
  });

  group('shortCutsForMainApp', () {
    testWidgets('opens keyboard shortcuts dialog with F1', (WidgetTester tester) async {
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

    testWidgets('Cmd/Ctrl+D starts a same-layer duplicate transform', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppPreferences preferences = AppPreferences();
      await preferences.getPref();
      final AppProvider appProvider = AppProvider(preferences: preferences);
      final ShellProvider shellProvider = ShellProvider();
      appProvider.selectAll();

      await tester.pumpWidget(
        buildShortcutHandlerTestWidget(
          appProvider: appProvider,
          shellProvider: shellProvider,
        ),
      );
      await tester.pump();

      final LogicalKeyboardKey modifierKey = duplicateShortcutModifierKey();
      await tester.sendKeyDownEvent(modifierKey);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(modifierKey);
      await tester.pumpAndSettle();

      expect(appProvider.transformModel.isVisible, isTrue);
      expect(appProvider.imagePlacementModel.commitMode, ImagePlacementCommitMode.selectedLayer);
      expect(appProvider.imagePlacementModel.layerRestoreState, isNotNull);
    });

    testWidgets('Shift+Cmd/Ctrl+D starts a new-layer duplicate transform', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppPreferences preferences = AppPreferences();
      await preferences.getPref();
      final AppProvider appProvider = AppProvider(preferences: preferences);
      final ShellProvider shellProvider = ShellProvider();
      appProvider.selectAll();

      await tester.pumpWidget(
        buildShortcutHandlerTestWidget(
          appProvider: appProvider,
          shellProvider: shellProvider,
        ),
      );
      await tester.pump();

      final LogicalKeyboardKey modifierKey = duplicateShortcutModifierKey();
      await tester.sendKeyDownEvent(modifierKey);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(modifierKey);
      await tester.pumpAndSettle();

      expect(appProvider.transformModel.isVisible, isTrue);
      expect(appProvider.imagePlacementModel.commitMode, ImagePlacementCommitMode.newLayer);
      expect(appProvider.imagePlacementModel.layerRestoreState, isNull);
    });

    testWidgets('Cmd/Ctrl+S invokes onSave', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppPreferences preferences = AppPreferences();
      await preferences.getPref();
      final AppProvider appProvider = AppProvider(preferences: preferences);
      final ShellProvider shellProvider = ShellProvider();
      int saveCount = 0;

      await tester.pumpWidget(
        buildShortcutHandlerTestWidget(
          appProvider: appProvider,
          shellProvider: shellProvider,
          onSave: () async {
            saveCount += 1;
          },
        ),
      );
      await tester.pump();

      final LogicalKeyboardKey modifierKey = duplicateShortcutModifierKey();
      await tester.sendKeyDownEvent(modifierKey);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(modifierKey);
      await tester.pumpAndSettle();

      expect(saveCount, 1);
    });

    testWidgets('single-key tool shortcuts switch the selected tool', (WidgetTester tester) async {
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

      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pump();
      expect(appProvider.selectedAction, ActionType.eraser);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.pump();
      expect(appProvider.selectedAction, ActionType.text);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pump();
      expect(appProvider.selectedAction, ActionType.selector);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pump();
      expect(appProvider.selectedAction, ActionType.fill);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pump();
      expect(appProvider.selectedAction, ActionType.brush);
    });

    testWidgets('Cmd/Ctrl + and - zoom the canvas', (WidgetTester tester) async {
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

      final double initialScale = appProvider.layers.scale;
      final LogicalKeyboardKey modifierKey = duplicateShortcutModifierKey();

      await tester.sendKeyDownEvent(modifierKey);
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.sendKeyUpEvent(modifierKey);
      await tester.pump();

      final double zoomedInScale = appProvider.layers.scale;
      expect(zoomedInScale, greaterThan(initialScale));
      expect(shellProvider.canvasPlacement, CanvasAutoPlacement.manual);

      await tester.sendKeyDownEvent(modifierKey);
      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.sendKeyUpEvent(modifierKey);
      await tester.pump();

      expect(appProvider.layers.scale, lessThan(zoomedInScale));
      expect(shellProvider.canvasPlacement, CanvasAutoPlacement.manual);
    });

    testWidgets('bracket keys rotate the view and Shift+[ stays unbound', (WidgetTester tester) async {
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

      expect(appProvider.canvasRotation, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.pump();
      final double clockwise = appProvider.canvasRotation;
      expect(clockwise, greaterThan(0));

      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.pump();
      expect(appProvider.canvasRotation, lessThan(clockwise));

      // Shift+[ is deliberately not bound: on most layouts it emits "{", so the
      // activator never matched. The view must stay rotated.
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.pump();
      expect(appProvider.layers.isRotated, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(appProvider.layers.isRotated, isTrue);
    });

    testWidgets('Cmd/Ctrl+0 requests a canvas fit like the zoom-value button', (WidgetTester tester) async {
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

      // Move off the fit placement so the request is observable.
      shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
      await tester.pump();

      final LogicalKeyboardKey modifierKey = duplicateShortcutModifierKey();
      await tester.sendKeyDownEvent(modifierKey);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyUpEvent(modifierKey);
      await tester.pumpAndSettle();

      // MainView performs the fit itself, so the shortcut's contract is the
      // request: placement returns to fit, exactly as the button leaves it.
      expect(shellProvider.canvasPlacement, CanvasAutoPlacement.fit);
    });

    testWidgets('the canvas fit clears rotation and scales to the viewport', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppPreferences preferences = AppPreferences();
      await preferences.getPref();
      final AppProvider appProvider = AppProvider(preferences: preferences);

      appProvider.applyRotationToCanvas(rotationDelta: degreesToRadians(52));
      appProvider.applyScaleToCanvas(
        scaleDelta: AppVisual.enlarge,
        anchorPoint: appProvider.canvasCenter,
      );
      expect(appProvider.layers.isRotated, isTrue);

      // The fit that Cmd/Ctrl+0 requests is performed with the laid-out
      // viewport size, and leaves the canvas upright, fitted and centred.
      appProvider.canvasFitToContainer(containerWidth: 800, containerHeight: 600);

      expect(appProvider.layers.isRotated, isFalse);
      expect(appProvider.canvasRotation, closeTo(0, 1e-9));
      final double fittedScale = appProvider.layers.scale;
      expect(fittedScale, lessThan(AppVisual.full));
      final double centredX = (800 - (appProvider.layers.width * fittedScale)) / 2;
      expect(appProvider.canvasOffset.dx, closeTo(centredX, 1e-6));
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
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }
}
