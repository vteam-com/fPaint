import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/app_model.dart';

void main() {
  group('PaintModel Tests', () {
    late AppModel paintModel;

    setUp(() {
      paintModel = AppModel();
    });

    test('initial state should have one empty layer', () {
      expect(paintModel.layers.length, 1);
      expect(paintModel.selectedLayerIndex, 0);
      expect(
        paintModel.selectedLayer.count,
        1,
      ); // default layer has one white rectangle
    });

    test('addShape with Shape object should add to current layer', () {
      final shape = UserAction(
        positions: [
          const Offset(0, 0),
          const Offset(10, 10),
        ],
        action: ActionType.brush,
        brush: MyBrush(
          color: Colors.black,
          size: 1,
        ),
        fillColor: Colors.black,
      );
      paintModel.layersAddActionToSelectedLayer(action: shape);
      expect(
        paintModel.selectedLayer.count,
        2,
      ); // the first layer has one default white rectangle shape
      expect(paintModel.selectedLayer.lastUserAction, shape);
    });

    test('add UserAction with parameters should create and add new shape', () {
      paintModel.updateAction(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: ActionType.circle,
        colorFill: Colors.red,
        colorBrush: Colors.yellow,
      );
      expect(
        paintModel.selectedLayer.count,
        2,
      ); // also has the default white rectangle
      expect(
        paintModel.selectedLayer.lastUserAction!.positions.first,
        const Offset(0, 0),
      );
      expect(
        paintModel.selectedLayer.lastUserAction!.positions.last,
        const Offset(10, 10),
      );
      expect(
        paintModel.selectedLayer.lastUserAction!.action,
        ActionType.circle,
      );
      expect(paintModel.selectedLayer.lastUserAction!.fillColor, Colors.red);
    });

    test('updateLastShape should modify end position of last shape', () {
      paintModel.updateAction(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: ActionType.rectangle,
        colorFill: Colors.blue,
      );
      paintModel.updateAction(end: const Offset(20, 20));
      expect(
        paintModel.selectedLayer.lastUserAction!.positions.last,
        const Offset(20, 20),
      );
    });

    test('updateLastShape should do nothing if no shapes exist', () {
      paintModel.updateAction(end: const Offset(20, 20));
      expect(paintModel.selectedLayer.count, 1);
    });

    test('undo should remove last shape', () {
      paintModel.updateAction(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: ActionType.brush,
        colorFill: Colors.green,
        colorBrush: Colors.black,
      );
      expect(paintModel.selectedLayer.count, 2);
      paintModel.layersUndo();
      expect(paintModel.selectedLayer.count, 1);
      paintModel.layersUndo();
      expect(paintModel.selectedLayer.isEmpty, true);

      // opne more time to check if undo work when there is nothing to undo
      paintModel.layersUndo();
      expect(paintModel.selectedLayer.isEmpty, true);
    });

    test('multiple shapes should be added and managed correctly', () {
      paintModel.updateAction(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: ActionType.brush,
        colorFill: Colors.blue,
        colorBrush: Colors.black,
      );
      paintModel.updateAction(
        start: const Offset(20, 20),
        end: const Offset(30, 30),
        type: ActionType.circle,
        colorFill: Colors.red,
        colorBrush: Colors.black,
      );
      expect(paintModel.selectedLayer.count, 3);
      paintModel.layersUndo();
      expect(paintModel.selectedLayer.count, 2);
      expect(paintModel.selectedLayer.lastUserAction!.action, ActionType.brush);
    });
  });
}
