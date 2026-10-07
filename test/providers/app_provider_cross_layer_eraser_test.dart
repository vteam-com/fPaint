import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppProvider appProvider;

  const Offset strokeStart = Offset(10, 10);
  const Offset strokeEnd = Offset(40, 40);

  /// Three layers, top-first: [0] top, [1] middle, [2] background.
  void setUpThreeLayers() {
    appProvider.layers.addTop(name: 'Middle');
    appProvider.layers.addTop(name: 'Top');
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppPreferences preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    appProvider.undoProvider.clear();
    appProvider.selectedAction = ActionType.eraser;
  });

  group('isCrossLayerEraserScope', () {
    test('follows the sticky All layers toggle', () {
      expect(appProvider.isCrossLayerEraserScope, isFalse);

      appProvider.setSelectorAllLayers(true);

      expect(appProvider.isCrossLayerEraserScope, isTrue);
    });
  });

  group('cross-layer eraser stroke', () {
    test('erases every visible unlocked layer with one shared stroke and one undo entry', () {
      setUpThreeLayers();
      appProvider.setSelectorAllLayers(true);

      expect(appProvider.startCrossLayerEraserStroke(strokeStart), isTrue);
      appProvider.extendCrossLayerEraserStroke(strokeEnd);

      final UserActionDrawing shared = appProvider.layers.get(0).actionStack.last;
      for (final LayerProvider layer in appProvider.layers.list) {
        expect(layer.isUserDrawing, isTrue);
        expect(layer.actionStack.single, same(shared));
      }
      expect(shared.action, ActionType.eraser);
      expect(shared.positions.last, strokeEnd);

      appProvider.endCrossLayerEraserStroke();

      expect(appProvider.crossLayerEraser.isActive, isFalse);
      for (final LayerProvider layer in appProvider.layers.list) {
        expect(layer.isUserDrawing, isFalse);
      }

      appProvider.undoAction();
      expect(appProvider.undoProvider.canUndo, isFalse);
      for (final LayerProvider layer in appProvider.layers.list) {
        expect(layer.actionStack, isEmpty);
      }
    });

    test('skips locked and hidden layers', () {
      setUpThreeLayers();
      appProvider.layers.get(0).isLocked = true;
      appProvider.layers.get(1).isVisible = false;
      appProvider.setSelectorAllLayers(true);

      appProvider.startCrossLayerEraserStroke(strokeStart);
      appProvider.endCrossLayerEraserStroke();

      expect(appProvider.layers.get(0).actionStack, isEmpty);
      expect(appProvider.layers.get(1).actionStack, isEmpty);
      expect(appProvider.layers.get(2).actionStack.single.action, ActionType.eraser);
    });

    test('records nothing when every layer is locked or hidden', () {
      setUpThreeLayers();
      appProvider.layers.get(0).isLocked = true;
      appProvider.layers.get(1).isVisible = false;
      appProvider.layers.get(2).isLocked = true;
      appProvider.setSelectorAllLayers(true);

      expect(appProvider.hasCrossLayerEditTargets, isFalse);
      expect(appProvider.startCrossLayerEraserStroke(strokeStart), isFalse);
      expect(appProvider.crossLayerEraser.isActive, isFalse);
      expect(appProvider.undoProvider.canUndo, isFalse);
    });

    test('clips the stroke to a visible selection', () {
      setUpThreeLayers();
      appProvider.setSelectorAllLayers(true);
      appProvider.selectAll();

      appProvider.startCrossLayerEraserStroke(strokeStart);

      expect(appProvider.crossLayerEraser.action!.clipPath, isNotNull);
      appProvider.endCrossLayerEraserStroke();
    });

    test('extend and end are no-ops without an active stroke', () {
      appProvider.extendCrossLayerEraserStroke(strokeEnd);
      appProvider.endCrossLayerEraserStroke();

      expect(appProvider.layers.selectedLayer.actionStack, isEmpty);
      expect(appProvider.undoProvider.canUndo, isFalse);
    });
  });
}
