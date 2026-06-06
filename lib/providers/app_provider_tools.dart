import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/providers/fill_service.dart';

/// Returns whether the platform-specific modifier requests origin-based flood fill.
@visibleForTesting
bool isFloodFillOriginModifierPressedForPlatform({
  required final TargetPlatform platform,
  required final bool isAltPressed,
  required final bool isControlPressed,
}) {
  final bool isApplePlatform = platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;
  return isApplePlatform ? isAltPressed : isControlPressed;
}

/// Returns whether flood fill should use the active selection path as its region.
@visibleForTesting
bool shouldUseSelectionRegionFloodFill({
  required final bool isSelectionVisible,
  required final ui.Path? selectionPath,
  required final bool isOriginFloodFillModifierPressed,
}) {
  return isSelectionVisible && selectionPath != null && !isOriginFloodFillModifierPressed;
}

/// Returns whether a solid flood-fill tap should first promote the tapped
/// region into the active selection instead of painting immediately.
@visibleForTesting
bool shouldCreateSelectionFromFloodFillTap({
  required final ActionType selectedAction,
  required final SelectorMode selectorMode,
  required final bool isSelectionVisible,
  required final ui.Path? selectionPath,
}) {
  return selectedAction == ActionType.selector &&
      selectorMode == SelectorMode.wand &&
      (!isSelectionVisible || selectionPath == null);
}

/// Tool state mutations, drawing actions, and flood-fill operations.
extension AppProviderTools on AppProvider {
  bool get _isOriginFloodFillModifierPressed {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    return isFloodFillOriginModifierPressedForPlatform(
      platform: defaultTargetPlatform,
      isAltPressed: keyboard.isAltPressed,
      isControlPressed: keyboard.isControlPressed,
    );
  }

  /// Clones the active selection path when selection-wide fill should override
  /// origin-based flood-fill sampling.
  ui.Path? get _selectionRegionFloodFillOverridePath {
    final ui.Path? selectionPath = selectorModel.path1;
    final bool useSelectionRegionFloodFill = shouldUseSelectionRegionFloodFill(
      isSelectionVisible: selectorModel.isVisible,
      selectionPath: selectionPath,
      isOriginFloodFillModifierPressed: _isOriginFloodFillModifierPressed,
    );
    if (!useSelectionRegionFloodFill || selectionPath == null) {
      return null;
    }
    return ui.Path.from(selectionPath);
  }

  /// Updates an action.
  void updateAction({
    final Offset? start,
    required final Offset end,
    final ActionType? type,
    final Color? colorFill,
    final Color? colorBrush,
  }) {
    if (start != null && type != null && colorFill != null && colorBrush != null) {
      recordExecuteDrawingActionToSelectedLayer(
        action: UserActionDrawing(
          positions: <ui.Offset>[start, end],
          action: type,
          brush: MyBrush(
            color: colorBrush,
            size: brushSize,
          ),
          fillColor: colorFill,
        ),
      );
    } else {
      updateActionEnd(end);
    }
  }

  /// Updates the end of an action.
  void updateActionEnd(final Offset position) {
    if (layers.selectedLayer.lastUserAction != null) {
      layers.selectedLayer.lastUserAction!.positions.last = position;
    }
  }

  /// Appends a line from the last user action.
  void appendLineFromLastUserAction(final Offset positionEndOfNewLine) {
    final UserActionDrawing? last = layers.selectedLayer.lastUserAction;
    if (last == null || last.positions.isEmpty) {
      return;
    }

    final bool canExtendActiveStroke =
        (last.action == ActionType.pencil || last.action == ActionType.eraser) && last.action == selectedAction;
    if (canExtendActiveStroke) {
      layers.selectedLayer.lastActionAppendPosition(position: positionEndOfNewLine);
      layers.repaintCanvas();
      return;
    }

    recordExecuteDrawingActionToSelectedLayer(
      action: UserActionDrawing(
        positions: <ui.Offset>[
          last.positions.last,
          positionEndOfNewLine,
        ],
        action: last.action,
        brush: last.brush,
        clipPath: selectorModel.isVisible ? selectorModel.path1 : null,
      ),
    );
  }

  /// Creates a selection from the tapped flood-fill region when no active
  /// selection exists yet. Returns `true` when the tap was consumed by the new
  /// selection behavior.
  Future<bool> prepareFloodFillSelection(final Offset position) async {
    if (!shouldCreateSelectionFromFloodFillTap(
      selectedAction: selectedAction,
      selectorMode: selectorModel.mode,
      isSelectionVisible: selectorModel.isVisible,
      selectionPath: selectorModel.path1,
    )) {
      return false;
    }

    final FillRegion region = await getRegionPathFromLayerImage(position);
    if (region.path.getBounds().isEmpty) {
      return false;
    }

    selectorModel.isVisible = true;
    selectorModel.isDrawing = false;
    selectorModel.path1 = region.path.shift(region.offset);
    selectorModel.path2 = null;
    selectorModel.points.clear();
    selectorModel.math = SelectorMath.replace;
    update();
    return true;
  }

  /// Performs a flood fill with a solid color.
  void floodFillSolidAction(final Offset position) async {
    if (await prepareFloodFillSelection(position)) {
      return;
    }

    final ui.Image sourceImage = layers.selectedLayer.toImageForStorage(layers.size);
    final ui.Path? clipPath = selectorModel.isVisible ? selectorModel.path1 : null;
    final UserActionDrawing action = await fillService.createFloodFillSolidAction(
      sourceImage: sourceImage,
      position: position,
      fillColor: fillColor,
      halftoneDotColor: fillModel.halftoneEnabled ? fillColor : null,
      halftoneMaxDotSizeFactor: fillModel.halftoneMaxDotSizeFactor,
      tolerance: tolerance,
      clipPath: clipPath,
      regionPathOverride: _selectionRegionFloodFillOverridePath,
    );

    recordExecuteDrawingActionToSelectedLayer(action: action);
  }

  /// Performs a flood fill with a gradient.
  void floodFillGradientAction(final FillModel fillModel) async {
    final ui.Image sourceImage = layers.selectedLayer.toImageForStorage(layers.size);
    final ui.Path? clipPath = selectorModel.isVisible ? selectorModel.path1 : null;
    final UserActionDrawing action = await fillService.createFloodFillGradientAction(
      sourceImage: sourceImage,
      fillModel: fillModel,
      tolerance: tolerance,
      clipPath: clipPath,
      toCanvas: toCanvas,
      regionPathOverride: _selectionRegionFloodFillOverridePath,
    );

    recordExecuteDrawingActionToSelectedLayer(action: action);
  }

  /// Updates the gradient fill.
  void updateGradientFill() {
    repaintToolOptions();
    if (fillModel.isVisible) {
      debounceGradientFill.run(
        () {
          undoProvider.undo();
          floodFillGradientAction(fillModel);
          update();
        },
      );
    }
  }
}
