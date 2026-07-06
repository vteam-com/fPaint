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
  Future<bool> prepareFloodFillSelection(
    final Offset position, {
    final bool sampleAllLayers = false,
  }) async {
    if (!shouldCreateSelectionFromFloodFillTap(
      selectedAction: selectedAction,
      selectorMode: selectorModel.mode,
      isSelectionVisible: selectorModel.isVisible,
      selectionPath: selectorModel.path1,
    )) {
      return false;
    }

    final FillRegion region = await getRegionPathFromLayerImage(
      position,
      sampleAllLayers: sampleAllLayers,
    );
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

  /// Performs a flood fill with a solid color, committed as one undoable action.
  void floodFillSolidAction(
    final Offset position, {
    final bool sampleAllLayers = false,
  }) async {
    if (await prepareFloodFillSelection(
      position,
      sampleAllLayers: sampleAllLayers,
    )) {
      return;
    }

    final UserActionDrawing? action = await _buildSolidFillAction(position, sampleAllLayers: sampleAllLayers);
    if (action == null) {
      return;
    }
    recordExecuteDrawingActionToSelectedLayer(action: action);
  }

  /// Builds a solid flood-fill action at [position], resolving the region from
  /// the **cached** layer pixels (+ isolate) so repeated builds during a drag
  /// skip the full-canvas readback. Honours fill color, halftone, and any
  /// selection clip. Returns null when the resolved region is empty.
  Future<UserActionDrawing?> _buildSolidFillAction(
    final Offset position, {
    required final bool sampleAllLayers,
  }) async {
    final FillImageData? imageData = await getSelectedLayerFillImageData(sampleAllLayers: sampleAllLayers);
    if (imageData == null) {
      return null;
    }
    final UserActionDrawing action = await fillService.createFloodFillSolidAction(
      imageData: imageData,
      position: position,
      fillColor: fillColor,
      halftoneDotColor: fillModel.halftoneEnabled ? fillColor : null,
      halftoneMaxDotSizeFactor: fillModel.halftoneMaxDotSizeFactor,
      tolerance: tolerance,
      clipPath: selectorModel.isVisible ? selectorModel.path1 : null,
      regionPathOverride: _selectionRegionFloodFillOverridePath,
    );
    return (action.path?.getBounds().isEmpty ?? true) ? null : action;
  }

  /// Builds a gradient flood-fill action from [fillModel], resolving the region
  /// from the **cached** layer pixels (+ isolate). Returns null when the gradient
  /// config or resolved region is unusable (an empty, path-less action).
  Future<UserActionDrawing?> _buildGradientFillAction(final FillModel fillModel) async {
    final FillImageData? imageData = await getSelectedLayerFillImageData(sampleAllLayers: fillModel.sampleAllLayers);
    if (imageData == null) {
      return null;
    }
    final UserActionDrawing action = await fillService.createFloodFillGradientAction(
      imageData: imageData,
      fillModel: fillModel,
      tolerance: tolerance,
      clipPath: selectorModel.isVisible ? selectorModel.path1 : null,
      toCanvas: toCanvas,
      regionPathOverride: _selectionRegionFloodFillOverridePath,
    );
    return action.path == null ? null : action;
  }

  /// Rebuilds the live solid-fill preview at [position] as a **held** action the
  /// canvas overlay paints — never appended to the layer, so re-previewing while
  /// dragging the tolerance costs O(region path), not a full-canvas re-composite.
  /// The region resolve is cached + isolate-run; a version token drops stale
  /// async results. Committed on pointer-up via [AppProvider.commitFillPreview].
  Future<void> updateSolidFillPreview(
    final Offset position, {
    required final bool sampleAllLayers,
  }) async {
    if (isSelectedLayerLocked) {
      return;
    }
    final int requestVersion = ++fillPreviewRenderVersion;
    final UserActionDrawing? action = await _buildSolidFillAction(position, sampleAllLayers: sampleAllLayers);
    if (requestVersion != fillPreviewRenderVersion) {
      return;
    }
    fillPreviewAction = action;
    repaintMainView();
  }

  /// Rebuilds the live gradient-fill preview as a **held** action the canvas
  /// overlay paints — never appended to the layer. Re-resolves the region from
  /// the current handles (cached + isolate) and repaints the overlay; a version
  /// token drops stale async results. Finalized via
  /// [AppProvider.applyGradientPreview] / [AppProvider.cancelGradientPreview].
  Future<void> updateGradientPreview() async {
    repaintToolOptions();
    if (!fillModel.isVisible || isSelectedLayerLocked) {
      return;
    }
    final int requestVersion = ++fillPreviewRenderVersion;
    final UserActionDrawing? action = await _buildGradientFillAction(fillModel);
    if (requestVersion != fillPreviewRenderVersion || !fillModel.isVisible) {
      return;
    }
    fillPreviewAction = action;
    repaintMainView();
  }
}
