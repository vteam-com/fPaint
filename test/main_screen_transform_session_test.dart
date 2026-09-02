import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/models/transform_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/panels/side_panel/side_panel.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/canvas_gesture_handler.dart';
import 'package:fpaint/widgets/canvas_panel.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:fpaint/widgets/selector_widget.dart';
import 'package:fpaint/widgets/transform_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _testImageDimension = 12;
const double _geometryEpsilon = 0.001;
const double _pinchInitialScale = 0.5;
const double _pinchExpectedScale = 0.6;
const double _pinchInitialRadius = 30.0;
const double _pinchFinalRadius = 36.0;
const Offset _touchContactNoise = Offset(2.0, 0.0);
const Size _largeCanvasSize = Size(5329.0, 9195.0);
const Duration _modifyModePreparationDuration = Duration(seconds: 1);
const Duration _snackBarDismissDuration = Duration(seconds: 4);
const Size _desktopTestViewSize = Size(1600, 900);

Future<ui.Image> _createTestImage() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, _testImageDimension.toDouble(), _testImageDimension.toDouble()),
    ui.Paint()..color = const Color(0xFF000000),
  );
  return recorder.endRecording().toImage(_testImageDimension, _testImageDimension);
}

void _startTransformOverlay(
  AppProvider appProvider,
  ui.Image image, {
  TransformSessionSource source = TransformSessionSource.selection,
}) {
  appProvider.transformModel.start(
    image: image,
    bounds: Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
    source: source,
  );
  appProvider.update();
}

Widget _buildHarness({
  required AppPreferences preferences,
  required AppProvider appProvider,
  required ShellProvider shellProvider,
  Widget? home,
}) {
  return InheritedControllerScope<ShellProvider>(
    controller: shellProvider,
    child: InheritedControllerScope<AppPreferences>(
      controller: preferences,
      child: InheritedControllerScope<AppProvider>(
        controller: appProvider,
        child: InheritedControllerScope<LayersProvider>(
          controller: appProvider.layers,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: home ?? const MainScreen(),
          ),
        ),
      ),
    ),
  );
}

void _expectRectMatches(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, _geometryEpsilon));
  expect(actual.top, closeTo(expected.top, _geometryEpsilon));
  expect(actual.width, closeTo(expected.width, _geometryEpsilon));
  expect(actual.height, closeTo(expected.height, _geometryEpsilon));
}

