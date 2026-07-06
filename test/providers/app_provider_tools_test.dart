import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/app_interaction.dart';
import 'package:fpaint/constants/app_limits.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/selector_model.dart';
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
    test('returns true for selector wand when no selection is active', () {
      final bool result = shouldCreateSelectionFromFloodFillTap(
        selectedAction: ActionType.selector,
        selectorMode: SelectorMode.wand,
        isSelectionVisible: false,
        selectionPath: null,
      );

      expect(result, isTrue);
    });

    test('returns true for selector wand when selection visibility is stale but path is missing', () {
      final bool result = shouldCreateSelectionFromFloodFillTap(
        selectedAction: ActionType.selector,
        selectorMode: SelectorMode.wand,
        isSelectionVisible: true,
        selectionPath: null,
      );

      expect(result, isTrue);
    });

    test('returns false when a selector wand selection is already active', () {
      final ui.Path selectionPath = ui.Path()..addRect(_selectionRect);

      final bool result = shouldCreateSelectionFromFloodFillTap(
        selectedAction: ActionType.selector,
        selectorMode: SelectorMode.wand,
        isSelectionVisible: true,
        selectionPath: selectionPath,
      );

      expect(result, isFalse);
    });

    test('returns false for the fill tool when no selection is active', () {
      final bool result = shouldCreateSelectionFromFloodFillTap(
        selectedAction: ActionType.fill,
        selectorMode: SelectorMode.wand,
        isSelectionVisible: false,
        selectionPath: null,
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

    test('does nothing when the fill tool has no active selection', () async {
      appProvider.selectedAction = ActionType.fill;
      final int originalActionCount = appProvider.layers.selectedLayer.actionStack.length;

      final bool result = await appProvider.prepareFloodFillSelection(const ui.Offset(10, 10));

      expect(result, isFalse);
      expect(appProvider.selectorModel.isVisible, isFalse);
      expect(appProvider.selectorModel.path1, isNull);
      expect(appProvider.layers.selectedLayer.actionStack.length, originalActionCount);
    });

    test('does nothing when a selection is already active', () async {
      appProvider.selectAll();
      final ui.Rect originalBounds = appProvider.selectorModel.path1!.getBounds();

      final bool result = await appProvider.prepareFloodFillSelection(const ui.Offset(10, 10));

      expect(result, isFalse);
      expect(appProvider.selectorModel.path1!.getBounds(), originalBounds);
    });

    test('creates a selection for the selector wand when none is active', () async {
      appProvider.selectedAction = ActionType.selector;
      appProvider.selectorModel.mode = SelectorMode.wand;

      final bool result = await appProvider.prepareFloodFillSelection(const ui.Offset(10, 10));

      expect(result, isTrue);
      expect(appProvider.selectorModel.isVisible, isTrue);
      expect(appProvider.selectorModel.path1, isNotNull);
      expect(
        appProvider.selectorModel.path1!.getBounds(),
        ui.Rect.fromPoints(
          ui.Offset.zero,
          ui.Offset(appProvider.layers.width, appProvider.layers.height),
        ),
      );
    });

    test('does nothing for the fill tool while linear fill mode is active', () async {
      appProvider.selectedAction = ActionType.fill;
      appProvider.fillModel.mode = FillMode.linear;

      final bool result = await appProvider.prepareFloodFillSelection(const ui.Offset(10, 10));

      expect(result, isFalse);
      expect(appProvider.fillModel.gradientPoints, isEmpty);
      expect(appProvider.fillModel.isVisible, isFalse);
      expect(appProvider.selectorModel.path1, isNull);
    });

    test('does nothing for the fill tool while radial fill mode is active', () async {
      appProvider.selectedAction = ActionType.fill;
      appProvider.fillModel.mode = FillMode.radial;

      final bool result = await appProvider.prepareFloodFillSelection(const ui.Offset(10, 10));

      expect(result, isFalse);
      expect(appProvider.fillModel.gradientPoints, isEmpty);
      expect(appProvider.fillModel.isVisible, isFalse);
      expect(appProvider.selectorModel.path1, isNull);
    });
  });

  group('Edge Detection wand drag-to-adjust', () {
    late AppProvider appProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppPreferences preferences = AppPreferences();
      await preferences.getPref();
      appProvider = AppProvider(preferences: preferences);
      appProvider.undoProvider.clear();
      appProvider.selectedAction = ActionType.selector;
      appProvider.selectorModel.mode = SelectorMode.wand;
    });

    test('wandToleranceForDrag loosens dragging right and tightens dragging left', () {
      const int start = 6;
      const double perUnit = AppInteraction.wandToleranceDragPixelsPerUnit;

      // No movement keeps the starting tolerance.
      expect(appProvider.wandToleranceForDrag(start, 0), start);
      // Dragging right by 4 units raises tolerance by 4.
      expect(appProvider.wandToleranceForDrag(start, perUnit * 4), start + 4);
      // Dragging far left clamps to the minimum.
      expect(appProvider.wandToleranceForDrag(start, -perUnit * 100), 1);
      // Dragging far right clamps to the maximum.
      expect(appProvider.wandToleranceForDrag(start, perUnit * 1000), AppLimits.percentMax);
    });

    test('wandSelectionResampleAt applies the tolerance and re-runs the selection', () async {
      appProvider.wandSelectionResampleAt(const ui.Offset(10, 10), tolerance: 25, sampleAllLayers: false);

      expect(appProvider.tolerance, 25);
      expect(appProvider.selectorModel.isDrawing, isTrue);

      // Let the queued async wand request settle; a selection should result.
      int guard = 0;
      while ((appProvider.wandSelection.isInProgress || appProvider.wandSelection.hasPendingRequest) && guard < 500) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        guard++;
      }
      expect(appProvider.selectorModel.path1, isNotNull);
    });

    test('wandSelectionResampleAt is a no-op outside wand mode', () {
      appProvider.selectorModel.mode = SelectorMode.rectangle;
      final int before = appProvider.tolerance;

      appProvider.wandSelectionResampleAt(const ui.Offset(10, 10), tolerance: 99, sampleAllLayers: false);

      expect(appProvider.tolerance, before);
    });

    test('wand tolerance HUD show/hide toggles visibility, value and position', () {
      expect(appProvider.isWandToleranceHudVisible, isFalse);

      appProvider.showWandToleranceHud(tolerance: 20, position: const ui.Offset(30, 40));
      expect(appProvider.isWandToleranceHudVisible, isTrue);
      expect(appProvider.wandToleranceHudTolerance, 20);
      expect(appProvider.wandToleranceHudPosition, const ui.Offset(30, 40));

      appProvider.hideWandToleranceHud();
      expect(appProvider.isWandToleranceHudVisible, isFalse);
      expect(appProvider.wandToleranceHudTolerance, isNull);
      expect(appProvider.wandToleranceHudPosition, isNull);
    });

    test('prewarmWandSourceCache is a no-op outside wand mode', () {
      appProvider.selectorModel.mode = SelectorMode.rectangle;

      appProvider.prewarmWandSourceCache();

      expect(appProvider.wandSelection.isInProgress, isFalse);
    });

    test('prewarmWandSourceCache warms the source so a later sample still selects', () async {
      appProvider.prewarmWandSourceCache();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      appProvider.wandSelectionResampleAt(const ui.Offset(10, 10), tolerance: 20, sampleAllLayers: false);
      int guard = 0;
      while ((appProvider.wandSelection.isInProgress || appProvider.wandSelection.hasPendingRequest) && guard < 500) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        guard++;
      }

      expect(appProvider.selectorModel.path1, isNotNull);
    });
  });

  group('gradient fill preview session', () {
    late AppProvider appProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppPreferences preferences = AppPreferences();
      await preferences.getPref();
      appProvider = AppProvider(preferences: preferences);
      appProvider.undoProvider.clear();
    });

    // Seeds a linear gradient session as the first canvas tap would.
    void startLinearSession() {
      appProvider.selectedAction = ActionType.fill;
      appProvider.fillModel.mode = FillMode.linear;
      appProvider.fillModel.addPoint(
        GradientPoint(offset: const ui.Offset(10, 10), color: const ui.Color(0xFFFF0000)),
      );
      appProvider.fillModel.addPoint(
        GradientPoint(offset: const ui.Offset(40, 40), color: const ui.Color(0xFF0000FF)),
      );
      appProvider.fillModel.isVisible = true;
    }

    // Waits for the debounced async preview render to append its transient.
    Future<void> settlePreview() async {
      int guard = 0;
      while (appProvider.fillPreviewAction == null && guard < 1000) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
        guard++;
      }
    }

    test('live preview never records an undo entry until applied', () async {
      startLinearSession();

      appProvider.updateGradientPreview();
      await settlePreview();
      // A second edit rebuilds the transient (remove-before-build), still no undo.
      appProvider.updateGradientPreview();
      await settlePreview();

      expect(appProvider.fillPreviewAction, isNotNull);
      expect(appProvider.isGradientPreviewActive, isTrue);
      expect(appProvider.undoProvider.canUndo, isFalse);
    });

    test('applying commits exactly one undo entry and ends the session', () async {
      startLinearSession();
      appProvider.updateGradientPreview();
      await settlePreview();
      expect(appProvider.fillPreviewAction, isNotNull);

      appProvider.applyGradientPreview();

      expect(appProvider.fillModel.isVisible, isFalse);
      expect(appProvider.fillPreviewAction, isNull);
      expect(appProvider.undoProvider.canUndo, isTrue);

      // Exactly one entry: a single undo empties the stack.
      appProvider.undoAction();
      expect(appProvider.undoProvider.canUndo, isFalse);
    });

    test('leaving the fill tool implicitly applies the session once', () async {
      startLinearSession();
      appProvider.updateGradientPreview();
      await settlePreview();

      // Switching tools routes through applyGradientPreview (implicit Apply).
      appProvider.selectedAction = ActionType.brush;

      expect(appProvider.fillModel.isVisible, isFalse);
      expect(appProvider.fillPreviewAction, isNull);
      expect(appProvider.undoProvider.canUndo, isTrue);
      appProvider.undoAction();
      expect(appProvider.undoProvider.canUndo, isFalse);
    });

    test('the preview is held, never appended to the layer', () async {
      final int baseline = appProvider.layers.selectedLayer.actionStack.length;
      startLinearSession();
      appProvider.updateGradientPreview();
      await settlePreview();

      expect(appProvider.fillPreviewAction, isNotNull);
      // The live preview is drawn by the overlay, not baked onto the layer.
      expect(appProvider.layers.selectedLayer.actionStack.length, baseline);
    });

    test('cancelling discards the preview with no undo entry', () async {
      final int baseline = appProvider.layers.selectedLayer.actionStack.length;
      startLinearSession();
      appProvider.updateGradientPreview();
      await settlePreview();
      expect(appProvider.fillPreviewAction, isNotNull);

      appProvider.cancelGradientPreview();

      expect(appProvider.fillModel.isVisible, isFalse);
      expect(appProvider.fillPreviewAction, isNull);
      expect(appProvider.undoProvider.canUndo, isFalse);
      // Nothing was ever added to the layer (held preview, overlay only).
      expect(appProvider.layers.selectedLayer.actionStack.length, baseline);
    });

    test('a render whose session ends before it completes does not apply', () async {
      startLinearSession();
      appProvider.updateGradientPreview(); // async region resolve in flight

      // Session ends out from under the in-flight resolve.
      appProvider.fillModel.isVisible = false;

      // Let the async resolve settle; the version/visibility guard must drop it.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(appProvider.fillPreviewAction, isNull);
      expect(appProvider.undoProvider.canUndo, isFalse);
    });
  });

  group('solid fill preview (tolerance drag)', () {
    late AppProvider appProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppPreferences preferences = AppPreferences();
      await preferences.getPref();
      appProvider = AppProvider(preferences: preferences);
      appProvider.undoProvider.clear();
      appProvider.selectedAction = ActionType.fill; // solid is the default mode
    });

    Future<void> settlePreview() async {
      int guard = 0;
      while (appProvider.fillPreviewAction == null && guard < 1000) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
        guard++;
      }
    }

    test('preview is not on the undo stack; committing records exactly one entry', () async {
      appProvider.updateSolidFillPreview(const ui.Offset(10, 10), sampleAllLayers: false);
      await settlePreview();

      expect(appProvider.fillPreviewAction, isNotNull);
      expect(appProvider.undoProvider.canUndo, isFalse);

      appProvider.commitFillPreview();

      expect(appProvider.fillPreviewAction, isNull);
      expect(appProvider.undoProvider.canUndo, isTrue);
      appProvider.undoAction();
      expect(appProvider.undoProvider.canUndo, isFalse);
    });

    test('committing with no rendered preview records nothing', () {
      expect(appProvider.fillPreviewAction, isNull);
      appProvider.commitFillPreview();
      expect(appProvider.undoProvider.canUndo, isFalse);
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
