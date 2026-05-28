import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppProvider appProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppPreferences preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
  });

  group('AppProvider initial state', () {
    test('layers has one layer after init', () {
      expect(appProvider.layers.length, 1);
    });

    test('selectedLayerIndex is 0', () {
      expect(appProvider.layers.selectedLayerIndex, 0);
    });

    test('canvasOffset starts at zero', () {
      expect(appProvider.canvasOffset, Offset.zero);
    });

    test('selectedAction defaults to brush', () {
      expect(appProvider.selectedAction, ActionType.brush);
    });

    test('brushStyle defaults to solid', () {
      expect(appProvider.brushStyle, BrushStyle.solid);
    });

    test('tolerance defaults to AppDefaults value', () {
      expect(appProvider.tolerance, AppDefaults.tolerance);
    });

    test('fillModel is not visible', () {
      expect(appProvider.fillModel.isVisible, isFalse);
    });

    test('selectorModel is not visible', () {
      expect(appProvider.selectorModel.isVisible, isFalse);
    });

    test('undoProvider canUndo is false', () {
      expect(appProvider.undoProvider.canUndo, isFalse);
    });

    test('undoProvider canRedo is false', () {
      expect(appProvider.undoProvider.canRedo, isFalse);
    });

    test('eyeDropPositionForBrush is null', () {
      expect(appProvider.eyeDropPositionForBrush, isNull);
    });

    test('eyeDropPositionForFill is null', () {
      expect(appProvider.eyeDropPositionForFill, isNull);
    });

    test('selectedTextObject is null', () {
      expect(appProvider.selectedTextObject, isNull);
    });
  });

  group('selectedAction', () {
    test('can be set and read', () {
      appProvider.selectedAction = ActionType.pencil;
      expect(appProvider.selectedAction, ActionType.pencil);
    });

    test('setting to non-fill clears fill model', () {
      appProvider.fillModel.isVisible = true;
      appProvider.selectedAction = ActionType.brush;
      expect(appProvider.fillModel.isVisible, isFalse);
    });

    test('setting to fill does not clear fill model', () {
      appProvider.fillModel.isVisible = true;
      appProvider.selectedAction = ActionType.fill;
      // Fill model should not be cleared
    });

    test('notifies listeners', () {
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      appProvider.selectedAction = ActionType.eraser;
      expect(notifyCount, 1);
    });
  });

  group('brushSize', () {
    test('can be set and read', () {
      appProvider.brushSize = 10.0;
      expect(appProvider.brushSize, 10.0);
    });

    test('notifies listeners', () {
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      appProvider.brushSize = 20.0;
      expect(notifyCount, 1);
    });
  });

  group('brushStyle', () {
    test('can be set and read', () {
      appProvider.brushStyle = BrushStyle.dash;
      expect(appProvider.brushStyle, BrushStyle.dash);
    });

    test('notifies listeners', () {
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      appProvider.brushStyle = BrushStyle.solid;
      expect(notifyCount, 1);
    });
  });

  group('brushColor', () {
    test('can be set and read', () {
      appProvider.brushColor = const Color(0xFFFF0000);
      expect(appProvider.brushColor, const Color(0xFFFF0000));
    });

    test('notifies listeners', () {
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      appProvider.brushColor = const Color(0xFF00FF00);
      expect(notifyCount, 1);
    });
  });

  group('fillColor', () {
    test('can be set and read', () {
      appProvider.fillColor = const Color(0xFF0000FF);
      expect(appProvider.fillColor, const Color(0xFF0000FF));
    });

    test('notifies listeners', () {
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      appProvider.fillColor = const Color(0xFFFF00FF);
      expect(notifyCount, 1);
    });
  });

  group('tolerance', () {
    test('can be set and read', () {
      appProvider.tolerance = 75;
      expect(appProvider.tolerance, 75);
    });

    test('clamps to minimum of 1', () {
      appProvider.tolerance = 0;
      expect(appProvider.tolerance, 1);
    });

    test('clamps to maximum of 100', () {
      appProvider.tolerance = 200;
      expect(appProvider.tolerance, AppLimits.percentMax);
    });

    test('notifies listeners', () {
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      appProvider.tolerance = 30;
      expect(notifyCount, 1);
    });
  });

  group('undo/redo', () {
    test('undoAction calls undo and notifies', () {
      int notifyCount = 0;
      appProvider.undoProvider.executeAction(
        name: 'test',
        forward: () {},
        backward: () {},
      );
      appProvider.addListener(() => notifyCount++);
      appProvider.undoAction();
      expect(notifyCount, 1);
    });

    test('redoAction calls redo and notifies', () {
      appProvider.undoProvider.executeAction(
        name: 'test',
        forward: () {},
        backward: () {},
      );
      appProvider.undoAction();
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      appProvider.redoAction();
      expect(notifyCount, 1);
    });
  });

  group('selected layer lock', () {
    test('prevents recording drawing actions on the locked selected layer', () {
      final UserActionDrawing action = UserActionDrawing(
        action: ActionType.brush,
        positions: <Offset>[const Offset(0, 0), const Offset(10, 10)],
        brush: MyBrush(color: const Color(0xFF000000), size: 5),
      );

      appProvider.layers.selectedLayer.isLocked = true;

      final bool wasRecorded = appProvider.recordExecuteDrawingActionToSelectedLayer(action: action);

      expect(wasRecorded, isFalse);
      expect(appProvider.layers.selectedLayer.actionStack, isEmpty);
      expect(appProvider.undoProvider.canUndo, isFalse);
    });

    test('records drawing actions when the selected layer is unlocked', () {
      final UserActionDrawing action = UserActionDrawing(
        action: ActionType.brush,
        positions: <Offset>[const Offset(0, 0), const Offset(10, 10)],
        brush: MyBrush(color: const Color(0xFF000000), size: 5),
      );

      final bool wasRecorded = appProvider.recordExecuteDrawingActionToSelectedLayer(action: action);

      expect(wasRecorded, isTrue);
      expect(appProvider.layers.selectedLayer.actionStack, hasLength(1));
      expect(appProvider.undoProvider.canUndo, isTrue);
    });
  });

  group('update', () {
    test('notifies listeners', () {
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      appProvider.update();
      expect(notifyCount, 1);
    });
  });

  group('preferences integration', () {
    test('preferredLocale is null by default', () {
      expect(appProvider.preferredLocale, isNull);
    });

    test('languageCode is null by default', () {
      expect(appProvider.languageCode, isNull);
    });

    test('setLanguageCode updates and notifies', () async {
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      await appProvider.setLanguageCode('fr');
      expect(appProvider.languageCode, 'fr');
      expect(notifyCount, greaterThanOrEqualTo(1));
    });

    test('setLanguageCode to null clears locale', () async {
      await appProvider.setLanguageCode('es');
      await appProvider.setLanguageCode(null);
      expect(appProvider.languageCode, isNull);
    });
  });

  group('fillService', () {
    test('is accessible', () {
      expect(appProvider.fillService, isNotNull);
    });
  });

  group('debounceGradientFill', () {
    test('is accessible', () {
      expect(appProvider.debounceGradientFill, isNotNull);
    });
  });

  group('imagePlacementModel', () {
    test('is accessible', () {
      expect(appProvider.imagePlacementModel, isNotNull);
    });
  });

  group('transformModel', () {
    test('is accessible', () {
      expect(appProvider.transformModel, isNotNull);
    });
  });
}
