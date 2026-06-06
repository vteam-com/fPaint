import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/image_placement_layer_restore_state.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_dialog.dart';
import 'package:fpaint/widgets/shortcuts.dart';
import 'package:fpaint/widgets/shortcuts_help.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final bool isApplePlatform =
      defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
  final String duplicateShortcutLabel = '${isApplePlatform ? 'Cmd' : 'Ctrl'} D';
  final String duplicateNewLayerShortcutLabel = '${isApplePlatform ? 'Cmd' : 'Ctrl'} Shift D';
  final String duplicateMoveShortcutLabel = '${isApplePlatform ? 'Option' : 'Ctrl'} + Drag Selection';
  final String duplicateMoveNewLayerShortcutLabel = 'Shift + ${isApplePlatform ? 'Option' : 'Ctrl'} + Drag Selection';
  const String duplicateSameLayerDescription = 'Duplicate in Same Layer';
  const String duplicateNewLayerDescription = 'Duplicate on New Layer';

  LogicalKeyboardKey duplicateShortcutModifierKey() {
    return isApplePlatform ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft;
  }

  Widget buildTestWidget({final Size size = const Size(1200, 900)}) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(size: size),
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
    final Future<void> Function()? onSave,
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

    testWidgets('shows Selection category with modifier shortcuts', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Selection'), findsOneWidget);
      expect(find.text('Add to Selection'), findsOneWidget);
      expect(find.text('Subtract from Selection'), findsOneWidget);
      expect(find.text('Intersect with Selection'), findsOneWidget);
      // Shift key cap must appear for Add to Selection
      expect(find.text('Shift'), findsAtLeastNWidgets(1));
      // Platform subtract modifier: Option on macOS/iOS, Alt on other platforms
      final bool isApple = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
      final String subtractModifier = isApple ? 'Option' : 'Alt';
      expect(find.textContaining(subtractModifier), findsAtLeastNWidgets(1));
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

    testWidgets('shows same-layer and new-layer duplicate shortcut entries', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text(duplicateShortcutLabel), findsOneWidget);
      expect(find.text(duplicateNewLayerShortcutLabel), findsOneWidget);
      expect(find.text(duplicateMoveShortcutLabel), findsOneWidget);
      expect(find.text(duplicateMoveNewLayerShortcutLabel), findsOneWidget);
      expect(find.text(duplicateSameLayerDescription), findsNWidgets(2));
      expect(find.text(duplicateNewLayerDescription), findsNWidgets(2));
    });

    testWidgets('uses a wider adaptive dialog on large screens', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(size: const Size(1400, 900)));
      await tester.pump();

      final Size dialogSize = tester.getSize(find.byType(AppDialog));
      expect(dialogSize.width, greaterThan(AppLayout.dialogWidth));
    });

    testWidgets('keeps long shortcut descriptions readable on phone-sized screens', (final WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(size: const Size(360, 800)));
      await tester.pump();

      final Size descriptionSize = tester.getSize(find.text(duplicateSameLayerDescription).first);
      expect(descriptionSize.width, greaterThan(AppLayout.shortcutHelpReadableTextMinWidth));
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

    testWidgets('Cmd/Ctrl+D starts a same-layer duplicate transform', (final WidgetTester tester) async {
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

    testWidgets('Shift+Cmd/Ctrl+D starts a new-layer duplicate transform', (final WidgetTester tester) async {
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

    testWidgets('Cmd/Ctrl+S invokes onSave', (final WidgetTester tester) async {
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
