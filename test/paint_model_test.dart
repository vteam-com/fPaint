import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/paint_model.dart';

void main() {
  group('PaintModel Tests', () {
    late PaintModel paintModel;

    setUp(() {
      paintModel = PaintModel();
    });

    test('initial state should have one empty layer', () {
      expect(paintModel.layers.length, 1);
      expect(paintModel.currentLayerIndex, 0);
      expect(paintModel.currentLayer.shapes.isEmpty, true);
    });

    test('addShape with Shape object should add to current layer', () {
      final shape = Shape(
        const Offset(0, 0),
        const Offset(10, 10),
        ShapeType.pencil,
        Colors.black,
      );
      paintModel.addShape(shape: shape);
      expect(paintModel.currentLayer.shapes.length, 1);
      expect(paintModel.currentLayer.shapes.first, shape);
    });

    test('addShape with parameters should create and add new shape', () {
      paintModel.addShape(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: ShapeType.circle,
        color: Colors.red,
      );
      expect(paintModel.currentLayer.shapes.length, 1);
      expect(paintModel.currentLayer.shapes.first.start, const Offset(0, 0));
      expect(paintModel.currentLayer.shapes.first.end, const Offset(10, 10));
      expect(paintModel.currentLayer.shapes.first.type, ShapeType.circle);
      expect(paintModel.currentLayer.shapes.first.color, Colors.red);
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
      expect(paintModel.currentLayer.shapes.isEmpty, true);
    });

    test('undo should remove last shape', () {
      paintModel.addShape(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: ShapeType.pencil,
        color: Colors.green,
      );
      expect(paintModel.currentLayer.shapes.length, 1);
      paintModel.undo();
      expect(paintModel.currentLayer.shapes.isEmpty, true);
    });

    test('undo should do nothing if no shapes exist', () {
      expect(paintModel.currentLayer.shapes.isEmpty, true);
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
      expect(paintModel.currentLayer.shapes.length, 2);
      paintModel.undo();
      expect(paintModel.currentLayer.shapes.length, 1);
      expect(paintModel.currentLayer.shapes.first.type, ShapeType.pencil);
    });
  });
}
