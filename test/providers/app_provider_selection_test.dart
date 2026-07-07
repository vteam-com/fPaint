import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/image_placement_layer_restore_state.dart';
import 'package:fpaint/models/selection_effect.dart';
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

  Future<Image> createFilledLayerImage({
    required final int width,
    required final int height,
    required final Color color,
  }) async {
    final PictureRecorder recorder = PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = color,
    );
    return recorder.endRecording().toImage(width, height);
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

    test('line mode creates path on start', () {
      appProvider.selectorModel.mode = SelectorMode.line;
      appProvider.selectorCreationStart(const Offset(10, 10));
      expect(appProvider.selectorModel.isDrawing, isTrue);
      expect(appProvider.selectorModel.path1, isNotNull);
      expect(appProvider.selectorModel.points, <Offset>[const Offset(10, 10)]);
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

    test('end ignores non-finite drag points without throwing', () {
      appProvider.selectorModel.mode = SelectorMode.rectangle;
      appProvider.selectorCreationStart(const Offset(10, 10));
      appProvider.selectorCreationAdditionalPoint(const Offset(40, 40));
      appProvider.selectorCreationEnd();

      final Rect before = appProvider.selectorModel.boundingRect;

      appProvider.selectorModel.math = SelectorMath.add;
      appProvider.selectorCreationStart(const Offset(50, 50));
      appProvider.selectorCreationAdditionalPoint(const Offset(double.nan, 80));

      expect(appProvider.selectorCreationEnd, returnsNormally);
      expect(appProvider.selectorModel.boundingRect, before);
      expect(appProvider.selectorModel.isDrawing, isFalse);
    });

    test('line mode stays active after pointer end until it closes', () {
      appProvider.selectorModel.mode = SelectorMode.line;
      appProvider.selectorCreationStart(const Offset(10, 10));

      appProvider.selectorCreationEnd();

      expect(appProvider.selectorModel.isDrawing, isTrue);
      expect(appProvider.selectorModel.points, hasLength(1));
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

    test('line mode ignores drag updates between clicks', () {
      appProvider.selectorModel.mode = SelectorMode.line;
      appProvider.selectorCreationStart(const Offset(10, 10));
      appProvider.selectorCreationAdditionalPoint(const Offset(80, 10));
      expect(appProvider.selectorModel.path1, isNotNull);
      expect(appProvider.selectorModel.points, <Offset>[const Offset(10, 10)]);
    });

    test('wand mode ignores additional points', () {
      appProvider.selectorModel.mode = SelectorMode.wand;
      // Start doesn't add points for wand (it uses async fill)
      appProvider.selectorCreationAdditionalPoint(const Offset(50, 50));
      // Should not throw
    });
  });

  group('selectorCreationPreview', () {
    test('line mode previews the next edge while drawing', () {
      appProvider.selectorModel.mode = SelectorMode.line;
      appProvider.selectorCreationStart(const Offset(10, 10));
      appProvider.selectorCreationStart(const Offset(80, 10));

      appProvider.selectorCreationPreview(const Offset(80, 80));

      expect(appProvider.selectorModel.path1, isNotNull);
      expect(appProvider.selectorModel.boundingRect, const Rect.fromLTWH(10, 10, 70, 70));
    });

    test('line mode closes when clicking back near the first point', () {
      appProvider.selectorModel.mode = SelectorMode.line;
      appProvider.selectorCreationStart(const Offset(10, 10));
      appProvider.selectorCreationStart(const Offset(80, 10));
      appProvider.selectorCreationStart(const Offset(80, 80));

      appProvider.selectorCreationStart(const Offset(12, 12));

      expect(appProvider.selectorModel.isDrawing, isFalse);
      expect(appProvider.selectorModel.points, isEmpty);
      expect(appProvider.selectorModel.path1, isNotNull);
      expect(appProvider.selectorModel.boundingRect, const Rect.fromLTWH(10, 10, 70, 70));
    });

    test('line mode closes when explicitly requested after three points', () {
      appProvider.selectorModel.mode = SelectorMode.line;
      appProvider.selectorCreationStart(const Offset(10, 10));
      appProvider.selectorCreationStart(const Offset(80, 10));
      appProvider.selectorCreationStart(const Offset(80, 80));

      final bool didClose = appProvider.selectorCreationClosePolygon();

      expect(didClose, isTrue);
      expect(appProvider.selectorModel.isDrawing, isFalse);
      expect(appProvider.selectorModel.points, isEmpty);
      expect(appProvider.selectorModel.path1, isNotNull);
      expect(appProvider.selectorModel.boundingRect, const Rect.fromLTWH(10, 10, 70, 70));
    });

    test('line mode does not close explicitly before three points', () {
      appProvider.selectorModel.mode = SelectorMode.line;
      appProvider.selectorCreationStart(const Offset(10, 10));
      appProvider.selectorCreationStart(const Offset(80, 10));

      final bool didClose = appProvider.selectorCreationClosePolygon();

      expect(didClose, isFalse);
      expect(appProvider.selectorModel.isDrawing, isTrue);
      expect(appProvider.selectorModel.points, <Offset>[const Offset(10, 10), const Offset(80, 10)]);
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
    test('layerModifyModeListenable only notifies when modify mode enters or exits', () async {
      int providerNotifications = 0;
      int layerModifyModeNotifications = 0;

      appProvider.addListener(() => providerNotifications++);
      appProvider.layerModifyModeListenable.addListener(() => layerModifyModeNotifications++);

      appProvider.brushColor = const Color(0xFF00FF00);

      expect(providerNotifications, 1);
      expect(layerModifyModeNotifications, 0);

      providerNotifications = 0;
      await appProvider.modifySelectedLayer();

      expect(appProvider.isLayerModifyMode, isTrue);
      expect(layerModifyModeNotifications, 1);

      providerNotifications = 0;
      appProvider.brushColor = const Color(0xFFFF0000);

      expect(providerNotifications, 1);
      expect(layerModifyModeNotifications, 1);

      appProvider.cancelLayerModifySession();

      expect(appProvider.isLayerModifyMode, isFalse);
      expect(layerModifyModeNotifications, 2);
    });

    test('does not enter modify mode when the selected layer is locked', () async {
      appProvider.layers.selectedLayer.isLocked = true;

      await appProvider.modifySelectedLayer();

      expect(appProvider.selectorModel.isVisible, isFalse);
      expect(appProvider.transformModel.isVisible, isFalse);
      expect(appProvider.imagePlacementModel.layerRestoreState, isNull);
    });

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

    test('starts same-layer duplicate in transform mode at the selection bounds', () async {
      appProvider.selectAll();
      final Rect selectionBounds = appProvider.selectorModel.path1!.getBounds();

      await appProvider.regionDuplicateSameLayer();

      expect(appProvider.imagePlacementModel.commitMode, ImagePlacementCommitMode.selectedLayer);
      expect(appProvider.imagePlacementModel.layerRestoreState, isNotNull);
      expect(appProvider.transformModel.isVisible, isTrue);
      expect(appProvider.transformModel.source, TransformSessionSource.duplicateSelection);
      expect(appProvider.transformModel.quadBounds, selectionBounds);
    });

    test('does not start same-layer duplicate when the selected layer is locked', () async {
      appProvider.selectAll();
      appProvider.layers.selectedLayer.isLocked = true;

      await appProvider.regionDuplicateSameLayer();

      expect(appProvider.transformModel.isVisible, isFalse);
      expect(appProvider.imagePlacementModel.layerRestoreState, isNull);
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

    test('confirming same-layer duplicate transform keeps the result on the selected layer', () async {
      appProvider.selectAll();
      final Rect selectionBounds = appProvider.selectorModel.path1!.getBounds();
      final int originalLayerCount = appProvider.layers.length;
      final int originalActionCount = appProvider.layers.selectedLayer.actionStack.length;

      await appProvider.regionDuplicateSameLayer();
      await appProvider.confirmTransform();

      expect(appProvider.layers.length, originalLayerCount);
      expect(appProvider.layers.selectedLayer.actionStack.length, originalActionCount + 1);
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

    test('duplicate move offsets the same-layer transform without latching translate mode', () async {
      appProvider.selectAll();
      final Rect selectionBounds = appProvider.selectorModel.path1!.getBounds();
      const Offset moveOffset = Offset(20, 10);

      await appProvider.regionDuplicateMove(moveOffset, onNewLayer: false);

      expect(appProvider.imagePlacementModel.commitMode, ImagePlacementCommitMode.selectedLayer);
      expect(appProvider.imagePlacementModel.layerRestoreState, isNotNull);
      expect(appProvider.transformModel.isVisible, isTrue);
      expect(appProvider.transformModel.source, TransformSessionSource.duplicateSelection);
      expect(appProvider.transformModel.isTranslateMode, isFalse);
      expect(appProvider.transformModel.handleSet, TransformHandleSet.corners);
      expect(appProvider.transformModel.quadBounds.topLeft, selectionBounds.topLeft + moveOffset);
    });

    test('duplicate move offsets the new-layer transform without latching translate mode', () async {
      appProvider.selectAll();
      final Rect selectionBounds = appProvider.selectorModel.path1!.getBounds();
      const Offset moveOffset = Offset(20, 10);

      await appProvider.regionDuplicateMove(moveOffset);

      expect(appProvider.imagePlacementModel.commitMode, ImagePlacementCommitMode.newLayer);
      expect(appProvider.imagePlacementModel.layerRestoreState, isNull);
      expect(appProvider.transformModel.isVisible, isTrue);
      expect(appProvider.transformModel.source, TransformSessionSource.duplicateSelection);
      expect(appProvider.transformModel.isTranslateMode, isFalse);
      expect(appProvider.transformModel.handleSet, TransformHandleSet.corners);
      expect(appProvider.transformModel.quadBounds.topLeft, selectionBounds.topLeft + moveOffset);
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

    test('does not record an action when the selected layer is locked', () {
      appProvider.selectAll();
      appProvider.layers.selectedLayer.isLocked = true;

      appProvider.regionErase();

      expect(appProvider.undoProvider.canUndo, isFalse);
    });

    test('records an action when path1 exists', () {
      appProvider.selectAll();
      appProvider.regionErase();
      expect(appProvider.undoProvider.canUndo, isTrue);
    });
  });

  group('startTransform', () {
    test('does not start when the selected layer is locked', () async {
      appProvider.selectAll();
      appProvider.layers.selectedLayer.isLocked = true;

      await appProvider.startTransform();

      expect(appProvider.transformModel.isVisible, isFalse);
    });
  });

  group('startEffectPreview', () {
    test('does not start when the selected layer is locked', () async {
      appProvider.selectAll();
      appProvider.layers.selectedLayer.isLocked = true;

      await appProvider.startEffectPreview(SelectionEffect.blur);

      expect(appProvider.effectPreviewModel.isVisible, isFalse);
    });

    test('targets the whole layer when no selection is visible', () async {
      final int canvasWidth = appProvider.layers.width.toInt();
      final int canvasHeight = appProvider.layers.height.toInt();
      final Image layerImage = await createFilledLayerImage(
        width: canvasWidth,
        height: canvasHeight,
        color: const Color(0xFF112233),
      );
      addTearDown(layerImage.dispose);
      appProvider.layers.selectedLayer.addImage(imageToAdd: layerImage);

      expect(appProvider.selectorModel.isVisible, isFalse);

      await appProvider.startEffectPreview(SelectionEffect.blur);

      expect(appProvider.effectPreviewModel.isVisible, isTrue);
      // A layer-wide effect must not leave a lingering select-all region.
      expect(appProvider.selectorModel.isVisible, isFalse);

      final Rect bounds = appProvider.effectPreviewModel.bounds!;
      expect(bounds.width, appProvider.layers.width);
      expect(bounds.height, appProvider.layers.height);

      await appProvider.confirmEffectPreview();

      final UserActionDrawing committedAction = appProvider.layers.selectedLayer.actionStack.last;
      expect(committedAction.action, ActionType.image);
      expect(appProvider.effectPreviewModel.isVisible, isFalse);
    });

    test('masks preview and commit to the selection shape', () async {
      final int canvasWidth = appProvider.layers.width.toInt();
      final int canvasHeight = appProvider.layers.height.toInt();
      final Image layerImage = await createFilledLayerImage(
        width: canvasWidth,
        height: canvasHeight,
        color: const Color(0xFF000000),
      );
      addTearDown(layerImage.dispose);
      appProvider.layers.selectedLayer.addImage(imageToAdd: layerImage);

      final Path selectionPath = Path()
        ..moveTo(0, 0)
        ..lineTo(canvasWidth.toDouble(), 0)
        ..lineTo(0, canvasHeight.toDouble())
        ..close();
      appProvider.selectorModel.isVisible = true;
      appProvider.selectorModel.path1 = selectionPath;

      await appProvider.startEffectPreview(SelectionEffect.blur);

      final Image? previewImage = appProvider.effectPreviewModel.previewImage;
      expect(previewImage, isNotNull);

      final ByteData? previewData = await previewImage!.toByteData(
        format: ImageByteFormat.rawRgba,
      );
      expect(previewData, isNotNull);

      final int previewInsidePixelBase = ((AppMath.one * previewImage.width) + AppMath.one) * AppMath.bytesPerPixel;
      final int previewOutsidePixelBase =
          (((previewImage.height - AppMath.one) * previewImage.width) + (previewImage.width - AppMath.one)) *
          AppMath.bytesPerPixel;
      expect(
        previewData!.getUint8(previewInsidePixelBase + AppEffects.alphaChannelIndex),
        greaterThan(AppMath.zero),
      );
      expect(
        previewData.getUint8(previewOutsidePixelBase + AppEffects.alphaChannelIndex),
        AppMath.zero,
      );

      await appProvider.confirmEffectPreview();

      final UserActionDrawing committedAction = appProvider.layers.selectedLayer.actionStack.last;
      expect(committedAction.action, ActionType.image);
      final Image committedImage = committedAction.image!;
      final ByteData? committedData = await committedImage.toByteData(
        format: ImageByteFormat.rawRgba,
      );
      expect(committedData, isNotNull);

      final int committedInsidePixelBase = ((AppMath.one * committedImage.width) + AppMath.one) * AppMath.bytesPerPixel;
      final int committedOutsidePixelBase =
          (((committedImage.height - AppMath.one) * committedImage.width) + (committedImage.width - AppMath.one)) *
          AppMath.bytesPerPixel;
      expect(
        committedData!.getUint8(committedInsidePixelBase + AppEffects.alphaChannelIndex),
        greaterThan(AppMath.zero),
      );
      expect(
        committedData.getUint8(committedOutsidePixelBase + AppEffects.alphaChannelIndex),
        AppMath.zero,
      );
    });
  });

  group('effect brush', () {
    test('arming an effect exposes it and disarming clears it', () {
      appProvider.armEffectBrush(SelectionEffect.blur);
      expect(appProvider.effectBrushModel.isArmed, isTrue);
      expect(appProvider.effectBrushModel.effect, SelectionEffect.blur);

      appProvider.setEffectBrushStrength(AppEffects.maxIntensity);
      expect(appProvider.effectBrushModel.strength, AppEffects.maxIntensity);

      appProvider.disarmEffectBrush();
      expect(appProvider.effectBrushModel.isArmed, isFalse);
    });

    test('selecting a gesture tool disarms the effect brush (one active tool)', () {
      appProvider.armEffectBrush(SelectionEffect.sharpness);
      expect(appProvider.effectBrushModel.isArmed, isTrue);

      // Picking any tool cancels the armed effect brush so a stroke is never
      // ambiguous (gesture tool vs. effect brush).
      appProvider.selectedAction = ActionType.brush;
      expect(appProvider.selectedAction, ActionType.brush);
      expect(appProvider.effectBrushModel.isArmed, isFalse);
    });

    test('commitEffectBrushStroke overlays a masked effect patch as one undoable action', () async {
      final int canvasWidth = appProvider.layers.width.toInt();
      final int canvasHeight = appProvider.layers.height.toInt();
      final Image layerImage = await createFilledLayerImage(
        width: canvasWidth,
        height: canvasHeight,
        color: const Color(0xFF3366AA),
      );
      addTearDown(layerImage.dispose);
      appProvider.layers.selectedLayer.addImage(imageToAdd: layerImage);

      final int actionsBefore = appProvider.layers.selectedLayer.actionStack.length;

      await appProvider.commitEffectBrushStroke(
        effect: SelectionEffect.blur,
        strength: AppEffects.defaultIntensity,
        size: AppEffects.minSize,
        strokePoints: <Offset>[const Offset(20, 20), const Offset(80, 60)],
        strokeBounds: const Rect.fromLTRB(20, 20, 80, 60),
        brushSize: 30,
        clipPath: null,
      );

      expect(appProvider.layers.selectedLayer.actionStack.length, actionsBefore + 1);
      final UserActionDrawing committed = appProvider.layers.selectedLayer.actionStack.last;
      expect(committed.action, ActionType.image);
      expect(committed.image, isNotNull);
      expect(appProvider.undoProvider.canUndo, isTrue);

      // The patch must be masked to the brushed band: opaque along the stroke,
      // transparent in the region corner away from it (guards against the
      // whole-region-rectangle masking bug).
      final Image patch = committed.image!;
      final ByteData patchData = (await patch.toByteData(format: ImageByteFormat.rawRgba))!;
      int alphaAt(final int x, final int y) => patchData.getUint8(
        (((y * patch.width) + x) * AppMath.bytesPerPixel) + AppEffects.alphaChannelIndex,
      );
      expect(alphaAt(45, 35), greaterThan(AppMath.zero));
      expect(alphaAt(2, 2), AppMath.zero);

      appProvider.undoProvider.undo();
      expect(appProvider.layers.selectedLayer.actionStack.length, actionsBefore);
    });

    test('commitEffectBrushStroke keeps the band continuous across joints (no beading)', () async {
      // Regression: on a fast / small-brush stroke the sampled points are spaced
      // apart (the sampler never interpolates), so the band relies on the quads
      // that bridge consecutive discs. If those quads wind opposite to the discs,
      // the non-zero fill cancels their overlap into a hole ring at every joint
      // and the stroke renders as separated circles. The whole stroke centreline
      // must stay opaque.
      final int canvasWidth = appProvider.layers.width.toInt();
      final int canvasHeight = appProvider.layers.height.toInt();
      final Image layerImage = await createFilledLayerImage(
        width: canvasWidth,
        height: canvasHeight,
        color: const Color(0xFFCC5533),
      );
      addTearDown(layerImage.dispose);
      appProvider.layers.selectedLayer.addImage(imageToAdd: layerImage);

      // brushSize 20 → radius 10.
      // Points 30 px apart (> disc diameter): discs alone leave gaps, so the
      // bridging quads are the only thing keeping the centreline continuous.
      await appProvider.commitEffectBrushStroke(
        effect: SelectionEffect.grayscale,
        strength: AppEffects.maxIntensity,
        size: AppEffects.minSize,
        strokePoints: <Offset>[const Offset(20, 20), const Offset(50, 20), const Offset(80, 20)],
        strokeBounds: const Rect.fromLTRB(20, 20, 80, 20),
        brushSize: 20,
        clipPath: null,
      );

      final UserActionDrawing committed = appProvider.layers.selectedLayer.actionStack.last;
      final Image patch = committed.image!;
      final ByteData patchData = (await patch.toByteData(format: ImageByteFormat.rawRgba))!;
      // Patch region origin is the stroke bounds inflated by one radius, floored.
      const int originX = 20 - 10; // stroke left - radius
      const int originY = 20 - 10; // stroke top - radius
      int alphaAt(final int canvasX, final int canvasY) => patchData.getUint8(
        ((((canvasY - originY) * patch.width) + (canvasX - originX)) * AppMath.bytesPerPixel) +
            AppEffects.alphaChannelIndex,
      );

      // Every point along the stroke centreline must be opaque — including the
      // disc/quad joints near x=30 and x=60 that the winding bug carved out.
      for (int x = 22; x <= 78; x++) {
        expect(alphaAt(x, 20), greaterThan(AppMath.zero), reason: 'gap in band at x=$x');
      }
    });

    test('commitEffectBrushStroke commits a single-point tap as one dab', () async {
      // A single tap deposits one effect dab (a disc) rather than doing nothing,
      // matching the freehand brushes' single-click behaviour.
      final int canvasWidth = appProvider.layers.width.toInt();
      final int canvasHeight = appProvider.layers.height.toInt();
      final Image layerImage = await createFilledLayerImage(
        width: canvasWidth,
        height: canvasHeight,
        color: const Color(0xFFCC5533),
      );
      addTearDown(layerImage.dispose);
      appProvider.layers.selectedLayer.addImage(imageToAdd: layerImage);

      final int actionsBefore = appProvider.layers.selectedLayer.actionStack.length;

      // brushSize 20 → radius 10; a single point paints one radius-10 disc.
      await appProvider.commitEffectBrushStroke(
        effect: SelectionEffect.grayscale,
        strength: AppEffects.maxIntensity,
        size: AppEffects.minSize,
        strokePoints: <Offset>[const Offset(20, 20)],
        strokeBounds: const Rect.fromLTRB(20, 20, 21, 21),
        brushSize: 20,
        clipPath: null,
      );

      expect(appProvider.layers.selectedLayer.actionStack.length, actionsBefore + 1);
      final UserActionDrawing committed = appProvider.layers.selectedLayer.actionStack.last;
      final Image patch = committed.image!;
      final ByteData patchData = (await patch.toByteData(format: ImageByteFormat.rawRgba))!;
      // Patch region origin is the stroke bounds inflated by one radius, floored.
      const int originX = 20 - 10; // stroke left - radius
      const int originY = 20 - 10; // stroke top - radius
      int alphaAt(final int canvasX, final int canvasY) => patchData.getUint8(
        ((((canvasY - originY) * patch.width) + (canvasX - originX)) * AppMath.bytesPerPixel) +
            AppEffects.alphaChannelIndex,
      );
      // Opaque at the dab centre, transparent at the patch corner (~14 px from
      // the centre, outside the radius-10 disc).
      expect(alphaAt(20, 20), greaterThan(AppMath.zero));
      expect(alphaAt(10, 10), AppMath.zero);
    });

    test('commitEffectBrushStroke ignores an empty stroke', () async {
      final int actionsBefore = appProvider.layers.selectedLayer.actionStack.length;

      await appProvider.commitEffectBrushStroke(
        effect: SelectionEffect.blur,
        strength: AppEffects.defaultIntensity,
        size: AppEffects.minSize,
        strokePoints: <Offset>[],
        strokeBounds: const Rect.fromLTRB(10, 10, 11, 11),
        brushSize: 10,
        clipPath: null,
      );

      expect(appProvider.layers.selectedLayer.actionStack.length, actionsBefore);
    });

    test('commitEffectBrushStroke is a safe no-op at centre strength (0)', () async {
      final int canvasWidth = appProvider.layers.width.toInt();
      final int canvasHeight = appProvider.layers.height.toInt();
      final Image layerImage = await createFilledLayerImage(
        width: canvasWidth,
        height: canvasHeight,
        color: const Color(0xFF808080),
      );
      addTearDown(layerImage.dispose);
      appProvider.layers.selectedLayer.addImage(imageToAdd: layerImage);

      final int actionsBefore = appProvider.layers.selectedLayer.actionStack.length;

      // A bipolar effect at centre (0) is a no-op: apply() returns the source
      // image untouched. Must not crash (was "non-genuine Image") and must not
      // commit anything.
      await appProvider.commitEffectBrushStroke(
        effect: SelectionEffect.brightness,
        strength: AppEffects.minIntensity,
        size: AppEffects.minSize,
        strokePoints: <Offset>[const Offset(20, 20), const Offset(80, 60)],
        strokeBounds: const Rect.fromLTRB(20, 20, 80, 60),
        brushSize: 30,
        clipPath: null,
      );

      expect(appProvider.layers.selectedLayer.actionStack.length, actionsBefore);
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

    test('persists across a tool switch and clips the new tool to the selection', () {
      // Make a selection while in selector mode.
      appProvider.activateSelectionAction();
      appProvider.selectAll();
      expect(appProvider.selectorModel.isVisible, isTrue);

      // Switching to a gesture tool must NOT clear the selection.
      appProvider.selectedAction = ActionType.brush;
      expect(appProvider.selectedAction, ActionType.brush);
      expect(appProvider.selectorModel.isVisible, isTrue);

      // A stroke on the gesture tool is clipped to the persistent selection.
      appProvider.recordExecuteDrawingActionToSelectedLayer(
        action: UserActionDrawing(
          positions: <Offset>[const Offset(0, 0), const Offset(10, 10)],
          action: ActionType.brush,
          brush: MyBrush(color: const Color(0xFF000000), size: 5),
        ),
      );

      final UserActionDrawing recorded = appProvider.layers.selectedLayer.actionStack.last;
      expect(recorded.clipPath, isNotNull);
      expect(recorded.clipPath!.getBounds().width, appProvider.layers.width);
    });
  });

  group('crop', () {
    test('registers committed crop textures for reclamation and frees them once orphaned', () async {
      appProvider.selectAll();

      await appProvider.crop();

      // The crop commits a finalImage per layer and must register them (plus any
      // resurrectable originals) with the undo coordinator. Before the fix this
      // list was empty, so the committed crop textures leaked permanently. They
      // are simultaneously live in the layer stacks, so none is disposed yet.
      final List<Image> retained = appProvider.undoProvider.liveRetainedImages.toSet().toList();
      expect(retained, isNotEmpty, reason: 'Crop must register its committed textures');
      for (final Image image in retained) {
        expect(image.debugDisposed, isFalse, reason: 'a live committed crop texture must not be disposed');
      }

      // Orphan every committed texture: drop the layer content that holds the
      // crop results and the undo record that can resurrect them, then run the
      // reachability sweep. Nothing references the crop textures now, so they
      // must be reclaimed rather than leaked. (Driving the sweep directly keeps
      // this independent of the layers<->undo callback wiring, which the default
      // test constructor leaves unlinked; production shares one provider.)
      for (final LayerProvider layer in appProvider.layers.list) {
        layer.actionStack.clear();
        layer.redoStack.clear();
      }
      appProvider.undoProvider.clear();
      appProvider.layers.disposeCommittedImagesIfUnreferenced(retained);
      for (final Image image in retained) {
        expect(image.debugDisposed, isTrue, reason: 'orphaned crop texture must be reclaimed');
      }
    });
  });

  group('dispose', () {
    test('can be disposed without error', () {
      appProvider.dispose();
      // Should not throw
    });
  });
}
