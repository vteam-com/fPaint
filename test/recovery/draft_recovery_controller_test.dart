import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/recovery/draft_recovery_controller.dart';
import '../helpers/recovery_test_helpers.dart';

void main() {
  testWidgets('autosave writes and clears the recovery draft', (final WidgetTester tester) async {
    final AppPreferences preferences = await createRecoveryTestPreferences();
    final LayersProvider layers = createRecoveryTestLayers();
    final ShellProvider shellProvider = ShellProvider()..loadedFileName = '/tmp/example.ora';
    final MemoryDraftRecoveryStorage storage = MemoryDraftRecoveryStorage();
    final DraftRecoveryController controller = DraftRecoveryController(
      preferences: preferences,
      layers: layers,
      shellProvider: shellProvider,
      storage: storage,
      encoder: (final LayersProvider _) async => <int>[1, 2, 3],
      saveDebounce: Duration.zero,
    );

    await controller.initialize();

    layers.markAllChanged();
    await tester.pump();

    expect(storage.bytes, <int>[1, 2, 3]);
    expect(await preferences.getRecoveryDraftSourceFilePath(), '/tmp/example.ora');

    layers.clearHasChanged();
    await tester.pump();

    expect(storage.bytes, isNull);
    expect(await preferences.getRecoveryDraftSourceFilePath(), isNull);

    controller.dispose();
  });

  testWidgets('restore loads the stored recovery draft', (final WidgetTester tester) async {
    final AppPreferences preferences = await createRecoveryTestPreferences();
    final LayersProvider layers = createRecoveryTestLayers();
    final ShellProvider shellProvider = ShellProvider();
    final MemoryDraftRecoveryStorage storage = MemoryDraftRecoveryStorage(
      bytes: Uint8List.fromList(<int>[9, 8, 7]),
    );
    final AppProvider appProvider = AppProvider(preferences: preferences);
    Uint8List? restoredBytes;
    final DraftRecoveryController controller = DraftRecoveryController(
      preferences: preferences,
      layers: layers,
      shellProvider: shellProvider,
      storage: storage,
      restorer: (final LayersProvider targetLayers, final Uint8List bytes) async {
        restoredBytes = bytes;
        targetLayers.addBottom('Recovered Layer');
      },
      saveDebounce: Duration.zero,
    );

    await preferences.setRecoveryDraftSourceFilePath('/tmp/recovered.ora');
    await controller.initialize();
    await controller.restoreDraftIfAvailable(appProvider: appProvider);
    await tester.pump();

    expect(restoredBytes, Uint8List.fromList(<int>[9, 8, 7]));
    expect(shellProvider.loadedFileName, '/tmp/recovered.ora');
    expect(layers.length, 1);
    expect(layers.list.single.name, 'Recovered Layer');
    expect(layers.hasChanged, true);

    controller.dispose();
  });

  testWidgets('automatic restore loads the stored recovery draft without a prompt', (final WidgetTester tester) async {
    final AppPreferences preferences = await createRecoveryTestPreferences();
    final LayersProvider layers = createRecoveryTestLayers();
    final ShellProvider shellProvider = ShellProvider();
    final MemoryDraftRecoveryStorage storage = MemoryDraftRecoveryStorage(
      bytes: Uint8List.fromList(<int>[6, 5, 4]),
    );
    final AppProvider appProvider = AppProvider(preferences: preferences);
    Uint8List? restoredBytes;
    final DraftRecoveryController controller = DraftRecoveryController(
      preferences: preferences,
      layers: layers,
      shellProvider: shellProvider,
      storage: storage,
      restorer: (final LayersProvider targetLayers, final Uint8List bytes) async {
        restoredBytes = bytes;
        targetLayers.addBottom('Recovered Automatically');
      },
      saveDebounce: Duration.zero,
    );

    await preferences.setRecoveryDraftSourceFilePath('/tmp/auto.ora');
    await controller.initialize();

    await controller.restoreDraftIfAvailable(appProvider: appProvider);
    await tester.pump();

    expect(restoredBytes, Uint8List.fromList(<int>[6, 5, 4]));
    expect(shellProvider.loadedFileName, '/tmp/auto.ora');
    expect(layers.length, 1);
    expect(layers.list.single.name, 'Recovered Automatically');
    expect(layers.hasChanged, true);

    controller.dispose();
  });

  testWidgets('restore discards empty stored recovery drafts', (final WidgetTester tester) async {
    final AppPreferences preferences = await createRecoveryTestPreferences();
    final LayersProvider layers = createRecoveryTestLayers();
    final ShellProvider shellProvider = ShellProvider();
    final MemoryDraftRecoveryStorage storage = MemoryDraftRecoveryStorage(
      bytes: Uint8List(0),
    );
    final AppProvider appProvider = AppProvider(preferences: preferences);
    final DraftRecoveryController controller = DraftRecoveryController(
      preferences: preferences,
      layers: layers,
      shellProvider: shellProvider,
      storage: storage,
      saveDebounce: Duration.zero,
    );

    await preferences.setRecoveryDraftSourceFilePath('/tmp/discard.ora');
    await controller.initialize();
    await controller.restoreDraftIfAvailable(appProvider: appProvider);
    await tester.pump();

    expect(storage.bytes, isNull);
    expect(await preferences.getRecoveryDraftSourceFilePath(), isNull);

    controller.dispose();
  });

  testWidgets('restoreDraftIfAvailable clears pref when no draft exists', (final WidgetTester tester) async {
    final AppPreferences preferences = await createRecoveryTestPreferences();
    final LayersProvider layers = createRecoveryTestLayers();
    final ShellProvider shellProvider = ShellProvider();
    final MemoryDraftRecoveryStorage storage = MemoryDraftRecoveryStorage();
    final AppProvider appProvider = AppProvider(preferences: preferences);
    final DraftRecoveryController controller = DraftRecoveryController(
      preferences: preferences,
      layers: layers,
      shellProvider: shellProvider,
      storage: storage,
      saveDebounce: Duration.zero,
    );

    await preferences.setRecoveryDraftSourceFilePath('/tmp/phantom.ora');
    await controller.initialize();
    await controller.restoreDraftIfAvailable(appProvider: appProvider);
    await tester.pump();

    expect(await preferences.getRecoveryDraftSourceFilePath(), isNull);
    controller.dispose();
  });

  testWidgets('discardDraft clears storage and preferences', (final WidgetTester tester) async {
    final AppPreferences preferences = await createRecoveryTestPreferences();
    final LayersProvider layers = createRecoveryTestLayers();
    final ShellProvider shellProvider = ShellProvider();
    final MemoryDraftRecoveryStorage storage = MemoryDraftRecoveryStorage(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );
    final DraftRecoveryController controller = DraftRecoveryController(
      preferences: preferences,
      layers: layers,
      shellProvider: shellProvider,
      storage: storage,
      saveDebounce: Duration.zero,
    );

    await preferences.setRecoveryDraftSourceFilePath('/tmp/discard_me.ora');
    await controller.initialize();
    await controller.discardDraft();
    await tester.pump();

    expect(storage.bytes, isNull);
    expect(await preferences.getRecoveryDraftSourceFilePath(), isNull);
    controller.dispose();
  });

  testWidgets('didChangeAppLifecycleState flushes on paused', (final WidgetTester tester) async {
    final AppPreferences preferences = await createRecoveryTestPreferences();
    final LayersProvider layers = createRecoveryTestLayers();
    final ShellProvider shellProvider = ShellProvider()..loadedFileName = '/tmp/lifecycle.ora';
    final MemoryDraftRecoveryStorage storage = MemoryDraftRecoveryStorage();
    final DraftRecoveryController controller = DraftRecoveryController(
      preferences: preferences,
      layers: layers,
      shellProvider: shellProvider,
      storage: storage,
      encoder: (final LayersProvider _) async => <int>[4, 5, 6],
      saveDebounce: const Duration(seconds: 60),
    );

    await controller.initialize();

    // Mark changed but don't trigger flush via debounce.
    layers.markAllChanged();
    // Simulate lifecycle event.
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();

    expect(storage.bytes, isNotNull);
    controller.dispose();
  });

  testWidgets('reconcileDraft skips delete during startup when no writes occurred', (final WidgetTester tester) async {
    final AppPreferences preferences = await createRecoveryTestPreferences();
    final LayersProvider layers = createRecoveryTestLayers();
    final ShellProvider shellProvider = ShellProvider();
    final MemoryDraftRecoveryStorage storage = MemoryDraftRecoveryStorage(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );
    final DraftRecoveryController controller = DraftRecoveryController(
      preferences: preferences,
      layers: layers,
      shellProvider: shellProvider,
      storage: storage,
      saveDebounce: Duration.zero,
    );

    await controller.initialize();
    // layers.hasChanged is false and startup check is pending — reconcile should skip delete.
    await controller.flushNow();
    await tester.pump();

    // The draft should NOT be deleted because startup recovery check is still pending.
    expect(storage.bytes, isNotNull);
    controller.dispose();
  });

  testWidgets('reconcileDraft deletes draft when not changed after startup check', (final WidgetTester tester) async {
    final AppPreferences preferences = await createRecoveryTestPreferences();
    final LayersProvider layers = createRecoveryTestLayers();
    final ShellProvider shellProvider = ShellProvider();
    final MemoryDraftRecoveryStorage storage = MemoryDraftRecoveryStorage(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );
    final AppProvider appProvider = AppProvider(preferences: preferences);
    final DraftRecoveryController controller = DraftRecoveryController(
      preferences: preferences,
      layers: layers,
      shellProvider: shellProvider,
      storage: storage,
      encoder: (final LayersProvider _) async => <int>[7, 8, 9],
      restorer: (final LayersProvider targetLayers, final Uint8List bytes) async {
        targetLayers.addBottom('Restored');
      },
      saveDebounce: Duration.zero,
    );

    await controller.initialize();
    // Complete the startup recovery check.
    await controller.restoreDraftIfAvailable(appProvider: appProvider);
    await tester.pump();

    // Now clear changes and flush — should delete draft.
    layers.clearHasChanged();
    await controller.flushNow();
    await tester.pump();

    expect(storage.bytes, isNull);
    controller.dispose();
  });
}