void _expectSelectionOverlayAligned(
  WidgetTester tester,
  AppProvider appProvider,
) {
  final SelectionRectWidget widget = tester.widget<SelectionRectWidget>(
    find.byType(SelectionRectWidget),
  );
  final Path? expectedPath = appProvider.getPathAdjustToCanvasSizeAndPosition(
    appProvider.selectorModel.path1,
  );

  expect(expectedPath, isNotNull);
  expect(widget.path1, isNotNull);

  _expectRectMatches(widget.path1!.getBounds(), expectedPath!.getBounds());
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
    appProvider.undoProvider.clear();
    shellProvider = ShellProvider();
    shellProvider.shellMode = ShellMode.full;
  });

  testWidgets('keeps side panel visible while transform overlay is active', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = _desktopTestViewSize;

    final ui.Image image = await _createTestImage();
    addTearDown(image.dispose);
    _startTransformOverlay(
      appProvider,
      image,
      source: TransformSessionSource.clipboardPaste,
    );

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump();

    expect(find.byType(MainView), findsOneWidget);
    expect(find.byType(TransformWidget), findsOneWidget);
    expect(find.byType(SelectionRectWidget), findsNothing);
    expect(find.byType(SidePanel), findsOneWidget);
    expect(find.byKey(Keys.floatActionToggle), findsOneWidget);
    expect(find.byKey(Keys.floatActionSelector), findsOneWidget);
    expect(find.byKey(Keys.floatActionZoomIn), findsOneWidget);
  });

  testWidgets('keeps side panel visible when duplicating from an active selection', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = _desktopTestViewSize;

    appProvider.selectAll();
    await appProvider.regionDuplicate();

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump();

    expect(find.byType(MainView), findsOneWidget);
    expect(find.byType(TransformWidget), findsOneWidget);
    expect(find.byType(SelectionRectWidget), findsNothing);
    expect(find.byType(SidePanel), findsOneWidget);
    expect(find.byKey(Keys.floatActionToggle), findsOneWidget);
  });

  testWidgets('shows the target layer in a snackbar after confirming a duplicate', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = _desktopTestViewSize;

    appProvider.selectAll();
    await appProvider.regionDuplicateSameLayer();

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump();

    final BuildContext context = tester.element(find.byType(MainView));
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String selectedLayerName = appProvider.layers.selectedLayer.name;
    final TransformWidget transformWidget = tester.widget<TransformWidget>(find.byType(TransformWidget));

    transformWidget.onConfirm();
    await tester.pump();
    await tester.pump();

    expect(find.text(l10n.duplicatedOnLayer(selectedLayerName)), findsOneWidget);

    await tester.pump(_snackBarDismissDuration);
    await tester.pump();
  });

  testWidgets('keeps side panel visible when pasting an image from the clipboard', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = _desktopTestViewSize;

    final ui.Image image = await _createTestImage();
    addTearDown(image.dispose);
    _startTransformOverlay(
      appProvider,
      image,
      source: TransformSessionSource.clipboardPaste,
    );

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump();

    expect(find.byType(MainView), findsOneWidget);
    expect(find.byType(TransformWidget), findsOneWidget);
    expect(find.byType(SidePanel), findsOneWidget);
    expect(find.byKey(Keys.floatActionToggle), findsOneWidget);
  });

  testWidgets('keeps side panel visible with modify actions during layer modify mode', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = _desktopTestViewSize;

    await appProvider.modifySelectedLayer();
    await tester.pump(_modifyModePreparationDuration);

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump();

    expect(find.byType(MainView), findsOneWidget);
    expect(find.byType(SelectionRectWidget), findsNothing);
    expect(find.byType(TransformWidget), findsOneWidget);
    expect(find.byType(SidePanel), findsOneWidget);
    expect(find.text('Modify'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
  });

  testWidgets('keeps selection overlay aligned while side panel resizes or closes', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = _desktopTestViewSize;

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump();

    appProvider.selectAll();
    appProvider.update();
    await tester.pump();

    expect(find.byType(SelectionRectWidget), findsOneWidget);
    _expectSelectionOverlayAligned(tester, appProvider);

    shellProvider.isSidePanelExpanded = false;
    await tester.pump();
    _expectSelectionOverlayAligned(tester, appProvider);

    shellProvider.isSidePanelExpanded = true;
    await tester.pump();
    _expectSelectionOverlayAligned(tester, appProvider);

    shellProvider.shellMode = ShellMode.hidden;
    shellProvider.update();
    await tester.pump();
    _expectSelectionOverlayAligned(tester, appProvider);
  });

  testWidgets('desktop shell button cycles expanded, narrow, hidden, and expanded', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = _desktopTestViewSize;

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump();

    expect(find.byKey(Keys.floatActionToggle), findsOneWidget);
    expect(shellProvider.shellMode, ShellMode.full);
    expect(shellProvider.isSidePanelExpanded, isTrue);
    expect(find.byType(SidePanel), findsOneWidget);

    await tester.tap(find.byKey(Keys.floatActionToggle));
    await tester.pump();

    expect(shellProvider.shellMode, ShellMode.full);
    expect(shellProvider.isSidePanelExpanded, isFalse);
    expect(find.byType(SidePanel), findsOneWidget);

    await tester.tap(find.byKey(Keys.floatActionToggle));
    await tester.pump();

    expect(shellProvider.shellMode, ShellMode.hidden);
    expect(find.byKey(Keys.floatActionToggle), findsOneWidget);
    expect(find.byType(SidePanel), findsNothing);

    await tester.tap(find.byKey(Keys.floatActionToggle));
    await tester.pump();

    expect(shellProvider.shellMode, ShellMode.full);
    expect(shellProvider.isSidePanelExpanded, isTrue);
    expect(find.byType(SidePanel), findsOneWidget);
  });

  testWidgets('keeps layer modify transform overlay visible while side panel resizes or closes', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = _desktopTestViewSize;

    await appProvider.modifySelectedLayer();
    await tester.pump(_modifyModePreparationDuration);

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump();

    expect(find.byType(TransformWidget), findsOneWidget);

    shellProvider.isSidePanelExpanded = false;
    await tester.pump();
    expect(find.byType(TransformWidget), findsOneWidget);

    shellProvider.isSidePanelExpanded = true;
    await tester.pump();
    expect(find.byType(TransformWidget), findsOneWidget);

    shellProvider.shellMode = ShellMode.hidden;
    shellProvider.update();
    await tester.pump();
    expect(find.byType(TransformWidget), findsOneWidget);
  });

  testWidgets('uses compact horizontal padding for modify mode in a narrow side panel', (
    WidgetTester tester,
  ) async {
    await appProvider.modifySelectedLayer();
    await tester.pump(_modifyModePreparationDuration);

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: AppLayout.sidePanelCollapsed,
            height: AppLayout.sidePanelExpandedMin,
            child: SidePanel(
              minimal: false,
              preferences: preferences,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.getSize(find.byType(SidePanel)).width, AppLayout.sidePanelCollapsed);

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Padding &&
            widget.padding ==
                const EdgeInsets.symmetric(
                  horizontal: AppSpacing.small,
                  vertical: AppSpacing.large,
                ),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: AppLayout.sidePanelExpandedMin,
            height: AppLayout.sidePanelExpandedMin,
            child: SidePanel(
              minimal: false,
              preferences: preferences,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.getSize(find.byType(SidePanel)).width, AppLayout.sidePanelExpandedMin);

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Padding &&
            widget.padding ==
                const EdgeInsets.symmetric(
                  horizontal: AppSpacing.large,
                  vertical: AppSpacing.large,
                ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('keeps bottom-right tools visible while transform overlay is active', (
    WidgetTester tester,
  ) async {
    final ui.Image image = await _createTestImage();
    addTearDown(image.dispose);
    _startTransformOverlay(appProvider, image);

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump();

    expect(find.byType(MainView), findsOneWidget);
    expect(find.byType(SidePanel), findsOneWidget);
    expect(find.byKey(Keys.floatActionSelector), findsOneWidget);
    expect(find.byKey(Keys.floatActionZoomIn), findsOneWidget);
  });

  testWidgets('pinch zoom works while transform overlay is active', (WidgetTester tester) async {
    final ui.Image image = await _createTestImage();
    addTearDown(image.dispose);
    _startTransformOverlay(appProvider, image);

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump();

    final Finder canvasGestureHandler = find.byType(CanvasGestureHandler);
    expect(canvasGestureHandler, findsOneWidget);

    final Offset center = tester.getCenter(canvasGestureHandler);
    final Offset localCenter = center - tester.getTopLeft(canvasGestureHandler);
    appProvider.layers.scale = _pinchInitialScale;
    final Offset canvasPointAtFocalPoint = appProvider.toCanvas(localCenter);

    final TestGesture finger1 = await tester.startGesture(
      center + const Offset(-_pinchInitialRadius, 0),
      pointer: 1,
      kind: ui.PointerDeviceKind.touch,
    );
    expect(find.byKey(Keys.brushSizePreviewOverlay), findsNothing);
    await tester.pump();
    final TestGesture finger2 = await tester.startGesture(
      center + const Offset(_pinchInitialRadius, 0),
      pointer: 2,
      kind: ui.PointerDeviceKind.touch,
    );
    expect(find.byKey(Keys.brushSizePreviewOverlay), findsNothing);
    await tester.pump();

    await finger1.moveTo(center + const Offset(-_pinchFinalRadius, 0));
    await tester.pump();
    await finger2.moveTo(center + const Offset(_pinchFinalRadius, 0));
    await tester.pump();

    expect(appProvider.layers.scale, closeTo(_pinchExpectedScale, _geometryEpsilon));
    expect(appProvider.toCanvas(localCenter).dx, closeTo(canvasPointAtFocalPoint.dx, _geometryEpsilon));
    expect(appProvider.toCanvas(localCenter).dy, closeTo(canvasPointAtFocalPoint.dy, _geometryEpsilon));

    await finger1.up();
    await finger2.up();
    await tester.pump();
  });

  testWidgets('maximum zoom bounds layer compositing to the visible viewport', (WidgetTester tester) async {
    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
    appProvider.layers.size = _largeCanvasSize;
    appProvider.layers.scale = AppInteraction.maxCanvasScale;
    appProvider.canvasOffset = Offset.zero;

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump();

    final Finder canvasGestureHandler = find.byType(CanvasGestureHandler);
    final Finder canvasPanelFinder = find.byType(CanvasPanel);
    final CanvasPanel canvasPanel = tester.widget<CanvasPanel>(canvasPanelFinder);
    final Size viewportSize = tester.getSize(canvasGestureHandler);

    expect(tester.getSize(canvasPanelFinder), viewportSize);
    expect(
      canvasPanel.visibleCanvasBounds.width,
      closeTo(viewportSize.width / AppInteraction.maxCanvasScale, _geometryEpsilon),
    );
    expect(
      canvasPanel.visibleCanvasBounds.height,
      closeTo(viewportSize.height / AppInteraction.maxCanvasScale, _geometryEpsilon),
    );
    expect(
      find.descendant(of: canvasPanelFinder, matching: find.byType(RepaintBoundary)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    for (final LayerProvider layer in appProvider.layers.list) {
      layer.cancelPendingThumbnailRebuild();
    }
  });

  testWidgets('two-finger touch does not create a drawing action', (WidgetTester tester) async {
    appProvider.selectedAction = ActionType.brush;
    appProvider.brushSize = 24.0;
    shellProvider.shellMode = ShellMode.hidden;
    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump();

    final Finder canvasGestureHandler = find.byType(CanvasGestureHandler);
    final Offset center = tester.getCenter(canvasGestureHandler);
    final int initialActionCount = appProvider.layers.selectedLayer.actionStack.length;
    expect(find.byKey(Keys.brushSizePreviewOverlay), findsOneWidget);
    final TestGesture finger1 = await tester.startGesture(
      center + const Offset(-_pinchInitialRadius, 0),
      pointer: 1,
      kind: ui.PointerDeviceKind.touch,
    );
    await finger1.moveBy(_touchContactNoise);
    await tester.pump();
    expect(find.byKey(Keys.brushSizePreviewOverlay), findsNothing);
    final TestGesture finger2 = await tester.startGesture(
      center + const Offset(_pinchInitialRadius, 0),
      pointer: 2,
      kind: ui.PointerDeviceKind.touch,
    );

    await finger1.moveTo(center + const Offset(-_pinchFinalRadius, 0));
    await finger2.moveTo(center + const Offset(_pinchFinalRadius, 0));
    await tester.pump();
    await finger1.up();
    await finger2.up();
    await tester.pump();

    expect(appProvider.layers.selectedLayer.actionStack.length, initialActionCount);
  });

  testWidgets('pinch zoom continues with a third touch contact', (WidgetTester tester) async {
    shellProvider.shellMode = ShellMode.hidden;
    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump();

    final Finder canvasGestureHandler = find.byType(CanvasGestureHandler);
    final Offset center = tester.getCenter(canvasGestureHandler);
    appProvider.layers.scale = _pinchInitialScale;
    final TestGesture finger1 = await tester.startGesture(
      center + const Offset(-_pinchInitialRadius, 0),
      pointer: 1,
      kind: ui.PointerDeviceKind.touch,
    );
    final TestGesture finger2 = await tester.startGesture(
      center + const Offset(_pinchInitialRadius, 0),
      pointer: 2,
      kind: ui.PointerDeviceKind.touch,
    );
    final TestGesture extraContact = await tester.startGesture(
      center + const Offset(0, _pinchInitialRadius),
      pointer: 3,
      kind: ui.PointerDeviceKind.touch,
    );

    await finger1.moveTo(center + const Offset(-_pinchFinalRadius, 0));
    await finger2.moveTo(center + const Offset(_pinchFinalRadius, 0));
    await tester.pump();

    expect(appProvider.layers.scale, closeTo(_pinchExpectedScale, _geometryEpsilon));

    await extraContact.up();
    await finger1.up();
    await finger2.up();
    await tester.pump();
  });

  testWidgets('two-finger panning does not change the canvas zoom scale', (WidgetTester tester) async {
    shellProvider.shellMode = ShellMode.hidden;
    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump();

    final Finder canvasGestureHandler = find.byType(CanvasGestureHandler);
    final Offset center = tester.getCenter(canvasGestureHandler);
    const double initialScale = 1.0;
    appProvider.layers.scale = initialScale;

    final TestGesture finger1 = await tester.startGesture(
      center + const Offset(-_pinchInitialRadius, 0),
      pointer: 1,
      kind: ui.PointerDeviceKind.touch,
    );
    final TestGesture finger2 = await tester.startGesture(
      center + const Offset(_pinchInitialRadius, 0),
      pointer: 2,
      kind: ui.PointerDeviceKind.touch,
    );

    // Pan both fingers right by 50px in 5px steps (pure two-finger panning translation).
    for (int i = 1; i <= 10; i++) {
      await finger1.moveTo(center + Offset(-_pinchInitialRadius + (i * 5.0), 0.0));
      await tester.pump();
      expect(appProvider.layers.scale, closeTo(initialScale, _geometryEpsilon));
      await finger2.moveTo(center + Offset(_pinchInitialRadius + (i * 5.0), 0.0));
      await tester.pump();
    }

    // The scale must remain unchanged because distance change is zero during translation panning.
    expect(appProvider.layers.scale, closeTo(initialScale, _geometryEpsilon));

    await finger1.up();
    await finger2.up();
    await tester.pump();
  });

  testWidgets('single-pointer canvas drawing stays disabled while transform overlay is active', (
    WidgetTester tester,
  ) async {
    final ui.Image image = await _createTestImage();
    addTearDown(image.dispose);
    appProvider.selectedAction = ActionType.brush;
    _startTransformOverlay(appProvider, image);

    await tester.pumpWidget(
      _buildHarness(
        preferences: preferences,
        appProvider: appProvider,
        shellProvider: shellProvider,
      ),
    );
    await tester.pump();

    final Finder canvasGestureHandler = find.byType(CanvasGestureHandler);
    expect(canvasGestureHandler, findsOneWidget);

    final int actionCountBefore = appProvider.layers.selectedLayer.actionStack.length;
    final Offset center = tester.getCenter(canvasGestureHandler);
    final TestGesture gesture = await tester.startGesture(
      center,
      pointer: 1,
      kind: ui.PointerDeviceKind.touch,
    );
    await tester.pump();
    await gesture.moveBy(const Offset(20, 20));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(appProvider.layers.selectedLayer.actionStack.length, actionCountBefore);
  });
}
