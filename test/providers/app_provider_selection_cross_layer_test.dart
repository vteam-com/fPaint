import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppProvider appProvider;

  Future<Image> createFilledImage({
    required int width,
    required int height,
    required Color color,
  }) async {
    final PictureRecorder recorder = PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = color,
    );
    return recorder.endRecording().toImage(width, height);
  }

  /// Adds a second layer and paints distinct content on both layers so
  /// cross-layer operations have real per-layer pixels to act on.
  Future<void> setUpTwoContentLayers() async {
    final int width = appProvider.layers.width.toInt();
    final int height = appProvider.layers.height.toInt();

    appProvider.layers.selectedLayer.addImage(
      imageToAdd: await createFilledImage(
        width: width,
        height: height,
        color: const Color(0xFF336699),
      ),
    );
    appProvider.layers.addTop(name: 'Top');
    appProvider.layers
        .get(0)
        .addImage(
          imageToAdd: await createFilledImage(
            width: width ~/ 2,
            height: height ~/ 2,
            color: const Color(0xFF996633),
          ),
        );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppPreferences preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    appProvider.undoProvider.clear();
  });

  group('setSelectorAllLayers', () {
    test('toggles the sticky scope and notifies', () {
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);

      appProvider.setSelectorAllLayers(true);

      expect(appProvider.selectorModel.allLayers, isTrue);
      expect(notifyCount, 1);
    });

    test('is a no-op when the value is unchanged', () {
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);

      appProvider.setSelectorAllLayers(false);

      expect(notifyCount, 0);
    });

    test('scope survives clearing the selection, like the selector mode', () {
      appProvider.setSelectorAllLayers(true);
      appProvider.selectorModel.clear();

      expect(appProvider.selectorModel.allLayers, isTrue);
    });
  });

  group('regionErase with All layers scope', () {
    test('erases every visible unlocked layer in one undo entry', () async {
      await setUpTwoContentLayers();
      appProvider.setSelectorAllLayers(true);
      appProvider.selectAll();

      final List<int> stackLengthsBefore = appProvider.layers.list
          .map((LayerProvider layer) => layer.actionStack.length)
          .toList();

      appProvider.regionErase();

      for (int i = 0; i < appProvider.layers.list.length; i++) {
        final LayerProvider layer = appProvider.layers.get(i);
        expect(layer.actionStack.length, stackLengthsBefore[i] + 1);
        expect(layer.actionStack.last.action, ActionType.cut);
      }

      // One record undoes the cut on every layer at once.
      appProvider.undoAction();
      expect(appProvider.undoProvider.canUndo, isFalse);
      for (int i = 0; i < appProvider.layers.list.length; i++) {
        expect(appProvider.layers.get(i).actionStack.length, stackLengthsBefore[i]);
      }
    });

    test('skips locked and hidden layers', () async {
      await setUpTwoContentLayers();
      appProvider.layers.addTop(name: 'Hidden');
      appProvider.layers.get(0).isVisible = false;
      appProvider.layers.get(1).isLocked = true;
      appProvider.setSelectorAllLayers(true);
      appProvider.selectAll();

      appProvider.regionErase();

      expect(appProvider.layers.get(0).actionStack, isEmpty);
      final List<UserActionDrawing> lockedStack = appProvider.layers.get(1).actionStack;
      expect(lockedStack.where((UserActionDrawing a) => a.action == ActionType.cut), isEmpty);
      expect(appProvider.layers.get(2).actionStack.last.action, ActionType.cut);
    });

    test('records nothing when every layer is locked or hidden', () async {
      await setUpTwoContentLayers();
      appProvider.layers.get(0).isLocked = true;
      appProvider.layers.get(1).isVisible = false;
      appProvider.setSelectorAllLayers(true);
      appProvider.selectAll();

      appProvider.regionErase();

      expect(appProvider.undoProvider.canUndo, isFalse);
    });

    test('does nothing without a selection path', () {
      appProvider.setSelectorAllLayers(true);
      appProvider.selectorModel.path1 = null;

      appProvider.regionErase();

      expect(appProvider.undoProvider.canUndo, isFalse);
    });
  });

  group('regionCut with All layers scope', () {
    test('copies the merged composite then erases all unlocked layers', () async {
      await setUpTwoContentLayers();
      appProvider.setSelectorAllLayers(true);
      appProvider.selectAll();

      await appProvider.regionCut();

      for (final LayerProvider layer in appProvider.layers.list) {
        expect(layer.actionStack.last.action, ActionType.cut);
      }
      expect(appProvider.undoProvider.canUndo, isTrue);
    });
  });

  group('createSelectionImageMerged', () {
    test('renders a selection-bounds sized composite of visible layers', () async {
      await setUpTwoContentLayers();
      appProvider.selectorModel.isVisible = true;
      appProvider.selectorModel.path1 = Path()..addRect(const Rect.fromLTWH(10, 10, 40, 30));

      final Image? merged = await appProvider.createSelectionImageMerged();

      expect(merged, isNotNull);
      expect(merged!.width, 40);
      expect(merged.height, 30);
    });

    test('returns null for empty selection bounds', () async {
      appProvider.selectorModel.isVisible = true;
      appProvider.selectorModel.path1 = Path();

      expect(await appProvider.createSelectionImageMerged(), isNull);
    });
  });

  group('startTransform with All layers scope', () {
    test('lifts one entry per visible unlocked layer and shows the overlay', () async {
      await setUpTwoContentLayers();
      appProvider.setSelectorAllLayers(true);
      appProvider.selectAll();

      await appProvider.startTransform();

      expect(appProvider.transformModel.isVisible, isTrue);
      expect(appProvider.isCrossLayerTransformActive, isTrue);
      expect(appProvider.crossLayerLift, hasLength(2));
    });

    test('excludes locked layers from the lift', () async {
      await setUpTwoContentLayers();
      appProvider.layers.get(0).isLocked = true;
      appProvider.setSelectorAllLayers(true);
      appProvider.selectAll();

      await appProvider.startTransform();

      expect(appProvider.crossLayerLift, hasLength(1));
      expect(appProvider.crossLayerLift!.single.layer, appProvider.layers.get(1));
    });

    test('does not start when every layer is locked', () async {
      await setUpTwoContentLayers();
      for (final LayerProvider layer in appProvider.layers.list) {
        layer.isLocked = true;
      }
      appProvider.setSelectorAllLayers(true);
      appProvider.selectAll();

      await appProvider.startTransform();

      expect(appProvider.transformModel.isVisible, isFalse);
      expect(appProvider.isCrossLayerTransformActive, isFalse);
    });
  });

  group('confirmTransform with All layers scope', () {
    test('commits erase + warped image per layer as one undo entry', () async {
      await setUpTwoContentLayers();
      appProvider.setSelectorAllLayers(true);
      appProvider.selectAll();
      await appProvider.startTransform();

      final List<int> stackLengthsBefore = appProvider.layers.list
          .map((LayerProvider layer) => layer.actionStack.length)
          .toList();

      appProvider.transformModel.moveAll(const Offset(25, 15));
      await appProvider.confirmTransform();

      expect(appProvider.isCrossLayerTransformActive, isFalse);
      expect(appProvider.transformModel.isVisible, isFalse);
      expect(appProvider.selectorModel.isVisible, isFalse);

      for (int i = 0; i < appProvider.layers.list.length; i++) {
        final List<UserActionDrawing> stack = appProvider.layers.get(i).actionStack;
        expect(stack.length, stackLengthsBefore[i] + 2);
        expect(stack[stack.length - 2].action, ActionType.cut);
        expect(stack.last.action, ActionType.image);
        expect(stack.last.positions.first, const Offset(25, 15));
      }

      // The committed warped textures must be registered for reclamation.
      expect(appProvider.undoProvider.liveRetainedImages, isNotEmpty);

      // One undo restores every touched layer at once.
      appProvider.undoAction();
      expect(appProvider.undoProvider.canUndo, isFalse);
      for (int i = 0; i < appProvider.layers.list.length; i++) {
        expect(appProvider.layers.get(i).actionStack.length, stackLengthsBefore[i]);
      }
    });
  });

  group('cancelTransform with All layers scope', () {
    test('disposes the lifted textures and clears the session', () async {
      await setUpTwoContentLayers();
      appProvider.setSelectorAllLayers(true);
      appProvider.selectAll();
      await appProvider.startTransform();

      final List<Image> lifted = appProvider.crossLayerLift!.map((CrossLayerLiftEntry entry) => entry.image).toList();

      appProvider.cancelTransform();

      expect(appProvider.isCrossLayerTransformActive, isFalse);
      expect(appProvider.transformModel.isVisible, isFalse);
      for (final Image image in lifted) {
        expect(image.debugDisposed, isTrue);
      }
    });
  });

  group('layer modify with All layers scope', () {
    test('still floats only the selected layer', () async {
      await setUpTwoContentLayers();
      appProvider.setSelectorAllLayers(true);

      await appProvider.modifySelectedLayer();

      expect(appProvider.transformModel.isVisible, isTrue);
      expect(appProvider.isCrossLayerTransformActive, isFalse);

      appProvider.cancelLayerModifySession();
    });
  });
}
