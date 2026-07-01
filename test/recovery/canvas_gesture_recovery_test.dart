import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/draft_flusher.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/smudge_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/image_placement_layer_restore_state.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/recovery/draft_recovery_controller.dart';
import 'package:fpaint/widgets/canvas_gesture_handler.dart';
import 'package:fpaint/widgets/text_editor_dialog.dart';
import 'package:provider/single_child_widget.dart';

import '../helpers/recovery_test_helpers.dart';

/// Commits an opaque blur patch covering [patchBounds] onto a fully opaque
/// 64×64 layer, rebuilds the display cache at [scale] (which replays the patch
/// under a fractional canvas.scale), and returns the minimum alpha of the
/// re-rendered display. An opaque layer must stay fully opaque; any value below
/// 255 is the transparent seam the canvas backdrop shows through as the white
/// rectangle around the stroke.
Future<int> _committedPatchMinDisplayAlpha(final Rect patchBounds, final double scale) async {
  final LayerProvider layer = LayerProvider(
    name: 'Seam',
    size: const Size(64, 64),
    onThumbnailChanged: () {},
  );
  layer.appendDrawingAction(
    UserActionDrawing(
      action: ActionType.region,
      positions: <Offset>[Offset.zero, const Offset(64, 64)],
      fillColor: const Color(0xFF3388AA),
      path: ui.Path()..addRect(const Rect.fromLTWH(0, 0, 64, 64)),
    ),
  );
  final ImagePlacementLayerRestoreState restoreState = ImagePlacementLayerRestoreState(
    layerIndex: 0,
    originalActions: List<UserActionDrawing>.from(layer.actionStack),
    originalRedoActions: <UserActionDrawing>[],
    originalHasChanged: layer.hasChanged,
    originalBackgroundColor: layer.backgroundColor,
    originalBlendMode: layer.blendMode,
    originalOpacity: layer.opacity,
  );
  final ui.Image patch = await renderCanvasImage(
    width: patchBounds.width.toInt(),
    height: patchBounds.height.toInt(),
    draw: (final ui.Canvas canvas) => canvas.drawRect(
      Rect.fromLTWH(0, 0, patchBounds.width, patchBounds.height),
      Paint()..color = const Color(0xFF992222),
    ),
  );

  applyPixelBrushPatchToLayer(
    restoreState: restoreState,
    targetLayer: layer,
    patch: PixelBrushLayerPatch(bounds: patchBounds, image: patch),
    mode: PixelBrushMode.blur,
  );

  await layer.buildDisplayCache(scale);
  final ui.Image displayed = await renderCanvasImage(
    width: 64,
    height: 64,
    draw: (final ui.Canvas canvas) => layer.renderLayerForDisplay(canvas, scale, () {}),
  );
  final ByteData? bytes = await displayed.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  displayed.dispose();
  int minAlpha = 255;
  for (int i = 3; i < bytes!.lengthInBytes; i += 4) {
    if (bytes.getUint8(i) < minAlpha) {
      minAlpha = bytes.getUint8(i);
    }
  }
  return minAlpha;
}

