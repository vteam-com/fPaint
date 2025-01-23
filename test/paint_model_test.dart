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
      expect(paintModel.currentLayerIndex, 0);
      expect(
        paintModel.currentLayer.shapes.length,
        1,
      ); // default layer has one white rectangle
    });

    test('addShape with Shape object should add to current layer', () {
      final shape = Shape(
        const Offset(0, 0),
        const Offset(10, 10),
        ShapeType.pencil,
        Colors.black,
      );
      paintModel.addShape(shape: shape);
      expect(
        paintModel.currentLayer.shapes.length,
        2,
      ); // the first layer has one default white rectangle shape
      expect(paintModel.currentLayer.shapes.last, shape);
    });

    test('addShape with parameters should create and add new shape', () {
      paintModel.addShape(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: ShapeType.circle,
        color: Colors.red,
      );
      expect(
        paintModel.currentLayer.shapes.length,
        2,
      ); // also has the default white rectangle
      expect(paintModel.currentLayer.shapes.last.start, const Offset(0, 0));
      expect(paintModel.currentLayer.shapes.last.end, const Offset(10, 10));
      expect(paintModel.currentLayer.shapes.last.type, ShapeType.circle);
      expect(paintModel.currentLayer.shapes.last.color, Colors.red);
    });

    test('updateLastShape should modify end position of last shape', () {
      paintModel.addShape(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: ShapeType.rectangle,
        color: Colors.blue,
      );
      paintModel.updateLastShape(const Offset(20, 20));
      expect(paintModel.currentLayer.shapes.last.end, const Offset(20, 20));
    });

    test('updateLastShape should do nothing if no shapes exist', () {
      paintModel.updateLastShape(const Offset(20, 20));
      expect(paintModel.currentLayer.shapes.length, 1);
    });

    test('undo should remove last shape', () {
      paintModel.addShape(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: ShapeType.pencil,
        color: Colors.green,
      );
      expect(paintModel.currentLayer.shapes.length, 2);
      paintModel.undo();
      expect(paintModel.currentLayer.shapes.length, 1);
      paintModel.undo();
      expect(paintModel.currentLayer.shapes.isEmpty, true);

      // opne more time to check if undo work when there is nothing to undo
      paintModel.undo();
      expect(paintModel.currentLayer.shapes.isEmpty, true);
    });

    test('multiple shapes should be added and managed correctly', () {
      paintModel.addShape(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: ShapeType.pencil,
        color: Colors.black,
      );
      paintModel.addShape(
        start: const Offset(20, 20),
        end: const Offset(30, 30),
        type: ShapeType.circle,
        color: Colors.red,
      );
      expect(paintModel.currentLayer.shapes.length, 3);
      paintModel.undo();
      expect(paintModel.currentLayer.shapes.length, 2);
      expect(paintModel.currentLayer.shapes.last.type, ShapeType.pencil);
    });
  });
}
