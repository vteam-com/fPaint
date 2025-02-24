import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  SharedPreferences.setMockInitialValues(<String, Object>{});

  group('appProvider Tests', () {
    test('initial state should have one empty layer', () {
      final AppProvider appProvider = AppProvider();
      expect(appProvider.layers.length, 1);
      expect(appProvider.layers.selectedLayerIndex, 0);
      expect(
        appProvider.layers.selectedLayer.count,
        0,
      ); // default layer has one white rectangle
    });

    test('addShape with Shape object should add to current layer', () {
      final AppProvider appProvider = AppProvider();
      final UserActionDrawing shape = UserActionDrawing(
        positions: <Offset>[
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
      appProvider.recordExecuteDrawingActionToSelectedLayer(action: shape);
      expect(
        appProvider.layers.selectedLayer.count,
        1,
      ); // the first layer has one default white rectangle shape
      expect(appProvider.layers.selectedLayer.lastUserAction, shape);
    });

    test('add UserAction with parameters should create and add new shape', () {
      final AppProvider appProvider = AppProvider();
      appProvider.updateAction(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: ActionType.circle,
        colorFill: Colors.red,
        colorBrush: Colors.yellow,
      );
      expect(
        appProvider.layers.selectedLayer.count,
        1,
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

    test('undo should remove last shape', () {
      final AppProvider appProvider = AppProvider();
      appProvider.updateAction(
        start: const Offset(0, 0),
        end: const Offset(10, 10),
        type: ActionType.brush,
        colorFill: Colors.green,
        colorBrush: Colors.black,
      );
      expect(appProvider.layers.selectedLayer.count, 1);
      appProvider.undoAction();
      expect(appProvider.layers.selectedLayer.count, 0);

      appProvider.undoAction();
      expect(appProvider.layers.selectedLayer.isEmpty, true);

      // opne more time to check if undo work when there is nothing to undo
      appProvider.undoAction();
      expect(appProvider.layers.selectedLayer.isEmpty, true);
    });

    test('multiple shapes should be added and managed correctly', () {
      final AppProvider appProvider = AppProvider();
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
      expect(appProvider.layers.selectedLayer.count, 2);
      appProvider.undoAction();
      expect(appProvider.layers.selectedLayer.count, 1);
      expect(
        appProvider.layers.selectedLayer.lastUserAction!.action,
        ActionType.brush,
      );
    });
  });
}
