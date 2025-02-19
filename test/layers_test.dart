import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/providers/layer_provider.dart';

void main() {
  group('Layer Tests', () {
    late LayerProvider layer;

    setUp(() {
      layer = LayerProvider(
        name: 'Test Layer',
        size: const Size(100, 100),
        onThumnailChanged: () {
          //
        },
      );
    });

    test('Initial values are correct', () {
      expect(layer.name, 'Test Layer');
      expect(layer.isSelected, false);
      expect(layer.isVisible, true);
      expect(layer.opacity, 1);
      expect(layer.count, 0);
      expect(layer.isEmpty, true);
    });

    test('Add user action', () {
      final UserActionDrawing userAction = UserActionDrawing(
        action: ActionType.brush,
        positions: <ui.Offset>[Offset.zero],
        brush: MyBrush(
          color: Colors.black,
          size: 1,
        ),
        fillColor: Colors.transparent,
      );
      layer.addUserAction(userAction);
      expect(layer.count, 1);
      expect(layer.isEmpty, false);
      expect(layer.lastUserAction, userAction);
    });

    test('Undo and redo actions', () {
      final UserActionDrawing userAction = UserActionDrawing(
        action: ActionType.brush,
        positions: <ui.Offset>[Offset.zero],
        brush: MyBrush(
          color: Colors.black,
          size: 1,
        ),
        fillColor: Colors.transparent,
      );
      layer.addUserAction(userAction);
      layer.undo();
      expect(layer.count, 0);
      expect(layer.redoStack.length, 1);
      layer.redo();
      expect(layer.count, 1);
      expect(layer.redoStack.length, 0);
    });

    test('Add image', () async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = Canvas(recorder);
      final ui.Paint paint = Paint()..color = Colors.red;
      canvas.drawRect(const Rect.fromLTWH(0, 0, 10, 10), paint);
      final ui.Picture picture = recorder.endRecording();
      final ui.Image image = await picture.toImage(10, 10);

      layer.addImage(imageToAdd: image);
      expect(layer.count, 1);
      expect(layer.lastUserAction?.action, ActionType.image);
    });

    test('Update last user action end position', () {
      final UserActionDrawing userAction = UserActionDrawing(
        action: ActionType.brush,
        positions: <ui.Offset>[Offset.zero, const Offset(1, 1)],
        brush: MyBrush(
          color: Colors.black,
          size: 1,
        ),
        fillColor: Colors.transparent,
      );
      layer.addUserAction(userAction);
      layer.lastActionUpdatePosition(const Offset(2, 2));
      expect(layer.lastUserAction?.positions.last, const Offset(2, 2));
    });

    test('Clear cache', () {
      layer.clearCache();
      expect(layer.thumbnailImage, null);
    });
  });
}
