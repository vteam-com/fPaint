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
        paintModel.currentLayer.actionStack.length,
        1,
      ); // default layer has one white rectangle
    });

    test('addShape with Shape object should add to current layer', () {
      final shape = UserAction(
        positionStart: const Offset(0, 0),
        positionEnd: const Offset(10, 10),
        tool: Tools.draw,
        fillColor: Colors.black,
        brushColor: Colors.black,
        brushSize: 1,
      );
      paintModel.addUserAction(shape: shape);
      expect(
        paintModel.currentLayer.actionStack.length,
        2,
      ); // the first layer has one default white rectangle shape
      expect(paintModel.currentLayer.actionStack.last, shape);
    });

    test('addShape with parameters should create and add new shape', () {
      paintModel.addUserAction(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: Tools.circle,
        colorFill: Colors.red,
        colorStroke: Colors.yellow,
      );
      expect(
        paintModel.currentLayer.actionStack.length,
        2,
      ); // also has the default white rectangle
      expect(
        paintModel.currentLayer.actionStack.last.positionStart,
        const Offset(0, 0),
      );
      expect(
        paintModel.currentLayer.actionStack.last.positionEnd,
        const Offset(10, 10),
      );
      expect(paintModel.currentLayer.actionStack.last.tool, Tools.circle);
      expect(paintModel.currentLayer.actionStack.last.fillColor, Colors.red);
    });

    test('updateLastShape should modify end position of last shape', () {
      paintModel.addUserAction(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: Tools.rectangle,
        colorFill: Colors.blue,
      );
      paintModel.updateLastUserAction(const Offset(20, 20));
      expect(
        paintModel.currentLayer.actionStack.last.positionEnd,
        const Offset(20, 20),
      );
    });

    test('updateLastShape should do nothing if no shapes exist', () {
      paintModel.updateLastUserAction(const Offset(20, 20));
      expect(paintModel.currentLayer.actionStack.length, 1);
    });

    test('undo should remove last shape', () {
      paintModel.addUserAction(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: Tools.draw,
        colorFill: Colors.green,
        colorStroke: Colors.black,
      );
      expect(paintModel.currentLayer.actionStack.length, 2);
      paintModel.undo();
      expect(paintModel.currentLayer.actionStack.length, 1);
      paintModel.undo();
      expect(paintModel.currentLayer.actionStack.isEmpty, true);

      // opne more time to check if undo work when there is nothing to undo
      paintModel.undo();
      expect(paintModel.currentLayer.actionStack.isEmpty, true);
    });

    test('multiple shapes should be added and managed correctly', () {
      paintModel.addUserAction(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: Tools.draw,
        colorFill: Colors.blue,
        colorStroke: Colors.black,
      );
      paintModel.addUserAction(
        start: const Offset(20, 20),
        end: const Offset(30, 30),
        type: Tools.circle,
        colorFill: Colors.red,
        colorStroke: Colors.black,
      );
      expect(paintModel.currentLayer.actionStack.length, 3);
      paintModel.undo();
      expect(paintModel.currentLayer.actionStack.length, 2);
      expect(paintModel.currentLayer.actionStack.last.tool, Tools.draw);
    });
  });
}
