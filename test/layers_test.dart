import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/providers/layer.dart';

void main() {
  group('Layer Tests', () {
    late Layer layer;

    setUp(() {
      layer = Layer(name: 'Test Layer');
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
      final userAction = UserAction(
        action: ActionType.brush,
        positions: [Offset.zero],
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
      final userAction = UserAction(
        action: ActionType.brush,
        positions: [Offset.zero],
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
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = Colors.red;
      canvas.drawRect(const Rect.fromLTWH(0, 0, 10, 10), paint);
      final picture = recorder.endRecording();
      final image = await picture.toImage(10, 10);

      layer.addImage(imageToAdd: image);
      expect(layer.count, 1);
      expect(layer.lastUserAction?.action, ActionType.image);
    });

    test('Update last user action end position', () {
      final userAction = UserAction(
        action: ActionType.brush,
        positions: [Offset.zero, const Offset(1, 1)],
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
      expect(layer.cachedThumnailImage, null);
    });
  });
}
