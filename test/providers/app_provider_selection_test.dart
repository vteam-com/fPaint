import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/image_placement_layer_restore_state.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/transform_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppProvider appProvider;

  Future<Image> createClipboardTestImage() async {
    final PictureRecorder recorder = PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 12, 12),
      Paint()..color = const Color(0xFF000000),
    );
    return recorder.endRecording().toImage(12, 12);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppPreferences preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    appProvider.undoProvider.clear();
  });

  group('selectAll', () {
    test('makes selectorModel visible', () {
      appProvider.selectAll();
      expect(appProvider.selectorModel.isVisible, isTrue);
    });

    test('sets path1 to full canvas rect', () {
      appProvider.selectAll();
      expect(appProvider.selectorModel.path1, isNotNull);
      final Rect bounds = appProvider.selectorModel.path1!.getBounds();
      expect(bounds.width, appProvider.layers.width);
      expect(bounds.height, appProvider.layers.height);
    });
  });

  group('selectorCreationStart / End', () {
    test('rectangle mode creates path on start', () {
      appProvider.selectorModel.mode = SelectorMode.rectangle;
      appProvider.selectorCreationStart(const Offset(10, 10));
      expect(appProvider.selectorModel.isDrawing, isTrue);
      expect(appProvider.selectorModel.isVisible, isTrue);
    });

    test('circle mode creates path on start', () {
      appProvider.selectorModel.mode = SelectorMode.circle;
      appProvider.selectorCreationStart(const Offset(10, 10));
      expect(appProvider.selectorModel.isDrawing, isTrue);
    });

    test('lasso mode creates path on start', () {
      appProvider.selectorModel.mode = SelectorMode.lasso;
      appProvider.selectorCreationStart(const Offset(10, 10));
      expect(appProvider.selectorModel.isDrawing, isTrue);
    });

    test('end stops drawing and applies math', () {
      appProvider.selectorModel.mode = SelectorMode.rectangle;
      appProvider.selectorCreationStart(const Offset(10, 10));
      appProvider.selectorCreationAdditionalPoint(const Offset(50, 50));
      appProvider.selectorCreationEnd();
      expect(appProvider.selectorModel.isDrawing, isFalse);
    });
  });

  group('selectorCreationAdditionalPoint', () {
    test('rectangle mode updates path2 when math is add', () {
      appProvider.selectorModel.mode = SelectorMode.rectangle;
      appProvider.selectorModel.math = SelectorMath.add;
      appProvider.selectorCreationStart(const Offset(10, 10));
      appProvider.selectorCreationAdditionalPoint(const Offset(50, 50));
      expect(appProvider.selectorModel.path2, isNotNull);
    });

    test('lasso mode adds points', () {
      appProvider.selectorModel.mode = SelectorMode.lasso;
      appProvider.selectorCreationStart(const Offset(10, 10));
      appProvider.selectorCreationAdditionalPoint(const Offset(50, 50));
      appProvider.selectorCreationAdditionalPoint(const Offset(30, 80));
      expect(appProvider.selectorModel.points.length, 3);
    });

    test('wand mode ignores additional points', () {
      appProvider.selectorModel.mode = SelectorMode.wand;
      // Start doesn't add points for wand (it uses async fill)
      appProvider.selectorCreationAdditionalPoint(const Offset(50, 50));
      // Should not throw
    });
  });

  group('cancelImagePlacement', () {
    test('clears imagePlacementModel and notifies', () {
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      appProvider.cancelImagePlacement();
      expect(appProvider.imagePlacementModel.image, isNull);
      expect(notifyCount, 1);
    });

    test('restores modified layer state', () async {
      const Color originalBackgroundColor = Color(0xFF000000);
      appProvider.layers.selectedLayer.backgroundColor = originalBackgroundColor;

      await appProvider.modifySelectedLayer();

      expect(appProvider.imagePlacementModel.commitMode, ImagePlacementCommitMode.replaceLayer);
      expect(appProvider.layers.selectedLayer.backgroundColor, originalBackgroundColor);

      appProvider.cancelLayerModifySession();

      expect(appProvider.layers.selectedLayer.backgroundColor, originalBackgroundColor);
      expect(appProvider.transformModel.isVisible, isFalse);
      expect(appProvider.imagePlacementModel.layerRestoreState, isNull);
    });
  });

  group('modifySelectedLayer', () {
    test('selects all, switches to selector, and immediately enters transform mode', () async {
      appProvider.layers.selectedLayer.backgroundColor = const Color(0xFF000000);

      await appProvider.modifySelectedLayer();

      expect(appProvider.selectedAction, ActionType.selector);
      expect(appProvider.selectorModel.isVisible, isTrue);
      expect(appProvider.selectorModel.path1, isNotNull);
      expect(appProvider.imagePlacementModel.isVisible, isFalse);
      expect(appProvider.imagePlacementModel.commitMode, ImagePlacementCommitMode.replaceLayer);
      expect(appProvider.transformModel.isVisible, isTrue);
    });

    test('confirm exits modify session without mutating layer when no transform is applied', () async {
      const Color originalBackgroundColor = Color(0xFF000000);
      final int originalLayerCount = appProvider.layers.length;
      appProvider.layers.selectedLayer.backgroundColor = originalBackgroundColor;

      await appProvider.modifySelectedLayer();
      await appProvider.confirmLayerModifySession();

      expect(appProvider.layers.length, originalLayerCount);
      expect(appProvider.layers.selectedLayer.backgroundColor, originalBackgroundColor);
      expect(appProvider.selectorModel.isVisible, isFalse);
      expect(appProvider.transformModel.isVisible, isFalse);
      expect(appProvider.imagePlacementModel.layerRestoreState, isNull);
    });

    test('cancel exits immediate transform mode and closes modify session', () async {
      appProvider.layers.selectedLayer.backgroundColor = const Color(0xFF000000);

      await appProvider.modifySelectedLayer();

      expect(appProvider.transformModel.isVisible, isTrue);
      expect(appProvider.transformModel.source, TransformSessionSource.selection);

      appProvider.cancelTransform();

      expect(appProvider.transformModel.isVisible, isFalse);
      expect(appProvider.imagePlacementModel.isVisible, isFalse);
      expect(appProvider.imagePlacementModel.layerRestoreState, isNull);
    });

    test('confirming transform applies on selected layer and exits modify session', () async {
      appProvider.layers.selectedLayer.backgroundColor = const Color(0xFF000000);

      await appProvider.modifySelectedLayer();

      appProvider.transformModel.moveCorner(
        TransformModel.topLeftIndex,
        const Offset(-10, -10),
      );

      await appProvider.confirmTransform();

      expect(appProvider.transformModel.isVisible, isFalse);
      expect(appProvider.imagePlacementModel.isVisible, isFalse);
      expect(appProvider.imagePlacementModel.layerRestoreState, isNull);
      expect(appProvider.undoProvider.canUndo, isTrue);
    });
  });

  group('regionDuplicate', () {
    test('starts duplicate in transform mode at the selection bounds', () async {
      appProvider.selectAll();
      final Rect selectionBounds = appProvider.selectorModel.path1!.getBounds();

      await appProvider.regionDuplicate();

      expect(appProvider.imagePlacementModel.image, isNotNull);
      expect(appProvider.imagePlacementModel.isVisible, isFalse);
      expect(appProvider.imagePlacementModel.position, selectionBounds.topLeft);
      expect(appProvider.transformModel.isVisible, isTrue);
      expect(appProvider.transformModel.source, TransformSessionSource.duplicateSelection);
      expect(appProvider.transformModel.quadBounds, selectionBounds);
    });

    test('confirming duplicate transform applies paste directly and keeps result selected', () async {
      appProvider.selectAll();
      final Rect selectionBounds = appProvider.selectorModel.path1!.getBounds();
      final int originalLayerCount = appProvider.layers.length;

      await appProvider.regionDuplicate();
      await appProvider.confirmTransform();

      expect(appProvider.layers.length, originalLayerCount + 1);
      expect(appProvider.transformModel.isVisible, isFalse);
      expect(appProvider.imagePlacementModel.isVisible, isFalse);
      expect(appProvider.selectorModel.isVisible, isTrue);
      expect(appProvider.selectorModel.path1!.getBounds(), selectionBounds);
      expect(appProvider.undoProvider.canUndo, isTrue);
    });

    test('canceling duplicate transform closes the duplicate without showing image placement', () async {
      appProvider.selectAll();
      final Rect selectionBounds = appProvider.selectorModel.path1!.getBounds();

      await appProvider.regionDuplicate();
      appProvider.cancelTransform();

      expect(appProvider.transformModel.isVisible, isFalse);
      expect(appProvider.imagePlacementModel.isVisible, isFalse);
      expect(appProvider.selectorModel.isVisible, isTrue);
      expect(appProvider.selectorModel.path1!.getBounds(), selectionBounds);
    });
  });

  group('paste', () {
    test('starts clipboard paste in transform mode centered on the canvas', () async {
      final Image clipboardImage = await createClipboardTestImage();
      addTearDown(clipboardImage.dispose);
      await copyImageToClipboard(clipboardImage);

      await appProvider.paste();

      final Rect pasteBounds = appProvider.transformModel.quadBounds;
      expect(appProvider.transformModel.isVisible, isTrue);
      expect(appProvider.transformModel.source, TransformSessionSource.clipboardPaste);
      expect(appProvider.imagePlacementModel.isVisible, isFalse);
      expect(pasteBounds.width, clipboardImage.width);
      expect(pasteBounds.height, clipboardImage.height);
      expect(pasteBounds.center, const Offset(512, 384));
    });

    test('confirming clipboard paste applies directly and keeps the pasted image selected', () async {
      final Image clipboardImage = await createClipboardTestImage();
      addTearDown(clipboardImage.dispose);
      await copyImageToClipboard(clipboardImage);
      final int originalLayerCount = appProvider.layers.length;

      await appProvider.paste();
      final Rect pasteBounds = appProvider.transformModel.quadBounds;
      await appProvider.confirmTransform();

      expect(appProvider.layers.length, originalLayerCount + 1);
      expect(appProvider.transformModel.isVisible, isFalse);
      expect(appProvider.imagePlacementModel.isVisible, isFalse);
      expect(appProvider.selectorModel.isVisible, isTrue);
      expect(appProvider.selectorModel.path1!.getBounds(), pasteBounds);
    });
  });

  group('cancelTransform', () {
    test('clears transformModel and notifies', () {
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      appProvider.cancelTransform();
      expect(appProvider.transformModel.sourceImage, isNull);
      expect(notifyCount, 1);
    });
  });

  group('regionErase', () {
    test('does nothing when path1 is null', () {
      appProvider.selectorModel.path1 = null;
      // Should not throw
      appProvider.regionErase();
    });

    test('records an action when path1 exists', () {
      appProvider.selectAll();
      appProvider.regionErase();
      expect(appProvider.undoProvider.canUndo, isTrue);
    });
  });

  group('getPathAdjustToCanvasSizeAndPosition', () {
    test('returns null for null path', () {
      expect(appProvider.getPathAdjustToCanvasSizeAndPosition(null), isNull);
    });

    test('transforms path by canvas offset and scale', () {
      final Path original = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
      appProvider.canvasOffset = const Offset(10, 20);
      appProvider.layers.scale = 2.0;
      final Path? result = appProvider.getPathAdjustToCanvasSizeAndPosition(original);
      expect(result, isNotNull);
      final Rect bounds = result!.getBounds();
      // The path should be scaled and translated
      expect(bounds.left, closeTo(10, 1));
      expect(bounds.top, closeTo(20, 1));
      expect(bounds.width, closeTo(200, 1));
      expect(bounds.height, closeTo(200, 1));
    });
  });

  group('recordExecuteDrawingActionToSelectedLayer', () {
    test('adds undo-able action', () {
      expect(appProvider.undoProvider.canUndo, isFalse);
      appProvider.recordExecuteDrawingActionToSelectedLayer(
        action: UserActionDrawing(
          positions: <Offset>[const Offset(0, 0), const Offset(10, 10)],
          action: ActionType.brush,
          brush: MyBrush(color: const Color(0xFF000000), size: 5),
        ),
      );
      expect(appProvider.undoProvider.canUndo, isTrue);
    });

    test('uses selector path as clipPath when visible', () {
      appProvider.selectAll();
      appProvider.recordExecuteDrawingActionToSelectedLayer(
        action: UserActionDrawing(
          positions: <Offset>[const Offset(0, 0), const Offset(10, 10)],
          action: ActionType.brush,
          brush: MyBrush(color: const Color(0xFF000000), size: 5),
        ),
      );
      expect(appProvider.undoProvider.canUndo, isTrue);
    });
  });

  group('dispose', () {
    test('can be disposed without error', () {
      appProvider.dispose();
      // Should not throw
    });
  });
}
