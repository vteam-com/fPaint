import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/providers/app_provider.dart';

void main() {
  group('appProvider Tests', () {
    test('initial state should have one empty layer', () {
      final appProvider = AppProvider();
      expect(appProvider.layers.length, 1);
      expect(appProvider.layers.selectedLayerIndex, 0);
      expect(
        appProvider.layers.selectedLayer.count,
        1,
      ); // default layer has one white rectangle
    });

    test('addShape with Shape object should add to current layer', () {
      final appProvider = AppProvider();
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
      appProvider.addActionToSelectedLayer(action: shape);
      expect(
        appProvider.layers.selectedLayer.count,
        2,
      ); // the first layer has one default white rectangle shape
      expect(appProvider.layers.selectedLayer.lastUserAction, shape);
    });

    test('add UserAction with parameters should create and add new shape', () {
      final appProvider = AppProvider();
      appProvider.updateAction(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: ActionType.circle,
        colorFill: Colors.red,
        colorBrush: Colors.yellow,
      );
      expect(
        appProvider.layers.selectedLayer.count,
        2,
      ); // also has the default white rectangle
      expect(
        appProvider.layers.selectedLayer.lastUserAction!.positions.first,
        const Offset(0, 0),
      );
      expect(
        appProvider.layers.selectedLayer.lastUserAction!.positions.last,
        const Offset(10, 10),
      );
      expect(
        appProvider.layers.selectedLayer.lastUserAction!.action,
        ActionType.circle,
      );
      expect(
        appProvider.layers.selectedLayer.lastUserAction!.fillColor,
        Colors.red,
      );
    });

    test('updateLastShape should modify end position of last shape', () {
      final appProvider = AppProvider();
      appProvider.updateAction(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: ActionType.rectangle,
        colorFill: Colors.blue,
      );
      appProvider.updateAction(end: const Offset(20, 20));
      expect(
        appProvider.layers.selectedLayer.lastUserAction!.positions.last,
        const Offset(20, 20),
      );
    });

    test('updateLastShape should do nothing if no shapes exist', () {
      final appProvider = AppProvider();
      appProvider.updateAction(end: const Offset(20, 20));
      expect(appProvider.layers.selectedLayer.count, 1);
    });

    test('undo should remove last shape', () {
      final appProvider = AppProvider();
      appProvider.updateAction(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: ActionType.brush,
        colorFill: Colors.green,
        colorBrush: Colors.black,
      );
      expect(appProvider.layers.selectedLayer.count, 2);
      appProvider.layersUndo();
      expect(appProvider.layers.selectedLayer.count, 1);
      appProvider.layersUndo();
      expect(appProvider.layers.selectedLayer.isEmpty, true);

      // opne more time to check if undo work when there is nothing to undo
      appProvider.layersUndo();
      expect(appProvider.layers.selectedLayer.isEmpty, true);
    });

    test('multiple shapes should be added and managed correctly', () {
      final appProvider = AppProvider();
      appProvider.updateAction(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: ActionType.brush,
        colorFill: Colors.blue,
        colorBrush: Colors.black,
      );
      appProvider.updateAction(
        start: const Offset(20, 20),
        end: const Offset(30, 30),
        type: ActionType.circle,
        colorFill: Colors.red,
        colorBrush: Colors.black,
      );
      expect(appProvider.layers.selectedLayer.count, 3);
      appProvider.layersUndo();
      expect(appProvider.layers.selectedLayer.count, 2);
      expect(
        appProvider.layers.selectedLayer.lastUserAction!.action,
        ActionType.brush,
      );
    });
  });
}
