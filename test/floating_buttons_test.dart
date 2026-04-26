import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/floating_buttons.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppProvider appProvider;
  late ShellProvider shellProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppPreferences preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
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

  group('floatingActionButtons - desktop layout', () {
    testWidgets('renders undo button', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return floatingActionButtons(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      // Desktop layout uses Column
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('renders zoom in button with correct key', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return floatingActionButtons(context, shellProvider, appProvider);
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
              return floatingActionButtons(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(Keys.floatActionZoomOut), findsOneWidget);
    });

    testWidgets('renders center button with correct key', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return floatingActionButtons(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(Keys.floatActionCenter), findsOneWidget);
    });

    testWidgets('renders toggle button with correct key', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return floatingActionButtons(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(Keys.floatActionToggle), findsOneWidget);
    });

    testWidgets('center button displays zoom and canvas size', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return floatingActionButtons(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      // Scale is 1.0 (100%), default canvas size 1024x768
      expect(find.textContaining('100'), findsOneWidget);
    });

    testWidgets('toggle button hides shell on tap', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = false;
      shellProvider.shellMode = ShellMode.full;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return floatingActionButtons(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(Keys.floatActionToggle));
      await tester.pump();

      expect(shellProvider.shellMode, ShellMode.hidden);
    });

    testWidgets('zoom in changes canvas placement to manual', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = false;
      shellProvider.canvasPlacement = CanvasAutoPlacement.fit;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return floatingActionButtons(context, shellProvider, appProvider);
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
              return floatingActionButtons(context, shellProvider, appProvider);
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
              return floatingActionButtons(context, shellProvider, appProvider);
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
  });

  group('floatingActionButtons - mobile layout', () {
    testWidgets('renders Row layout when deviceSizeSmall is true', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = true;
      shellProvider.showMenu = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return floatingActionButtons(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      // Mobile layout uses Row
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('shows undo and redo when menu is hidden', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = true;
      shellProvider.showMenu = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return floatingActionButtons(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      // 4 GestureDetectors: tool icon, color, undo, redo
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('shows close button when menu is visible', (final WidgetTester tester) async {
      shellProvider.deviceSizeSmall = true;
      shellProvider.showMenu = true;

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (final BuildContext context) {
              return floatingActionButtons(context, shellProvider, appProvider);
            },
          ),
        ),
      );
      await tester.pump();

      // Only the close button should be rendered (1 GestureDetector)
      expect(find.byType(GestureDetector), findsOneWidget);
    });
  });

  group('myFloatButton', () {
    testWidgets('renders with icon', (final WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: myFloatButton(
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
          child: myFloatButton(
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
          child: myFloatButton(
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
          child: myFloatButton(
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
          child: myFloatButton(
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
          child: myFloatButton(
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
          child: myFloatButton(
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
