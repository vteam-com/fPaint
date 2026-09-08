part of 'app_provider.dart';

/// Canvas viewport operations: pan, zoom, scale, coordinate conversion,
/// rotation, flipping, and document lifecycle.
extension AppProviderCanvas on AppProvider {
  /// Clears the canvas.
  void canvasClear(Size size) {
    layers.clear();
    layers.size = size;
    layers.addWhiteBackgroundLayer();
    layers.selectedLayerIndex = 0;
    resetView();
  }

  /// The current canvas-to-screen viewport transform (pan, zoom and rotation).
  ///
  /// Rebuilt only when a viewport field changes, so the precomputed inverse is
  /// reused across the many [toCanvas] calls a single stroke makes.
  ViewportTransform get viewportTransform {
    final ViewportTransform? cached = cachedViewportTransform;
    if (cached != null &&
        cached.offset == canvasOffset &&
        cached.scale == layers.scale &&
        cached.rotation == layers.rotation) {
      return cached;
    }
    final ViewportTransform rebuilt = ViewportTransform(
      offset: canvasOffset,
      scale: layers.scale,
      rotation: layers.rotation,
    );
    cachedViewportTransform = rebuilt;
    return rebuilt;
  }

  /// Converts a screen point to a canvas point.
  Offset toCanvas(Offset point) => viewportTransform.toCanvas(point);

  /// Converts a canvas point to a screen point.
  Offset fromCanvas(Offset point) => viewportTransform.toScreen(point);

  /// Converts a screen-space drag delta into canvas space.
  ///
  /// Unlike a point, a delta must not be translated — and once the viewport is
  /// rotated it must be rotated too, not merely divided by the zoom.
  Offset deltaToCanvas(Offset delta) => viewportTransform.deltaToCanvas(delta);

  /// Applies a scale to the canvas.
  void applyScaleToCanvas({
    required double scaleDelta,
    ui.Offset? anchorPoint,
    bool notifyListener = true,
    bool notifyViewport = false,
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
    } else if (notifyViewport) {
      repaintViewport();
    }
  }

  /// Applies a rotation delta to the viewport, keeping [anchorPoint] fixed.
  ///
  /// A pure view change: no pixel is altered and nothing enters the undo stack.
  /// The canvas point under the user's fingers stays under their fingers, using
  /// the same before/after correction [applyScaleToCanvas] performs for zoom.
  void applyRotationToCanvas({
    required double rotationDelta,
    ui.Offset? anchorPoint,
    bool notifyListener = true,
    bool notifyViewport = false,
  }) {
    if (rotationDelta == 0) {
      return;
    }

    final Offset before = anchorPoint == null ? Offset.zero : toCanvas(anchorPoint);

    for (final GradientPoint point in fillModel.gradientPoints) {
      point.offset = toCanvas(point.offset);
    }

    layers.rotation = layers.rotation + rotationDelta;

    if (anchorPoint != null) {
      // Re-anchor in screen space: the canvas point that was under the anchor
      // has moved, so translate by that screen-space discrepancy.
      final Offset afterScreen = fromCanvas(before);
      canvasOffset += anchorPoint - afterScreen;
    }

    for (final GradientPoint point in fillModel.gradientPoints) {
      point.offset = fromCanvas(point.offset);
    }
    if (notifyListener) {
      update();
    } else if (notifyViewport) {
      repaintViewport();
    }
  }

  /// Resets the viewport rotation to upright, keeping the view centred.
  void resetCanvasRotation({bool notifyListener = true}) {
    if (!layers.isRotated) {
      return;
    }
    applyRotationToCanvas(
      rotationDelta: -layers.rotation,
      anchorPoint: canvasCenter,
      notifyListener: notifyListener,
    );
  }

  /// Gets the center of the canvas in screen coordinates.
  Offset get canvasCenter => fromCanvas(
    Offset(layers.width / AppMath.pair, layers.height / AppMath.pair),
  );

  /// Pans the canvas.
  void canvasPan({
    required Offset offsetDelta,
    bool notifyListener = true,
    bool notifyViewport = false,
  }) {
    canvasOffset += offsetDelta;

    if (fillModel.isVisible) {
      fillModel.gradientPoints.forEach(
        (GradientPoint point) => point.offset += offsetDelta,
      );
    }
    if (notifyListener) {
      update();
    } else if (notifyViewport) {
      repaintViewport();
    }
  }

  /// Centers the canvas within the view.
  ///
  /// Fitting returns the view upright: the centring math below is axis-aligned,
  /// and "fit to window" is also the user's way out of an awkward angle.
  void canvasFitToContainer({
    required double containerWidth,
    required double containerHeight,
  }) {
    layers.rotation = 0;

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

  /// Whether the live viewport-rotation angle readout should be shown.
  bool get isViewportRotationFeedbackVisible => _isViewportRotationFeedbackVisible;

  /// Shows the live viewport-angle readout during a rotate gesture.
  void showViewportRotationFeedback() {
    if (!_isViewportRotationFeedbackVisible) {
      _isViewportRotationFeedbackVisible = true;
    }
    repaintHudOverlay();
  }

  /// Hides the live viewport-angle readout.
  void hideViewportRotationFeedback() {
    if (!_isViewportRotationFeedbackVisible) {
      return;
    }
    _isViewportRotationFeedbackVisible = false;
    repaintHudOverlay();
  }

  /// Resets the view.
  void resetView() {
    canvasOffset = Offset.zero;
    layers.scale = 1;
    layers.rotation = 0;
    update();
  }

  /// Gets whether the canvas resize lock aspect ratio is enabled.
  bool get canvasResizeLockAspectRatio => layers.canvasResizeLockAspectRatio;

  /// Sets whether the canvas resize lock aspect ratio is enabled.
  set canvasResizeLockAspectRatio(bool value) {
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
  Future<void> rotateCanvas90(String actionName) async {
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
  Future<void> flipCanvasHorizontal(String actionName) async {
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
  Future<void> flipCanvasVertical(String actionName) async {
    if (selectorModel.isVisible) {
      await flipSelectionVertical(actionName);
    } else {
      await layers.flipCanvasVertical(actionName);
    }
    update();
  }
}
