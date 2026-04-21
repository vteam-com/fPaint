import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/recovery/draft_recovery_controller.dart';
import 'package:fpaint/recovery/draft_recovery_storage.dart';
import 'package:fpaint/widgets/canvas_gesture_handler.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('pointer up flushes a recovery draft immediately', (final WidgetTester tester) async {
    final AppPreferences preferences = await _createPreferences();
    final AppProvider appProvider = AppProvider(preferences: preferences);
    final ShellProvider shellProvider = ShellProvider();
    final _MemoryDraftRecoveryStorage storage = _MemoryDraftRecoveryStorage();
    final DraftRecoveryController controller = DraftRecoveryController(
      preferences: preferences,
      layers: appProvider.layers,
      shellProvider: shellProvider,
      storage: storage,
      encoder: (final LayersProvider _) async => <int>[1, 2, 3],
      saveDebounce: const Duration(seconds: 10),
    );

    _resetLayers(appProvider);
    await controller.initialize();

    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          Provider<DraftRecoveryController>.value(value: controller),
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
}

Future<AppPreferences> _createPreferences() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final AppPreferences preferences = AppPreferences();
  await preferences.getPref();
  return preferences;
}

void _resetLayers(final AppProvider appProvider) {
  appProvider.layers.list.clear();
  appProvider.layers.size = const Size(100, 100);
  appProvider.layers.addWhiteBackgroundLayer();
  appProvider.layers.selectedLayerIndex = 0;
  appProvider.layers.clearHasChanged();
}

class _MemoryDraftRecoveryStorage implements DraftRecoveryStorage {
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
