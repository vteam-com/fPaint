import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/draft_flusher.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/canvas_gesture_handler.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_harness.dart';

class _NoopDraftFlusher implements DraftFlusher {
  @override
  Future<void> flushNow() async {}
}

Widget _buildHarness({
  required final AppPreferences preferences,
  required final AppProvider appProvider,
  required final ShellProvider shellProvider,
}) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<DraftFlusher>.value(value: _NoopDraftFlusher()),
      ChangeNotifierProvider<AppPreferences>.value(value: preferences),
      ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ChangeNotifierProvider<LayersProvider>.value(value: appProvider.layers),
      ChangeNotifierProvider<ShellProvider>.value(value: shellProvider),
    ],
    child: buildLocalizedTestApp(
      home: const Scaffold(body: SizedBox.expand(child: MainView())),
    ),
  );
}

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

  testWidgets('shows and hides centered brush-size preview while brush size changes', (
    final WidgetTester tester,
  ) async {
    const Color activeColor = Color(0xFF123456);
    appProvider.brushColor = activeColor;

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );

    appProvider.brushSize = 24.0;
    await tester.pump();

    final Finder previewFinder = find.byKey(Keys.brushSizePreviewOverlay);
    expect(previewFinder, findsOneWidget);
    final double expectedDiameter = 24.0 * appProvider.layers.scale;
    expect(tester.getSize(previewFinder), Size(expectedDiameter, expectedDiameter));

    final Finder mainViewFinder = find.byType(MainView);
    expect(tester.getCenter(previewFinder), tester.getCenter(mainViewFinder));
    expect(appProvider.brushSizePreviewColor, activeColor);

    await tester.pump(AppDefaults.brushSizePreviewDuration);
    await tester.pump();

    expect(find.byKey(Keys.brushSizePreviewOverlay), findsNothing);
  });

  testWidgets('shows brush-size preview at the drawing position while dragging', (
    final WidgetTester tester,
  ) async {
    appProvider.selectedAction = ActionType.brush;
    appProvider.brushSize = 24.0;

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump(AppDefaults.brushSizePreviewDuration);
    await tester.pump();

    final Finder canvasGestureHandler = find.byType(CanvasGestureHandler);
    expect(canvasGestureHandler, findsOneWidget);

    final Offset dragStart = tester.getTopLeft(canvasGestureHandler) + const Offset(140, 160);
    final TestGesture gesture = await tester.startGesture(dragStart);
    await tester.pump();

    final Finder previewFinder = find.byKey(Keys.brushSizePreviewOverlay);
    expect(previewFinder, findsOneWidget);
    expect(tester.getCenter(previewFinder), dragStart);

    const Offset dragDelta = Offset(36, 28);
    await gesture.moveBy(dragDelta);
    await tester.pump();

    expect(find.byKey(Keys.brushSizePreviewOverlay), findsOneWidget);
    expect(tester.getCenter(previewFinder), dragStart + dragDelta);

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.byKey(Keys.brushSizePreviewOverlay), findsNothing);
  });

  testWidgets('shows brush-size preview while hovering a mouse before drawing', (
    final WidgetTester tester,
  ) async {
    appProvider.selectedAction = ActionType.brush;
    appProvider.brushSize = 24.0;

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump(AppDefaults.brushSizePreviewDuration);
    await tester.pump();

    final Finder canvasGestureHandler = find.byType(CanvasGestureHandler);
    expect(canvasGestureHandler, findsOneWidget);

    final Offset hoverPosition = tester.getTopLeft(canvasGestureHandler) + const Offset(120, 140);
    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: hoverPosition);
    await mouse.moveTo(hoverPosition);
    await tester.pump();

    final Finder previewFinder = find.byKey(Keys.brushSizePreviewOverlay);
    expect(previewFinder, findsOneWidget);
    expect(tester.getCenter(previewFinder), hoverPosition);
  });
}
