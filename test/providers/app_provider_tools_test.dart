import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/providers/app_provider_tools.dart';
import 'package:shared_preferences/shared_preferences.dart';

const ui.Rect _selectionRect = ui.Rect.fromLTWH(1, 1, 3, 3);

void main() {
  group('isFloodFillOriginModifierPressedForPlatform', () {
    test('uses Option on Apple platforms', () {
      final bool result = isFloodFillOriginModifierPressedForPlatform(
        platform: TargetPlatform.macOS,
        isAltPressed: true,
        isControlPressed: false,
      );

      expect(result, isTrue);
    });

    test('ignores Control on Apple platforms', () {
      final bool result = isFloodFillOriginModifierPressedForPlatform(
        platform: TargetPlatform.iOS,
        isAltPressed: false,
        isControlPressed: true,
      );

      expect(result, isFalse);
    });

    test('uses Control on non-Apple platforms', () {
      final bool result = isFloodFillOriginModifierPressedForPlatform(
        platform: TargetPlatform.windows,
        isAltPressed: false,
        isControlPressed: true,
      );

      expect(result, isTrue);
    });

    test('ignores Option on non-Apple platforms', () {
      final bool result = isFloodFillOriginModifierPressedForPlatform(
        platform: TargetPlatform.linux,
        isAltPressed: true,
        isControlPressed: false,
      );

      expect(result, isFalse);
    });
  });

  group('shouldUseSelectionRegionFloodFill', () {
    test('uses the selection region when a selection is active and modifier is not pressed', () {
      final ui.Path selectionPath = ui.Path()..addRect(_selectionRect);

      final bool result = shouldUseSelectionRegionFloodFill(
        isSelectionVisible: true,
        selectionPath: selectionPath,
        isOriginFloodFillModifierPressed: false,
      );

      expect(result, isTrue);
    });

    test('does not use the selection region when no selection is active', () {
      final ui.Path selectionPath = ui.Path()..addRect(_selectionRect);

      final bool result = shouldUseSelectionRegionFloodFill(
        isSelectionVisible: false,
        selectionPath: selectionPath,
        isOriginFloodFillModifierPressed: false,
      );

      expect(result, isFalse);
    });

    test('does not use the selection region when the selection path is missing', () {
      final bool result = shouldUseSelectionRegionFloodFill(
        isSelectionVisible: true,
        selectionPath: null,
        isOriginFloodFillModifierPressed: false,
      );

      expect(result, isFalse);
    });

    test('does not use the selection region when the origin modifier is pressed', () {
      final ui.Path selectionPath = ui.Path()..addRect(_selectionRect);

      final bool result = shouldUseSelectionRegionFloodFill(
        isSelectionVisible: true,
        selectionPath: selectionPath,
        isOriginFloodFillModifierPressed: true,
      );

      expect(result, isFalse);
    });
  });

  group('shouldCreateSelectionFromFloodFillTap', () {
    test('returns true when no selection is active', () {
      final bool result = shouldCreateSelectionFromFloodFillTap(
        isSelectionVisible: false,
        selectionPath: null,
      );

      expect(result, isTrue);
    });

    test('returns true when selection visibility is stale but path is missing', () {
      final bool result = shouldCreateSelectionFromFloodFillTap(
        isSelectionVisible: true,
        selectionPath: null,
      );

      expect(result, isTrue);
    });

    test('returns false when a selection is already active', () {
      final ui.Path selectionPath = ui.Path()..addRect(_selectionRect);

      final bool result = shouldCreateSelectionFromFloodFillTap(
        isSelectionVisible: true,
        selectionPath: selectionPath,
      );

      expect(result, isFalse);
    });
  });

  group('prepareFloodFillSelection', () {
    late AppProvider appProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppPreferences preferences = AppPreferences();
      await preferences.getPref();
      appProvider = AppProvider(preferences: preferences);
      appProvider.undoProvider.clear();
    });

    test('creates a selection instead of a paint action when none is active', () async {
      final int originalActionCount = appProvider.layers.selectedLayer.actionStack.length;

      final bool result = await appProvider.prepareFloodFillSelection(const ui.Offset(10, 10));

      expect(result, isTrue);
      expect(appProvider.selectorModel.isVisible, isTrue);
      expect(
        appProvider.selectorModel.path1!.getBounds(),
        ui.Rect.fromPoints(
          ui.Offset.zero,
          ui.Offset(appProvider.layers.width, appProvider.layers.height),
        ),
      );
      expect(appProvider.layers.selectedLayer.actionStack.length, originalActionCount);
    });

    test('does nothing when a selection is already active', () async {
      appProvider.selectAll();
      final ui.Rect originalBounds = appProvider.selectorModel.path1!.getBounds();

      final bool result = await appProvider.prepareFloodFillSelection(const ui.Offset(10, 10));

      expect(result, isFalse);
      expect(appProvider.selectorModel.path1!.getBounds(), originalBounds);
    });

    test('creates a selection while linear fill mode is active', () async {
      appProvider.selectedAction = ActionType.fill;
      appProvider.fillModel.mode = FillMode.linear;

      final bool result = await appProvider.prepareFloodFillSelection(const ui.Offset(10, 10));

      expect(result, isTrue);
      expect(appProvider.selectorModel.isVisible, isTrue);
      expect(appProvider.selectorModel.path1, isNotNull);
      expect(appProvider.fillModel.gradientPoints, isEmpty);
      expect(appProvider.fillModel.isVisible, isFalse);
    });

    test('creates a selection while radial fill mode is active', () async {
      appProvider.selectedAction = ActionType.fill;
      appProvider.fillModel.mode = FillMode.radial;

      final bool result = await appProvider.prepareFloodFillSelection(const ui.Offset(10, 10));

      expect(result, isTrue);
      expect(appProvider.selectorModel.isVisible, isTrue);
      expect(appProvider.selectorModel.path1, isNotNull);
      expect(appProvider.fillModel.gradientPoints, isEmpty);
      expect(appProvider.fillModel.isVisible, isFalse);
    });
  });

  group('appendLineFromLastUserAction', () {
    late AppProvider appProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppPreferences preferences = AppPreferences();
      await preferences.getPref();
      appProvider = AppProvider(preferences: preferences);
      appProvider.undoProvider.clear();
    });

    test('extends a pencil stroke without creating another undo action', () {
      appProvider.selectedAction = ActionType.pencil;
      appProvider.recordExecuteDrawingActionToSelectedLayer(
        action: UserActionDrawing(
          action: ActionType.pencil,
          positions: <ui.Offset>[
            const ui.Offset(0, 0),
            const ui.Offset(5, 5),
          ],
          brush: MyBrush(color: const ui.Color(0xFF000000), size: 2),
        ),
      );

      appProvider.appendLineFromLastUserAction(const ui.Offset(10, 10));

      expect(appProvider.layers.selectedLayer.actionStack, hasLength(1));
      expect(
        appProvider.layers.selectedLayer.lastUserAction!.positions,
        <ui.Offset>[
          const ui.Offset(0, 0),
          const ui.Offset(5, 5),
          const ui.Offset(10, 10),
        ],
      );

      appProvider.undoAction();

      expect(appProvider.layers.selectedLayer.actionStack, isEmpty);
    });

    test('extends an eraser stroke without creating another undo action', () {
      appProvider.selectedAction = ActionType.eraser;
      appProvider.recordExecuteDrawingActionToSelectedLayer(
        action: UserActionDrawing(
          action: ActionType.eraser,
          positions: <ui.Offset>[
            const ui.Offset(0, 0),
            const ui.Offset(5, 5),
          ],
          brush: MyBrush(color: const ui.Color(0xFF000000), size: 4),
        ),
      );

      appProvider.appendLineFromLastUserAction(const ui.Offset(10, 10));

      expect(appProvider.layers.selectedLayer.actionStack, hasLength(1));
      expect(
        appProvider.layers.selectedLayer.lastUserAction!.positions,
        <ui.Offset>[
          const ui.Offset(0, 0),
          const ui.Offset(5, 5),
          const ui.Offset(10, 10),
        ],
      );

      appProvider.undoAction();

      expect(appProvider.layers.selectedLayer.actionStack, isEmpty);
    });
  });
}
