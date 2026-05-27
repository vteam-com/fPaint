import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/draft_flusher.dart';
import 'package:fpaint/l10n/app_localizations.dart';
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
}
