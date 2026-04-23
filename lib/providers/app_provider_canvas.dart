import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_selection.dart';

/// Canvas viewport operations: pan, zoom, scale, coordinate conversion,
/// rotation, flipping, and document lifecycle.
extension AppProviderCanvas on AppProvider {
  /// Clears the canvas.
  void canvasClear(final Size size) {
    layers.clear();
    layers.size = size;
    layers.addWhiteBackgroundLayer();
    layers.selectedLayerIndex = 0;
    resetView();
  }

  /// Converts a screen point to a canvas point.
  Offset toCanvas(final Offset point) {
    return (point - canvasOffset) / layers.scale;
  }

  /// Converts a canvas point to a screen point.
  Offset fromCanvas(final Offset point) {
    return (point * layers.scale) + canvasOffset;
  }

  /// Applies a scale to the canvas.
  void applyScaleToCanvas({
    required final double scaleDelta,
    final ui.Offset? anchorPoint,
    final bool notifyListener = true,
  }) {
    final Offset before = anchorPoint == null ? Offset.zero : toCanvas(anchorPoint);

    for (final GradientPoint point in fillModel.gradientPoints) {
      point.offset = toCanvas(point.offset);
    }

    layers.scale = layers.scale * scaleDelta;

    final Offset after = anchorPoint == null ? Offset.zero : toCanvas(anchorPoint);
    final Offset offsetDelta = (before - after);

    canvasOffset -= offsetDelta * layers.scale;

    for (final GradientPoint point in fillModel.gradientPoints) {
      point.offset = fromCanvas(point.offset);
    }
    if (notifyListener) {
      update();
    }
  }

  /// Gets the center of the canvas.
  Offset get canvasCenter => Offset(
    canvasOffset.dx + (layers.width / AppMath.pair) * layers.scale,
    canvasOffset.dy + (layers.height / AppMath.pair) * layers.scale,
  );

  /// Pans the canvas.
  void canvasPan({
    required final Offset offsetDelta,
    final bool notifyListener = true,
  }) {
    canvasOffset += offsetDelta;

    if (fillModel.isVisible) {
      fillModel.gradientPoints.forEach(
        (final GradientPoint point) => point.offset += offsetDelta,
      );
    }
    if (notifyListener) {
      update();
    }
  }

  /// Centers the canvas within the view.
  void canvasFitToContainer({
    required final double containerWidth,
    required final double containerHeight,
  }) {
    final double scaleX = containerWidth / layers.width;
    final double scaleY = containerHeight / layers.height;
    final double targetScale = min(scaleX, scaleY) * AppVisual.fitToContainerScale;
    final double adjustedScale = targetScale / layers.scale;

    applyScaleToCanvas(
      scaleDelta: adjustedScale,
      anchorPoint: canvasOffset,
      notifyListener: false,
    );

    final double offsetX = ((containerWidth - (layers.width * layers.scale)) / AppMath.pair) - canvasOffset.dx;
    final double offsetY = ((containerHeight - (layers.height * layers.scale)) / AppMath.pair) - canvasOffset.dy;
    final Offset offsetDelta = Offset(offsetX, offsetY);

    canvasPan(offsetDelta: offsetDelta, notifyListener: false);
  }

  /// Resets the view.
  void resetView() {
    canvasOffset = Offset.zero;
    layers.scale = 1;
    update();
  }

  /// Gets whether the canvas resize lock aspect ratio is enabled.
  bool get canvasResizeLockAspectRatio => layers.canvasResizeLockAspectRatio;

  /// Sets whether the canvas resize lock aspect ratio is enabled.
  set canvasResizeLockAspectRatio(final bool value) {
    layers.canvasResizeLockAspectRatio = value;
    update();
  }

  /// Creates a new document from an image in the clipboard.
  void newDocumentFromClipboardImage() async {
    final ui.Image? clipboardImage = await getImageFromClipboard();
    if (clipboardImage != null) {
      final double width = clipboardImage.width.toDouble();
      final double height = clipboardImage.height.toDouble();
      final Size newCanvasSize = Size(width, height);
      canvasClear(newCanvasSize);
      layers.selectedLayer.addImage(imageToAdd: clipboardImage);
      update();
    }
  }

  /// Rotates 90 degrees clockwise.
  ///
  /// When a selection exists, only the selected region on the active layer
  /// is rotated.  Otherwise the entire canvas (all layers) is rotated.
  Future<void> rotateCanvas90(final String actionName) async {
    if (selectorModel.isVisible) {
      await rotateSelection90(actionName);
      update();
    } else {
      await layers.rotateCanvas90Clockwise();
      resetView();
    }
  }

  /// Flips horizontally (left ↔ right).
  ///
  /// When a selection exists, only the selected region on the active layer
  /// is flipped.  Otherwise the entire canvas (all layers) is flipped.
  Future<void> flipCanvasHorizontal(final String actionName) async {
    if (selectorModel.isVisible) {
      await flipSelectionHorizontal(actionName);
    } else {
      await layers.flipCanvasHorizontal(actionName);
    }
    update();
  }

  /// Flips vertically (top ↔ bottom).
  ///
  /// When a selection exists, only the selected region on the active layer
  /// is flipped.  Otherwise the entire canvas (all layers) is flipped.
  Future<void> flipCanvasVertical(final String actionName) async {
    if (selectorModel.isVisible) {
      await flipSelectionVertical(actionName);
    } else {
      await layers.flipCanvasVertical(actionName);
    }
    update();
  }
}
