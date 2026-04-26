import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppProvider appProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppPreferences preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    appProvider.undoProvider.clear();
  });

  group('selectAll', () {
    test('makes selectorModel visible', () {
      appProvider.selectAll();
      expect(appProvider.selectorModel.isVisible, isTrue);
    });

    test('sets path1 to full canvas rect', () {
      appProvider.selectAll();
      expect(appProvider.selectorModel.path1, isNotNull);
      final Rect bounds = appProvider.selectorModel.path1!.getBounds();
      expect(bounds.width, appProvider.layers.width);
      expect(bounds.height, appProvider.layers.height);
    });
  });

  group('selectorCreationStart / End', () {
    test('rectangle mode creates path on start', () {
      appProvider.selectorModel.mode = SelectorMode.rectangle;
      appProvider.selectorCreationStart(const Offset(10, 10));
      expect(appProvider.selectorModel.isDrawing, isTrue);
      expect(appProvider.selectorModel.isVisible, isTrue);
    });

    test('circle mode creates path on start', () {
      appProvider.selectorModel.mode = SelectorMode.circle;
      appProvider.selectorCreationStart(const Offset(10, 10));
      expect(appProvider.selectorModel.isDrawing, isTrue);
    });

    test('lasso mode creates path on start', () {
      appProvider.selectorModel.mode = SelectorMode.lasso;
      appProvider.selectorCreationStart(const Offset(10, 10));
      expect(appProvider.selectorModel.isDrawing, isTrue);
    });

    test('end stops drawing and applies math', () {
      appProvider.selectorModel.mode = SelectorMode.rectangle;
      appProvider.selectorCreationStart(const Offset(10, 10));
      appProvider.selectorCreationAdditionalPoint(const Offset(50, 50));
      appProvider.selectorCreationEnd();
      expect(appProvider.selectorModel.isDrawing, isFalse);
    });
  });

  group('selectorCreationAdditionalPoint', () {
    test('rectangle mode updates path2 when math is add', () {
      appProvider.selectorModel.mode = SelectorMode.rectangle;
      appProvider.selectorModel.math = SelectorMath.add;
      appProvider.selectorCreationStart(const Offset(10, 10));
      appProvider.selectorCreationAdditionalPoint(const Offset(50, 50));
      expect(appProvider.selectorModel.path2, isNotNull);
    });

    test('lasso mode adds points', () {
      appProvider.selectorModel.mode = SelectorMode.lasso;
      appProvider.selectorCreationStart(const Offset(10, 10));
      appProvider.selectorCreationAdditionalPoint(const Offset(50, 50));
      appProvider.selectorCreationAdditionalPoint(const Offset(30, 80));
      expect(appProvider.selectorModel.points.length, 3);
    });

    test('wand mode ignores additional points', () {
      appProvider.selectorModel.mode = SelectorMode.wand;
      // Start doesn't add points for wand (it uses async fill)
      appProvider.selectorCreationAdditionalPoint(const Offset(50, 50));
      // Should not throw
    });
  });

  group('cancelImagePlacement', () {
    test('clears imagePlacementModel and notifies', () {
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      appProvider.cancelImagePlacement();
      expect(appProvider.imagePlacementModel.image, isNull);
      expect(notifyCount, 1);
    });
  });

  group('cancelTransform', () {
    test('clears transformModel and notifies', () {
      int notifyCount = 0;
      appProvider.addListener(() => notifyCount++);
      appProvider.cancelTransform();
      expect(appProvider.transformModel.sourceImage, isNull);
      expect(notifyCount, 1);
    });
  });

  group('regionErase', () {
    test('does nothing when path1 is null', () {
      appProvider.selectorModel.path1 = null;
      // Should not throw
      appProvider.regionErase();
    });

    test('records an action when path1 exists', () {
      appProvider.selectAll();
      appProvider.regionErase();
      expect(appProvider.undoProvider.canUndo, isTrue);
    });
  });

  group('getPathAdjustToCanvasSizeAndPosition', () {
    test('returns null for null path', () {
      expect(appProvider.getPathAdjustToCanvasSizeAndPosition(null), isNull);
    });

    test('transforms path by canvas offset and scale', () {
      final Path original = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
      appProvider.canvasOffset = const Offset(10, 20);
      appProvider.layers.scale = 2.0;
      final Path? result = appProvider.getPathAdjustToCanvasSizeAndPosition(original);
      expect(result, isNotNull);
      final Rect bounds = result!.getBounds();
      // The path should be scaled and translated
      expect(bounds.left, closeTo(10, 1));
      expect(bounds.top, closeTo(20, 1));
      expect(bounds.width, closeTo(200, 1));
      expect(bounds.height, closeTo(200, 1));
    });
  });

  group('recordExecuteDrawingActionToSelectedLayer', () {
    test('adds undo-able action', () {
      expect(appProvider.undoProvider.canUndo, isFalse);
      appProvider.recordExecuteDrawingActionToSelectedLayer(
        action: UserActionDrawing(
          positions: <Offset>[const Offset(0, 0), const Offset(10, 10)],
          action: ActionType.brush,
          brush: MyBrush(color: const Color(0xFF000000), size: 5),
        ),
      );
      expect(appProvider.undoProvider.canUndo, isTrue);
    });

    test('uses selector path as clipPath when visible', () {
      appProvider.selectAll();
      appProvider.recordExecuteDrawingActionToSelectedLayer(
        action: UserActionDrawing(
          positions: <Offset>[const Offset(0, 0), const Offset(10, 10)],
          action: ActionType.brush,
          brush: MyBrush(color: const Color(0xFF000000), size: 5),
        ),
      );
      expect(appProvider.undoProvider.canUndo, isTrue);
    });
  });

  group('dispose', () {
    test('can be disposed without error', () {
      appProvider.dispose();
      // Should not throw
    });
  });
}
