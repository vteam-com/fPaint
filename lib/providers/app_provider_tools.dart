import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';

/// Tool state mutations, drawing actions, and flood-fill operations.
extension AppProviderTools on AppProvider {
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
    recordExecuteDrawingActionToSelectedLayer(
      action: UserActionDrawing(
        positions: <ui.Offset>[
          layers.selectedLayer.lastUserAction!.positions.last,
          positionEndOfNewLine,
        ],
        action: layers.selectedLayer.lastUserAction!.action,
        brush: layers.selectedLayer.lastUserAction!.brush,
        clipPath: selectorModel.isVisible ? selectorModel.path1 : null,
      ),
    );
  }

  /// Performs a flood fill with a solid color.
  void floodFillSolidAction(final Offset position) async {
    final ui.Image sourceImage = layers.selectedLayer.toImageForStorage(layers.size);
    final UserActionDrawing action = await fillService.createFloodFillSolidAction(
      sourceImage: sourceImage,
      position: position,
      fillColor: fillColor,
      tolerance: tolerance,
      clipPath: selectorModel.isVisible ? selectorModel.path1 : null,
    );

    recordExecuteDrawingActionToSelectedLayer(action: action);
  }

  /// Performs a flood fill with a gradient.
  void floodFillGradientAction(final FillModel fillModel) async {
    final ui.Image sourceImage = layers.selectedLayer.toImageForStorage(layers.size);
    final UserActionDrawing action = await fillService.createFloodFillGradientAction(
      sourceImage: sourceImage,
      fillModel: fillModel,
      tolerance: tolerance,
      clipPath: selectorModel.isVisible ? selectorModel.path1 : null,
      toCanvas: toCanvas,
    );

    recordExecuteDrawingActionToSelectedLayer(action: action);
  }

  /// Updates the gradient fill.
  void updateGradientFill() {
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
