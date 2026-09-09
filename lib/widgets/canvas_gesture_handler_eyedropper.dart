part of 'canvas_gesture_handler.dart';

extension _CanvasGestureHandlerStateEyedropperMethods on _CanvasGestureHandlerState {
  /// Captures an eyedropper sample at [screenPosition] when an eyedropper is armed.
  bool _handleEyeDropperPointerStart(AppProvider appProvider, ui.Offset screenPosition) {
    final bool isBrushDrop = appProvider.eyeDropPositionForBrush != null;
    final bool isFillDrop = appProvider.eyeDropPositionForFill != null;
    if (!isBrushDrop && !isFillDrop) {
      return false;
    }

    if (isBrushDrop) {
      appProvider.eyeDropPositionForBrush = screenPosition;
    } else {
      appProvider.eyeDropPositionForFill = screenPosition;
    }

    final Offset canvasPosition = appProvider.toCanvas(screenPosition);
    unawaited(
      appProvider.layers.getColorAtOffset(canvasPosition, useCachedImage: true).then<void>((Color? color) {
        if (color != null) {
          if (isBrushDrop) {
            appProvider.brushColor = color;
          } else {
            appProvider.fillColor = color;
          }
          appProvider.update();
        }
      }),
    );

    unawaited(appProvider.layers.capturePainterToImage().then<void>((_) => appProvider.repaintMainView()));
    return true;
  }

  /// Finalizes eyedropper sampling at [screenPosition] on pointer release.
  bool _handleEyeDropperPointerEnd(AppProvider appProvider, ui.Offset screenPosition) {
    final bool isBrushDrop = appProvider.eyeDropPositionForBrush != null;
    final bool isFillDrop = appProvider.eyeDropPositionForFill != null;
    if (!isBrushDrop && !isFillDrop) {
      return false;
    }

    if (!appProvider.isEyeDropShortcutActive) {
      appProvider.eyeDropPositionForBrush = null;
      appProvider.eyeDropPositionForFill = null;
    }

    final Offset canvasPosition = appProvider.toCanvas(screenPosition);
    unawaited(
      appProvider.layers.getColorAtOffset(canvasPosition, useCachedImage: true).then<void>((Color? color) {
        if (color != null) {
          if (isBrushDrop) {
            appProvider.brushColor = color;
          } else {
            appProvider.fillColor = color;
          }
          appProvider.update();
        }
      }),
    );

    return true;
  }

  /// Starts a flood fill at [adjustedPosition], honouring an active selection,
  /// solid fill, or gradient fill initialization. [screenPosition] is the raw
  /// pointer position used to anchor the tolerance drag and HUD.
  ///
  /// Both modes use the same tap-to-fill / drag-horizontally-to-adjust-tolerance
  /// gesture as the Edge Detection wand: the region is previewed live as the
  /// tolerance changes. Solid fill commits on pointer-up; gradient fill leaves
  /// its handle session open on release (finalized via Apply/Cancel).
  Future<void> _handleFillPointerStart(
    AppProvider appProvider,
    ui.Offset screenPosition,
    ui.Offset adjustedPosition,
  ) async {
    final bool sampleAllLayers = _isSampleAllLayersModifierPressed();

    if (await appProvider.prepareFloodFillSelection(
      adjustedPosition,
      sampleAllLayers: sampleAllLayers,
    )) {
      return;
    }

    if (appProvider.fillModel.mode == FillMode.solid) {
      appProvider.fillModel.gradientPoints.clear();
      appProvider.fillModel.sampleAllLayers = sampleAllLayers;
      _startFillToleranceDrag(appProvider, screenPosition, adjustedPosition, sampleAllLayers: sampleAllLayers);
      appProvider.updateSolidFillPreview(adjustedPosition, sampleAllLayers: sampleAllLayers);
      return;
    }

    // Gradient: seed the handle session on the first tap (it re-previews itself),
    // then anchor the tolerance drag so dragging adjusts the region's tolerance.
    if (appProvider.fillModel.gradientPoints.isEmpty) {
      _initializeGradientFill(appProvider, adjustedPosition, sampleAllLayers: sampleAllLayers);
    }
    _startFillToleranceDrag(appProvider, screenPosition, adjustedPosition, sampleAllLayers: sampleAllLayers);
  }

