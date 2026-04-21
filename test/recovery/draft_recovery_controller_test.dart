import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/recovery/draft_recovery_controller.dart';
import 'package:fpaint/recovery/draft_recovery_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('autosave writes and clears the recovery draft', (final WidgetTester tester) async {
    final AppPreferences preferences = await _createPreferences();
    final LayersProvider layers = _resetLayers();
    final ShellProvider shellProvider = ShellProvider()..loadedFileName = '/tmp/example.ora';
    final _MemoryDraftRecoveryStorage storage = _MemoryDraftRecoveryStorage();
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
    final AppPreferences preferences = await _createPreferences();
    final LayersProvider layers = _resetLayers();
    final ShellProvider shellProvider = ShellProvider();
    final _MemoryDraftRecoveryStorage storage = _MemoryDraftRecoveryStorage(
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
    final AppPreferences preferences = await _createPreferences();
    final LayersProvider layers = _resetLayers();
    final ShellProvider shellProvider = ShellProvider();
    final _MemoryDraftRecoveryStorage storage = _MemoryDraftRecoveryStorage(
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
    final AppPreferences preferences = await _createPreferences();
    final LayersProvider layers = _resetLayers();
    final ShellProvider shellProvider = ShellProvider();
    final _MemoryDraftRecoveryStorage storage = _MemoryDraftRecoveryStorage(
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
}

Future<AppPreferences> _createPreferences() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final AppPreferences preferences = AppPreferences();
  await preferences.getPref();
  return preferences;
}

LayersProvider _resetLayers() {
  final LayersProvider layers = LayersProvider();
  layers.list.clear();
  layers.size = const Size(100, 100);
  layers.addWhiteBackgroundLayer();
  layers.selectedLayerIndex = 0;
  layers.clearHasChanged();
  return layers;
}

class _MemoryDraftRecoveryStorage implements DraftRecoveryStorage {
  _MemoryDraftRecoveryStorage({this.bytes});

  Uint8List? bytes;

  @override
  Future<void> deleteDraft() async {
    bytes = null;
  }

  @override
  Future<bool> hasDraft() async {
    return bytes != null;
  }

  @override
  Future<Uint8List?> readDraft() async {
    return bytes;
  }

  @override
  Future<void> writeDraft(final Uint8List nextBytes) async {
    bytes = nextBytes;
  }
}
