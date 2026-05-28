import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/layer_provider.dart';

LayerProvider _createLayer({
  final String name = 'Test',
  final Size size = const Size(100, 100),
}) {
  return LayerProvider(
    name: name,
    size: size,
    onThumbnailChanged: () {},
  );
}

void main() {
  group('LayerProvider coverage', () {
    test('constructor and basic getters', () {
      final LayerProvider layer = _createLayer(name: 'MyLayer');
      expect(layer.name, 'MyLayer');
      expect(layer.size, const Size(100, 100));
      expect(layer.isSelected, false);
      expect(layer.isVisible, true);
      expect(layer.opacity, 1.0);
      expect(layer.count, 0);
      expect(layer.isEmpty, true);
      expect(layer.hasChanged, false);
      expect(layer.isUserDrawing, false);
      expect(layer.blendMode, ui.BlendMode.srcOver);
      expect(layer.preserveAlpha, true);
      expect(layer.backgroundColor, null);
      expect(layer.parentGroupName, '');
      expect(layer.id, '');
      expect(layer.lastUserAction, null);
    });

    test('name setter notifies', () {
      final LayerProvider layer = _createLayer();
      bool notified = false;
      layer.addListener(() => notified = true);
      layer.name = 'Renamed';
      expect(layer.name, 'Renamed');
      expect(notified, true);
    });

    test('isVisible setter clears cache', () {
      final LayerProvider layer = _createLayer();
      layer.isVisible = false;
      expect(layer.isVisible, false);
      layer.isVisible = true;
      expect(layer.isVisible, true);
    });

    test('opacity setter clears cache', () {
      final LayerProvider layer = _createLayer();
      layer.opacity = 0.5;
      expect(layer.opacity, 0.5);
    });

    test('size setter clears cache', () {
      final LayerProvider layer = _createLayer();
      layer.size = const Size(200, 150);
      expect(layer.size, const Size(200, 150));
    });

    test('appendDrawingAction adds to stack', () {
      final LayerProvider layer = _createLayer();
      final UserActionDrawing action = UserActionDrawing(
        action: ActionType.pencil,
        positions: <Offset>[const Offset(0, 0), const Offset(10, 10)],
        brush: MyBrush(color: AppColors.black, size: 2),
        fillColor: AppColors.transparent,
      );
      layer.appendDrawingAction(action);
      expect(layer.count, 1);
      expect(layer.isEmpty, false);
      expect(layer.hasChanged, true);
      expect(layer.lastUserAction, action);
    });

    test('undo and redo', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.pencil,
          positions: <Offset>[const Offset(0, 0), const Offset(5, 5)],
          brush: MyBrush(color: AppColors.black, size: 2),
          fillColor: AppColors.transparent,
        ),
      );
      expect(layer.count, 1);

      layer.undo();
      expect(layer.count, 0);
      expect(layer.redoStack.length, 1);

      layer.redo();
      expect(layer.count, 1);
      expect(layer.redoStack.length, 0);
    });

    test('undo on empty does nothing', () {
      final LayerProvider layer = _createLayer();
      layer.undo();
      expect(layer.count, 0);
    });

    test('redo on empty does nothing', () {
      final LayerProvider layer = _createLayer();
      layer.redo();
      expect(layer.count, 0);
    });

    test('lastActionAppendPosition', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.brush,
          positions: <Offset>[const Offset(0, 0)],
          brush: MyBrush(color: AppColors.black, size: 2),
          fillColor: AppColors.transparent,
        ),
      );
      layer.lastActionAppendPosition(position: const Offset(20, 20));
      expect(layer.actionStack.last.positions.length, 2);
    });

    test('addImage creates image action', () async {
      final LayerProvider layer = _createLayer();
      final ui.Image testImage = await _createTestImage(50, 50);
      final UserActionDrawing action = layer.addImage(imageToAdd: testImage);
      expect(action.action, ActionType.image);
      expect(layer.count, 1);
      expect(action.image, testImage);
    });

    test('addImage with offset', () async {
      final LayerProvider layer = _createLayer();
      final ui.Image testImage = await _createTestImage(30, 30);
      final UserActionDrawing action = layer.addImage(
        imageToAdd: testImage,
        offset: const Offset(10, 20),
      );
      expect(action.positions.first, const Offset(10, 20));
      expect(action.positions.last, const Offset(40, 50));
    });

    test('offset shifts positions', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.pencil,
          positions: <Offset>[const Offset(10, 10), const Offset(20, 20)],
          brush: MyBrush(color: AppColors.black, size: 2),
          fillColor: AppColors.transparent,
        ),
      );
      layer.offset(const Offset(5, 5));
      expect(layer.actionStack.first.positions.first, const Offset(15, 15));
      expect(layer.actionStack.first.positions.last, const Offset(25, 25));
    });

    test('offset shifts path', () {
      final LayerProvider layer = _createLayer();
      final ui.Path path = ui.Path()..addRect(const Rect.fromLTWH(10, 10, 20, 20));
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.region,
          positions: <Offset>[const Offset(10, 10)],
          brush: MyBrush(color: AppColors.black, size: 2),
          fillColor: AppColors.red,
          path: path,
        ),
      );
      layer.offset(const Offset(5, 5));
      // Path was shifted
      expect(layer.actionStack.first.path, isNotNull);
    });

    test('offset shifts clipPath', () {
      final LayerProvider layer = _createLayer();
      final ui.Path clipPath = ui.Path()..addRect(const Rect.fromLTWH(0, 0, 50, 50));
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.pencil,
          positions: <Offset>[const Offset(10, 10), const Offset(20, 20)],
          brush: MyBrush(color: AppColors.black, size: 2),
          fillColor: AppColors.transparent,
          clipPath: clipPath,
        ),
      );
      layer.offset(const Offset(3, 3));
      expect(layer.actionStack.first.clipPath, isNotNull);
    });

    test('offset shifts textObject', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.text,
          positions: <Offset>[const Offset(10, 10)],
          brush: MyBrush(color: AppColors.black, size: 2),
          fillColor: AppColors.transparent,
          textObject: TextObject(
            text: 'Hello',
            position: const Offset(10, 10),
            color: AppColors.black,
            size: 16,
          ),
        ),
      );
      layer.offset(const Offset(5, 5));
      expect(layer.actionStack.first.textObject!.position, const Offset(15, 15));
    });

    test('scale scales positions', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.pencil,
          positions: <Offset>[const Offset(10, 10), const Offset(20, 20)],
          brush: MyBrush(color: AppColors.black, size: 2),
          fillColor: AppColors.transparent,
        ),
      );
      layer.scale(2.0);
      expect(layer.actionStack.first.positions.first, const Offset(20, 20));
      expect(layer.actionStack.first.positions.last, const Offset(40, 40));
    });

    test('toImageForStorage renders image', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.pencil,
          positions: <Offset>[const Offset(0, 0), const Offset(50, 50)],
          brush: MyBrush(color: AppColors.black, size: 2),
          fillColor: AppColors.transparent,
        ),
      );
      final ui.Image img = layer.toImageForStorage(const Size(100, 100));
      expect(img.width, 100);
      expect(img.height, 100);
    });

    test('renderImageWH renders image', () {
      final LayerProvider layer = _createLayer();
      final ui.Image img = layer.renderImageWH(50, 50);
      expect(img.width, 50);
      expect(img.height, 50);
    });

    test('renderLayer with backgroundColor', () {
      final LayerProvider layer = _createLayer();
      layer.backgroundColor = AppColors.white;
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renderLayer with pencil action', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.pencil,
          positions: <Offset>[const Offset(0, 0), const Offset(50, 50)],
          brush: MyBrush(color: AppColors.black, size: 2),
          fillColor: AppColors.transparent,
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renderLayer with brush action', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.brush,
          positions: <Offset>[
            const Offset(0, 0),
            const Offset(10, 10),
            const Offset(20, 20),
          ],
          brush: MyBrush(color: AppColors.blue, size: 4),
          fillColor: AppColors.transparent,
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renderLayer with line action', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.line,
          positions: <Offset>[const Offset(0, 0), const Offset(80, 80)],
          brush: MyBrush(color: AppColors.black, size: 3),
          fillColor: AppColors.transparent,
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renderLayer with circle action', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.circle,
          positions: <Offset>[const Offset(10, 10), const Offset(50, 50)],
          brush: MyBrush(color: AppColors.black, size: 2),
          fillColor: AppColors.red,
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renderLayer with rectangle action', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.rectangle,
          positions: <Offset>[const Offset(5, 5), const Offset(90, 90)],
          brush: MyBrush(color: AppColors.black, size: 2),
          fillColor: AppColors.green,
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renderLayer with region action', () {
      final LayerProvider layer = _createLayer();
      final ui.Path regionPath = ui.Path()..addRect(const Rect.fromLTWH(10, 10, 30, 30));
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.region,
          positions: <Offset>[const Offset(10, 10)],
          brush: MyBrush(color: AppColors.black, size: 0),
          fillColor: AppColors.layerHiddenWarning,
          path: regionPath,
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renderLayer with eraser action', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.eraser,
          positions: <Offset>[const Offset(5, 5), const Offset(50, 50)],
          brush: MyBrush(color: AppColors.transparent, size: 10),
          fillColor: AppColors.transparent,
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renderLayer with cut action', () {
      final LayerProvider layer = _createLayer();
      final ui.Path cutPath = ui.Path()..addRect(const Rect.fromLTWH(0, 0, 20, 20));
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.cut,
          positions: <Offset>[const Offset(0, 0)],
          brush: MyBrush(color: AppColors.transparent, size: 0),
          fillColor: AppColors.transparent,
          path: cutPath,
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renderLayer with image action', () async {
      final LayerProvider layer = _createLayer();
      final ui.Image testImage = await _createTestImage(20, 20);
      layer.addImage(imageToAdd: testImage, offset: const Offset(5, 5));
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renderLayer with text action', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.text,
          positions: <Offset>[const Offset(10, 10)],
          brush: MyBrush(color: AppColors.black, size: 0),
          fillColor: AppColors.transparent,
          textObject: TextObject(
            text: 'Test',
            position: const Offset(10, 10),
            color: AppColors.black,
            size: 14,
          ),
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renderLayer with selector action does nothing', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.selector,
          positions: <Offset>[const Offset(10, 10), const Offset(50, 50)],
          brush: MyBrush(color: AppColors.black, size: 0),
          fillColor: AppColors.transparent,
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renderLayer with fill action does nothing (handled as region)', () {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.fill,
          positions: <Offset>[const Offset(10, 10)],
          brush: MyBrush(color: AppColors.black, size: 0),
          fillColor: AppColors.red,
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renderLayer with clipPath on action', () {
      final LayerProvider layer = _createLayer();
      final ui.Path clipPath = ui.Path()..addRect(const Rect.fromLTWH(0, 0, 50, 50));
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.pencil,
          positions: <Offset>[const Offset(5, 5), const Offset(40, 40)],
          brush: MyBrush(color: AppColors.black, size: 2),
          fillColor: AppColors.transparent,
          clipPath: clipPath,
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('renderLayer with opacity and blendMode', () {
      final LayerProvider layer = _createLayer();
      layer.opacity = 0.5;
      layer.blendMode = ui.BlendMode.multiply;
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.pencil,
          positions: <Offset>[const Offset(0, 0), const Offset(50, 50)],
          brush: MyBrush(color: AppColors.black, size: 2),
          fillColor: AppColors.transparent,
        ),
      );
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      layer.renderLayer(canvas);
      recorder.endRecording();
    });

    test('applyAction without clipPath', () {
      final LayerProvider layer = _createLayer();
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      bool called = false;
      layer.applyAction(canvas, null, (final Canvas c) => called = true);
      expect(called, true);
      recorder.endRecording();
    });

    test('applyAction with clipPath', () {
      final LayerProvider layer = _createLayer();
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final ui.Path clip = ui.Path()..addRect(const Rect.fromLTWH(0, 0, 50, 50));
      bool called = false;
      layer.applyAction(canvas, clip, (final Canvas c) => called = true);
      expect(called, true);
      recorder.endRecording();
    });

    test('update notifies listeners', () {
      final LayerProvider layer = _createLayer();
      bool notified = false;
      layer.addListener(() => notified = true);
      layer.update();
      expect(notified, true);
    });

    test('rotate90Clockwise with simple positions', () async {
      final LayerProvider layer = _createLayer(size: const Size(100, 200));
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.pencil,
          positions: <Offset>[const Offset(10, 20), const Offset(30, 40)],
          brush: MyBrush(color: AppColors.black, size: 2),
          fillColor: AppColors.transparent,
        ),
      );
      await layer.rotate90Clockwise(const Size(100, 200));
      // After 90° CW: (x,y) -> (H-y, x) where H=200
      expect(layer.actionStack.first.positions.first, const Offset(180, 10));
    });

    test('rotate90Clockwise with path', () async {
      final LayerProvider layer = _createLayer(size: const Size(100, 200));
      final ui.Path path = ui.Path()..addRect(const Rect.fromLTWH(10, 10, 20, 20));
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.region,
          positions: <Offset>[const Offset(10, 10)],
          brush: MyBrush(color: AppColors.black, size: 0),
          fillColor: AppColors.red,
          path: path,
        ),
      );
      await layer.rotate90Clockwise(const Size(100, 200));
      expect(layer.actionStack.first.path, isNotNull);
    });

    test('rotate90Clockwise with clipPath', () async {
      final LayerProvider layer = _createLayer(size: const Size(100, 100));
      final ui.Path clipPath = ui.Path()..addRect(const Rect.fromLTWH(0, 0, 50, 50));
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.pencil,
          positions: <Offset>[const Offset(5, 5), const Offset(40, 40)],
          brush: MyBrush(color: AppColors.black, size: 2),
          fillColor: AppColors.transparent,
          clipPath: clipPath,
        ),
      );
      await layer.rotate90Clockwise(const Size(100, 100));
      expect(layer.actionStack.first.clipPath, isNotNull);
    });

    test('rotate90Clockwise with image', () async {
      final LayerProvider layer = _createLayer(size: const Size(100, 100));
      final ui.Image testImage = await _createTestImage(20, 30);
      layer.addImage(imageToAdd: testImage, offset: const Offset(10, 10));
      await layer.rotate90Clockwise(const Size(100, 100));
      expect(layer.actionStack.first.image, isNotNull);
      expect(layer.actionStack.first.action, ActionType.image);
    });

    test('rotate90Clockwise with textObject', () async {
      final LayerProvider layer = _createLayer(size: const Size(100, 100));
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.text,
          positions: <Offset>[const Offset(10, 20)],
          brush: MyBrush(color: AppColors.black, size: 0),
          fillColor: AppColors.transparent,
          textObject: TextObject(
            text: 'Rotate',
            position: const Offset(10, 20),
            color: AppColors.black,
            size: 14,
          ),
        ),
      );
      await layer.rotate90Clockwise(const Size(100, 100));
      expect(layer.actionStack.first.textObject, isNotNull);
    });

    test('flipHorizontal flips positions', () async {
      final LayerProvider layer = _createLayer(size: const Size(100, 100));
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.pencil,
          positions: <Offset>[const Offset(10, 20), const Offset(30, 40)],
          brush: MyBrush(color: AppColors.black, size: 2),
          fillColor: AppColors.transparent,
        ),
      );
      await layer.flipHorizontal(const Size(100, 100));
      // horizontal: (x,y) -> (W-x, y) where W=100
      expect(layer.actionStack.first.positions.first, const Offset(90, 20));
    });

    test('flipVertical flips positions', () async {
      final LayerProvider layer = _createLayer(size: const Size(100, 100));
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.pencil,
          positions: <Offset>[const Offset(10, 20), const Offset(30, 40)],
          brush: MyBrush(color: AppColors.black, size: 2),
          fillColor: AppColors.transparent,
        ),
      );
      await layer.flipVertical(const Size(100, 100));
      // vertical: (x,y) -> (x, H-y) where H=100
      expect(layer.actionStack.first.positions.first, const Offset(10, 80));
    });

    test('flipHorizontal with path', () async {
      final LayerProvider layer = _createLayer(size: const Size(100, 100));
      final ui.Path path = ui.Path()..addRect(const Rect.fromLTWH(10, 10, 20, 20));
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.region,
          positions: <Offset>[const Offset(10, 10)],
          brush: MyBrush(color: AppColors.black, size: 0),
          fillColor: AppColors.red,
          path: path,
        ),
      );
      await layer.flipHorizontal(const Size(100, 100));
      expect(layer.actionStack.first.path, isNotNull);
    });

    test('flipVertical with clipPath', () async {
      final LayerProvider layer = _createLayer(size: const Size(100, 100));
      final ui.Path clipPath = ui.Path()..addRect(const Rect.fromLTWH(0, 0, 50, 50));
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.pencil,
          positions: <Offset>[const Offset(5, 5), const Offset(40, 40)],
          brush: MyBrush(color: AppColors.black, size: 2),
          fillColor: AppColors.transparent,
          clipPath: clipPath,
        ),
      );
      await layer.flipVertical(const Size(100, 100));
      expect(layer.actionStack.first.clipPath, isNotNull);
    });

    test('flipHorizontal with image', () async {
      final LayerProvider layer = _createLayer(size: const Size(100, 100));
      final ui.Image testImage = await _createTestImage(20, 20);
      layer.addImage(imageToAdd: testImage, offset: const Offset(10, 10));
      await layer.flipHorizontal(const Size(100, 100));
      expect(layer.actionStack.first.image, isNotNull);
    });

    test('flipVertical with image', () async {
      final LayerProvider layer = _createLayer(size: const Size(100, 100));
      final ui.Image testImage = await _createTestImage(20, 20);
      layer.addImage(imageToAdd: testImage, offset: const Offset(10, 10));
      await layer.flipVertical(const Size(100, 100));
      expect(layer.actionStack.first.image, isNotNull);
    });

    test('flipHorizontal with textObject', () async {
      final LayerProvider layer = _createLayer(size: const Size(100, 100));
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.text,
          positions: <Offset>[const Offset(10, 20)],
          brush: MyBrush(color: AppColors.black, size: 0),
          fillColor: AppColors.transparent,
          textObject: TextObject(
            text: 'FlipH',
            position: const Offset(10, 20),
            color: AppColors.black,
            size: 14,
          ),
        ),
      );
      await layer.flipHorizontal(const Size(100, 100));
      expect(layer.actionStack.first.textObject, isNotNull);
    });

    test('flipVertical with textObject', () async {
      final LayerProvider layer = _createLayer(size: const Size(100, 100));
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.text,
          positions: <Offset>[const Offset(10, 20)],
          brush: MyBrush(color: AppColors.black, size: 0),
          fillColor: AppColors.transparent,
          textObject: TextObject(
            text: 'FlipV',
            position: const Offset(10, 20),
            color: AppColors.black,
            size: 14,
          ),
        ),
      );
      await layer.flipVertical(const Size(100, 100));
      expect(layer.actionStack.first.textObject, isNotNull);
    });

    test('updateThumbnail creates thumbnail', () async {
      final LayerProvider layer = _createLayer();
      layer.appendDrawingAction(
        UserActionDrawing(
          action: ActionType.pencil,
          positions: <Offset>[const Offset(0, 0), const Offset(50, 50)],
          brush: MyBrush(color: AppColors.black, size: 2),
          fillColor: AppColors.transparent,
        ),
      );
      await layer.updateThumbnail();
      expect(layer.thumbnailImage, isNotNull);
      expect(layer.topColorsUsed, isA<List<ColorUsage>>());
    });

    test('topColorsUsed initially empty', () {
      final LayerProvider layer = _createLayer();
      expect(layer.topColorsUsed, isEmpty);
    });
  });
}

Future<ui.Image> _createTestImage(int width, int height) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = AppColors.red,
  );
  return recorder.endRecording().toImage(width, height);
}