  /// Anchors a tap-to-fill / drag-to-adjust-tolerance gesture (shared by solid
  /// and gradient fill) at [screenPosition] and shows the top Fill Tolerance bar.
  void _startFillToleranceDrag(
    AppProvider appProvider,
    ui.Offset screenPosition,
    ui.Offset adjustedPosition, {
    required bool sampleAllLayers,
  }) {
    _toleranceDragAnchorScreen = screenPosition;
    _toleranceDragAnchorCanvas = adjustedPosition;
    _toleranceDragStartTolerance = appProvider.tolerance;
    _toleranceDragSampleAllLayers = sampleAllLayers;
    _toleranceDragLastApplied = appProvider.tolerance;
    appProvider.showFillTolerancePreview(appProvider.tolerance);
    // Pin the pointer at the tap: the horizontal scrub adjusts tolerance in
    // place instead of dragging the cursor across the canvas.
    appProvider.beginTolerancePointerLock(screenPosition);
  }

  /// Computes the live tolerance for the current horizontal drag since the
  /// sample tap and fires haptics on change. Returns the new tolerance to apply,
  /// or null when there is no active drag anchor or the tolerance is unchanged.
  /// Feedback (wand finger-HUD vs. fill top-bar) is left to the callers. Shared
  /// by the Edge Detection wand and the paint-bucket tolerance drags.
  int? _toleranceForDragStep(
    AppProvider appProvider,
    Offset screenPosition,
  ) {
    final Offset? anchorScreen = _toleranceDragAnchorScreen;
    if (anchorScreen == null || _toleranceDragAnchorCanvas == null) {
      return null;
    }
    final int tolerance = appProvider.wandToleranceForDrag(
      _toleranceDragStartTolerance,
      screenPosition.dx - anchorScreen.dx,
    );
    if (tolerance == _toleranceDragLastApplied) {
      return null;
    }
    triggerWandToleranceHaptic(_toleranceDragLastApplied ?? tolerance, tolerance);
    _toleranceDragLastApplied = tolerance;
    return tolerance;
  }

  /// Resamples the wand selection at the fixed anchor for the dragged tolerance.
  void _updateWandToleranceFromDrag(
    AppProvider appProvider,
    Offset screenPosition,
  ) {
    final int? tolerance = _toleranceForDragStep(appProvider, screenPosition);
    // Keep the HUD pinned at the sample tap (the pointer is locked there), not
    // at the moving finger.
    appProvider.showWandToleranceHud(
      tolerance: _toleranceDragLastApplied ?? appProvider.tolerance,
      position: _toleranceDragAnchorScreen ?? screenPosition,
    );
    if (tolerance == null) {
      return;
    }
    appProvider.wandSelectionResampleAt(
      _toleranceDragAnchorCanvas!,
      tolerance: tolerance,
      sampleAllLayers: _toleranceDragSampleAllLayers,
    );
  }

  /// Re-previews the fill at the fixed anchor for the dragged tolerance. Solid
  /// fill re-resolves the region from the anchor; gradient fill re-resolves from
  /// its handles.
  void _updateFillToleranceFromDrag(
    AppProvider appProvider,
    Offset screenPosition,
  ) {
    final int? tolerance = _toleranceForDragStep(appProvider, screenPosition);
    if (tolerance == null) {
      return;
    }
    // Apply the tolerance so the preview (and, for solid, the pointer-up commit)
    // use it, and update the top Fill Tolerance bar.
    appProvider.tolerance = tolerance;
    appProvider.showFillTolerancePreview(tolerance);
    if (appProvider.fillModel.mode == FillMode.solid) {
      appProvider.updateSolidFillPreview(_toleranceDragAnchorCanvas!, sampleAllLayers: _toleranceDragSampleAllLayers);
    } else {
      appProvider.updateGradientPreview();
    }
  }

  /// Commits the solid-fill tolerance drag on pointer-up: the previewed transient
  /// is committed as one undoable action, or — when a quick tap released before
  /// the debounced preview rendered — a fresh fill is committed at the anchor.
  void _commitSolidFillDrag(AppProvider appProvider) {
    final Offset? anchorCanvas = _toleranceDragAnchorCanvas;
    final bool hadPreview = appProvider.fillPreviewAction != null;
    // Cancels the pending render, invalidates in-flight ones, and commits the
    // transient (if any) as a single undo entry.
    appProvider.commitFillPreview();
    if (!hadPreview && anchorCanvas != null) {
      appProvider.floodFillSolidAction(anchorCanvas, sampleAllLayers: _toleranceDragSampleAllLayers);
    }
  }

  /// Anchors a hold-modifiers-and-drag brush resize at [screenPosition].
  ///
  /// Cmd+Option (macOS) / Ctrl+Alt (elsewhere) plus a horizontal drag adjusts
  /// brush size in place: the pointer is pinned at the anchor so the gesture
  /// reads as scrubbing a value rather than dragging across the canvas, and the
  /// existing brush-size HUD ring previews the new diameter at that point.
  void _startBrushSizeDrag(AppProvider appProvider, ui.Offset screenPosition) {
    _brushSizeDragAnchorScreen = screenPosition;
    _brushSizeDragStartSize = appProvider.brushSize;
    appProvider.beginTolerancePointerLock(screenPosition);
    appProvider.showDrawingToolPreviewAt(
      size: appProvider.brushSize,
      position: screenPosition,
    );
  }

