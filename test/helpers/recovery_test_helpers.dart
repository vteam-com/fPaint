import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/recovery/draft_recovery_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Canonical recovery test canvas size to keep scenarios deterministic.
const Size recoveryTestCanvasSize = Size(100, 100);

/// Creates test preferences backed by mocked shared preferences storage.
Future<AppPreferences> createRecoveryTestPreferences() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final AppPreferences preferences = AppPreferences();
  await preferences.getPref();
  return preferences;
}

/// Resets an existing app provider layer stack to a clean white canvas.
void resetAppProviderLayersForRecovery(
  final AppProvider appProvider, {
  final Size canvasSize = recoveryTestCanvasSize,
}) {
  appProvider.layers.list.clear();
  appProvider.layers.size = canvasSize;
  appProvider.layers.addWhiteBackgroundLayer();
  appProvider.layers.selectedLayerIndex = 0;
  appProvider.layers.clearHasChanged();
}

/// Creates a fresh layers provider prepared for recovery tests.
LayersProvider createRecoveryTestLayers({
  final Size canvasSize = recoveryTestCanvasSize,
}) {
  final LayersProvider layers = LayersProvider();
  layers.list.clear();
  layers.size = canvasSize;
  layers.addWhiteBackgroundLayer();
  layers.selectedLayerIndex = 0;
  layers.clearHasChanged();
  return layers;
}

/// In-memory draft recovery storage for deterministic tests.
class MemoryDraftRecoveryStorage implements DraftRecoveryStorage {
  MemoryDraftRecoveryStorage({this.bytes});

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