void main() {
  testWidgets('pointer up flushes a recovery draft immediately', (final WidgetTester tester) async {
    final AppPreferences preferences = await createRecoveryTestPreferences();
    final AppProvider appProvider = AppProvider(preferences: preferences);
    final ShellProvider shellProvider = ShellProvider();
    final MemoryDraftRecoveryStorage storage = MemoryDraftRecoveryStorage();
    final DraftRecoveryController controller = DraftRecoveryController(
      preferences: preferences,
      layers: appProvider.layers,
      shellProvider: shellProvider,
      storage: storage,
      encoder: (final LayersProvider _) async => <int>[1, 2, 3],
      saveDebounce: const Duration(seconds: 10),
    );

    resetAppProviderLayersForRecovery(appProvider);
    await controller.initialize();

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<DraftRecoveryController>.value(value: controller),
          Provider<DraftFlusher>.value(value: controller),
          ChangeNotifierProvider<AppPreferences>.value(value: preferences),
          ChangeNotifierProvider<AppProvider>.value(value: appProvider),
          ChangeNotifierProvider<ShellProvider>.value(value: shellProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(
              child: CanvasGestureHandler(
                child: ColoredBox(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(CanvasGestureHandler)));
    await tester.pump();
    await gesture.moveBy(const Offset(20, 20));
    await tester.pump();

    expect(storage.bytes, isNull, reason: 'Debounced autosave should not have written yet.');

    await gesture.up();
    await tester.pump();

    expect(storage.bytes, Uint8List.fromList(<int>[1, 2, 3]));

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    controller.dispose();
  });

  testWidgets('text dialog does not lock subsequent tools', (final WidgetTester tester) async {
    final AppPreferences preferences = await createRecoveryTestPreferences();
    final AppProvider appProvider = AppProvider(preferences: preferences);
    final ShellProvider shellProvider = ShellProvider();
    final MemoryDraftRecoveryStorage storage = MemoryDraftRecoveryStorage();
    final DraftRecoveryController controller = DraftRecoveryController(
      preferences: preferences,
      layers: appProvider.layers,
      shellProvider: shellProvider,
      storage: storage,
      encoder: (final LayersProvider _) async => <int>[1, 2, 3],
      saveDebounce: const Duration(seconds: 10),
    );

    resetAppProviderLayersForRecovery(appProvider);
    await controller.initialize();

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<DraftRecoveryController>.value(value: controller),
          Provider<DraftFlusher>.value(value: controller),
          ChangeNotifierProvider<AppPreferences>.value(value: preferences),
          ChangeNotifierProvider<AppProvider>.value(value: appProvider),
          ChangeNotifierProvider<ShellProvider>.value(value: shellProvider),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox.expand(
              child: CanvasGestureHandler(
                child: ColoredBox(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    appProvider.selectedAction = ActionType.text;
    await tester.pump();

    await tester.tap(find.byType(CanvasGestureHandler));
    await tester.pumpAndSettle();
    expect(find.byType(TextEditorDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    appProvider.selectedAction = ActionType.brush;
    await tester.pump();

    final Offset center = tester.getCenter(find.byType(CanvasGestureHandler));
    final TestGesture gesture = await tester.startGesture(center);
    await tester.pump();
    await gesture.moveBy(const Offset(20, 20));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(appProvider.layers.selectedLayer.actionStack, isNotEmpty);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    controller.dispose();
  });

  testWidgets('straight-line selector closes only after returning to the first point', (
    final WidgetTester tester,
  ) async {
    final AppPreferences preferences = await createRecoveryTestPreferences();
    final AppProvider appProvider = AppProvider(preferences: preferences);
    final ShellProvider shellProvider = ShellProvider();
    final MemoryDraftRecoveryStorage storage = MemoryDraftRecoveryStorage();
    final DraftRecoveryController controller = DraftRecoveryController(
      preferences: preferences,
      layers: appProvider.layers,
      shellProvider: shellProvider,
      storage: storage,
      encoder: (final LayersProvider _) async => <int>[1, 2, 3],
      saveDebounce: const Duration(seconds: 10),
    );

    resetAppProviderLayersForRecovery(appProvider);
    await controller.initialize();

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<DraftRecoveryController>.value(value: controller),
          Provider<DraftFlusher>.value(value: controller),
          ChangeNotifierProvider<AppPreferences>.value(value: preferences),
          ChangeNotifierProvider<AppProvider>.value(value: appProvider),
          ChangeNotifierProvider<ShellProvider>.value(value: shellProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(
              child: CanvasGestureHandler(
                child: ColoredBox(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    appProvider.selectedAction = ActionType.selector;
    appProvider.selectorModel.mode = SelectorMode.line;
    await tester.pump();

    final Offset canvasTopLeft = tester.getTopLeft(find.byType(CanvasGestureHandler));

    Future<void> tapCanvas(final Offset canvasPosition) async {
      await tester.tapAt(canvasTopLeft + canvasPosition);
      await tester.pump();
    }

    await tapCanvas(const Offset(50, 50));
    expect(appProvider.selectorModel.isDrawing, isTrue);
    expect(appProvider.selectorModel.points, <Offset>[const Offset(50, 50)]);

    await tapCanvas(const Offset(120, 50));
    expect(appProvider.selectorModel.isDrawing, isTrue);
    expect(appProvider.selectorModel.points, <Offset>[const Offset(50, 50), const Offset(120, 50)]);

    await tapCanvas(const Offset(120, 120));
    expect(appProvider.selectorModel.isDrawing, isTrue);
    expect(
      appProvider.selectorModel.points,
      <Offset>[const Offset(50, 50), const Offset(120, 50), const Offset(120, 120)],
    );

    await tapCanvas(const Offset(52, 52));
    expect(appProvider.selectorModel.isDrawing, isFalse);
    expect(appProvider.selectorModel.points, isEmpty);
    expect(appProvider.selectorModel.path1, isNotNull);
    expect(appProvider.selectorModel.path1!.getBounds(), const Rect.fromLTWH(50, 50, 70, 70));

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    controller.dispose();
  });

  testWidgets('straight-line selector closes on double tap without returning to the first point', (
    final WidgetTester tester,
  ) async {
    final AppPreferences preferences = await createRecoveryTestPreferences();
    final AppProvider appProvider = AppProvider(preferences: preferences);
    final ShellProvider shellProvider = ShellProvider();
    final MemoryDraftRecoveryStorage storage = MemoryDraftRecoveryStorage();
    final DraftRecoveryController controller = DraftRecoveryController(
      preferences: preferences,
      layers: appProvider.layers,
      shellProvider: shellProvider,
      storage: storage,
      encoder: (final LayersProvider _) async => <int>[1, 2, 3],
      saveDebounce: const Duration(seconds: 10),
    );

    resetAppProviderLayersForRecovery(appProvider);
    await controller.initialize();

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<DraftRecoveryController>.value(value: controller),
          Provider<DraftFlusher>.value(value: controller),
          ChangeNotifierProvider<AppPreferences>.value(value: preferences),
          ChangeNotifierProvider<AppProvider>.value(value: appProvider),
          ChangeNotifierProvider<ShellProvider>.value(value: shellProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(
              child: CanvasGestureHandler(
                child: ColoredBox(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    appProvider.selectedAction = ActionType.selector;
    appProvider.selectorModel.mode = SelectorMode.line;
    await tester.pump();

    final Offset canvasTopLeft = tester.getTopLeft(find.byType(CanvasGestureHandler));

    Future<void> tapCanvas(final Offset canvasPosition) async {
      await tester.tapAt(canvasTopLeft + canvasPosition);
      await tester.pump();
    }

    await tapCanvas(const Offset(50, 50));
    await tapCanvas(const Offset(120, 50));
    await tapCanvas(const Offset(120, 120));

    expect(appProvider.selectorModel.isDrawing, isTrue);
    expect(
      appProvider.selectorModel.points,
      <Offset>[const Offset(50, 50), const Offset(120, 50), const Offset(120, 120)],
    );

    await tester.tapAt(canvasTopLeft + const Offset(170, 140));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(canvasTopLeft + const Offset(170, 140));
    await tester.pump();

    expect(appProvider.selectorModel.isDrawing, isFalse);
    expect(appProvider.selectorModel.points, isEmpty);
    expect(appProvider.selectorModel.path1, isNotNull);
    expect(appProvider.selectorModel.path1!.getBounds(), const Rect.fromLTWH(50, 50, 120, 90));

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    controller.dispose();
  });

  test('smudge patch application keeps prior vector actions and appends a bounded replacement', () async {
    final LayerProvider layer = LayerProvider(
      name: 'Test',
      size: const Size(200, 200),
      onThumbnailChanged: () {},
    );
    layer.appendDrawingAction(
      UserActionDrawing(
        action: ActionType.region,
        positions: <Offset>[const Offset(80, 80), const Offset(120, 160)],
        fillColor: const Color(0xFFFF6699),
        path: ui.Path()..addRect(const Rect.fromLTWH(80, 80, 40, 80)),
      ),
    );
    layer.appendDrawingAction(
      UserActionDrawing(
        action: ActionType.region,
        positions: <Offset>[const Offset(120, 80), const Offset(160, 160)],
        fillColor: const Color(0xFF6699FF),
        path: ui.Path()..addRect(const Rect.fromLTWH(120, 80, 40, 80)),
      ),
    );

    final ImagePlacementLayerRestoreState restoreState = ImagePlacementLayerRestoreState(
      layerIndex: 0,
      originalActions: List<UserActionDrawing>.from(layer.actionStack),
      originalRedoActions: <UserActionDrawing>[],
      originalHasChanged: layer.hasChanged,
      originalBackgroundColor: layer.backgroundColor,
      originalBlendMode: layer.blendMode,
      originalOpacity: layer.opacity,
    );
    final ui.Image patchImage = await renderCanvasImage(
      width: 8,
      height: 8,
      draw: (final ui.Canvas canvas) {
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 8, 8),
          Paint()..color = const Color(0xFFFFFFFF),
        );
      },
    );

    applyPixelBrushPatchToLayer(
      restoreState: restoreState,
      targetLayer: layer,
      patch: PixelBrushLayerPatch(
        bounds: const Rect.fromLTWH(116, 116, 8, 8),
        image: patchImage,
      ),
      mode: PixelBrushMode.smudge,
    );

    final List<ActionType> actions = layer.actionStack.map((final UserActionDrawing action) => action.action).toList();
    expect(actions, contains(ActionType.region));
    expect(actions, contains(ActionType.smudge));
    // No separate `cut`: the patch action replaces its region with BlendMode.src.
    // A clear-then-srcOver pair left a sub-1-alpha ring at anti-aliased edges when
    // replayed under the display cache's fractional scale — the white rectangle
    // around the stroke.
    expect(actions, isNot(contains(ActionType.cut)));
    expect(actions.length, 3);
  });

  test('a committed smudge/blur patch never leaves a display-cache seam', () async {
    // End-to-end guard for the "white rectangle around the blur/smudge stroke":
    // commit a patch through the real path, then rebuild the display cache (which
    // replays the patch under a fractional canvas.scale). The seam depended on
    // the sub-pixel fraction of the scaled patch bounds, so sweep several scales
    // and offsets — a fully opaque layer must stay fully opaque (no alpha < 255)
    // in every case. Fails if the commit re-introduces the `cut` clear or the
    // patch renders srcOver instead of BlendMode.src.
    const List<Rect> boundsCases = <Rect>[
      Rect.fromLTWH(11, 11, 22, 16),
      Rect.fromLTWH(7, 5, 19, 21),
      Rect.fromLTWH(9, 13, 25, 17),
      Rect.fromLTWH(3, 7, 30, 27),
      Rect.fromLTWH(5, 9, 21, 23),
    ];
    const List<double> scaleCases = <double>[0.5, 0.375, 0.6, 0.7];

    for (final double scale in scaleCases) {
      for (final Rect bounds in boundsCases) {
        expect(
          await _committedPatchMinDisplayAlpha(bounds, scale),
          255,
          reason: 'transparent seam for bounds=$bounds scale=$scale',
        );
      }
    }
  });
}