  /// Applies the horizontal drag since the resize anchor to the brush size.
  void _updateBrushSizeFromDrag(AppProvider appProvider, ui.Offset screenPosition) {
    final ui.Offset? anchor = _brushSizeDragAnchorScreen;
    if (anchor == null) {
      return;
    }
    final double size = appProvider.applyBrushSizeDrag(
      startSize: _brushSizeDragStartSize,
      screenDx: screenPosition.dx - anchor.dx,
    );
    // Keep the preview ring pinned at the anchor (the pointer is locked there),
    // so it grows and shrinks around a fixed centre.
    appProvider.showDrawingToolPreviewAt(size: size, position: anchor);
  }

  /// Applies a mouse-wheel [event] scroll to the brush size while Ctrl+Alt
  /// (or Cmd+Opt on macOS) is held, showing the size HUD ring at the pointer.
  ///
  /// Unlike the anchored drag gesture each wheel tick changes the size from its
  /// current value (no anchor state), so a consecutive chain of notches keeps
  /// accumulating through the clamped tool range.
  void _updateBrushSizeFromWheelScroll(
    AppProvider appProvider,
    PointerScrollEvent event,
  ) {
    final double size = appProvider.applyBrushSizeWheelScroll(
      startSize: appProvider.brushSize,
      scrollDy: event.scrollDelta.dy,
    );
    appProvider.showDrawingToolPreviewAt(
      size: size,
      position: event.localPosition,
    );
  }

  /// Whether a hold-modifiers-and-drag brush resize is in progress.
  bool get _isBrushSizeDragActive => _brushSizeDragAnchorScreen != null;

  /// Ends a brush-resize drag, releasing the pointer lock and letting the
  /// size HUD fade on its usual timer.
  void _endBrushSizeDrag(AppProvider appProvider) {
    if (_brushSizeDragAnchorScreen == null) {
      return;
    }
    _brushSizeDragAnchorScreen = null;
    appProvider.endTolerancePointerLock();
    appProvider.hideDrawingToolPreview();
  }

  /// Clears the tolerance-drag anchor once the gesture ends or is cancelled
  /// (shared by the Edge Detection wand and the solid-fill tolerance drag).
  void _clearToleranceDragAnchor() {
    _toleranceDragAnchorScreen = null;
    _toleranceDragAnchorCanvas = null;
    _toleranceDragLastApplied = null;
  }

  /// Seeds the gradient fill handles around [adjustedPosition] for the active
  /// linear or radial fill mode and commits the initial gradient action.
  void _initializeGradientFill(
    AppProvider appProvider,
    ui.Offset adjustedPosition, {
    required bool sampleAllLayers,
  }) {
    appProvider.fillModel.sampleAllLayers = sampleAllLayers;
    if (appProvider.fillModel.mode == FillMode.linear) {
      appProvider.fillModel.addPoint(
        GradientPoint(
          offset: appProvider.fromCanvas(
            adjustedPosition + const Offset(-AppInteraction.linearFillHandleOffset, 0),
          ),
          color: appProvider.fillModel.gradientStopColors.first,
        ),
      );
      appProvider.fillModel.addPoint(
        GradientPoint(
          offset: appProvider.fromCanvas(
            adjustedPosition + const Offset(AppInteraction.linearFillHandleOffset, 0),
          ),
          color: appProvider.fillModel.gradientStopColors.last,
        ),
      );
    } else if (appProvider.fillModel.mode == FillMode.radial) {
      appProvider.fillModel.addPoint(
        GradientPoint(
          offset: appProvider.fromCanvas(adjustedPosition),
          color: appProvider.fillModel.gradientStopColors.first,
        ),
      );
      appProvider.fillModel.addPoint(
        GradientPoint(
          offset: appProvider.fromCanvas(
            adjustedPosition +
                const Offset(AppInteraction.radialFillHandleOffset, AppInteraction.radialFillHandleOffset),
          ),
          color: appProvider.fillModel.gradientStopColors.last,
        ),
      );
    }
    appProvider.fillModel.isVisible = true;
    // Start the live preview session (non-committed, no undo entry) rather than
    // committing the fill; Apply/Cancel on the fill overlay finalizes it.
    appProvider.updateGradientPreview();
    appProvider.update();
  }
}
