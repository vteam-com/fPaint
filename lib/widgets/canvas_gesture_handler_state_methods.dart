part of 'canvas_gesture_handler.dart';

extension _CanvasGestureHandlerStateMethods on _CanvasGestureHandlerState {
  /// Reads the current keyboard modifier state and temporarily overrides
  /// [selectorModel.math] for the upcoming selection gesture:
  ///   Shift + Option/Alt -> intersect
  ///   Shift             -> add
  ///   Option/Alt        -> remove
  ///   (none)            -> no override; existing math is preserved
  ///
  /// The original value is saved in [_previousSelectorMath] and restored by
  /// [_restoreSelectionMath] once the gesture completes.
  void _applySelectionModifierMath(final AppProvider appProvider) {
    final bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final bool isAltPressed = HardwareKeyboard.instance.isAltPressed;

    if (!isShiftPressed && !isAltPressed) {
      return;
    }

    final SelectorMath overrideMath;
    if (isShiftPressed && isAltPressed) {
      overrideMath = SelectorMath.intersect;
    } else if (isShiftPressed) {
      overrideMath = SelectorMath.add;
    } else {
      overrideMath = SelectorMath.remove;
    }

    _previousSelectorMath = appProvider.selectorModel.math;
    appProvider.selectorModel.math = overrideMath;
    appProvider.repaintToolOptions();
  }

  /// Returns whether drawing may start on the selected layer, surfacing a
  /// message and aborting when the layer is hidden or locked.
  bool _canStartDrawingOnSelectedLayer(final AppProvider appProvider) {
    if (appProvider.layers.selectedLayer.isVisible == false) {
      final AppLocalizations l10n = context.l10n;
      context.showSnackBarMessage(
        l10n.selectionIsHidden,
      );
      return false;
    }

    if (appProvider.isSelectedLayerLocked) {
      _activePointerId = -1;
      _showLockedLayerMessage(appProvider);
      return false;
    }

    return true;
  }

  void _clearSelectionTapTracking() {
    _lastSelectionTapTimestamp = null;
    _lastSelectionTapCanvasPosition = null;
  }

  /// Returns the distance between the first two active touch points.
  ///
  /// Returns 0.0 when fewer than two touch pointers are active.
  double _getDistanceBetweenTouchPoints() {
    if (_pointerPositions.length >= AppMath.pair) {
      final List<Offset> positions = _pointerPositions.values.toList();
      final Offset pos1 = positions[0];
      final Offset pos2 = positions[1];
      return (pos2 - pos1).distance;
    } else {
      return 0.0;
    }
  }

  /// Captures an eyedropper sample at [adjustedPosition] when an eyedropper is
  /// armed. Returns whether the pointer-down was consumed.
  bool _handleEyeDropperPointerStart(
    final AppProvider appProvider,
    final ui.Offset adjustedPosition,
  ) {
    if (appProvider.eyeDropPositionForBrush != null) {
      appProvider.layers.capturePainterToImage();
      appProvider.eyeDropPositionForBrush = adjustedPosition;
      return true;
    }

    if (appProvider.eyeDropPositionForFill != null) {
      appProvider.layers.capturePainterToImage();
      appProvider.eyeDropPositionForFill = adjustedPosition;
      return true;
    }

    return false;
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
    final AppProvider appProvider,
    final ui.Offset screenPosition,
    final ui.Offset adjustedPosition,
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
    final AppProvider appProvider,
    final ui.Offset screenPosition,
    final ui.Offset adjustedPosition, {
    required final bool sampleAllLayers,
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

  /// Handles two-finger pan and pinch updates for manual canvas navigation.
  void _handleMultiTouchUpdate(
    final PointerMoveEvent event,
    final AppProvider appProvider,
    final ShellProvider shellProvider,
  ) {
    appProvider.canvasOffset += event.delta;
    final double newDistance = _getDistanceBetweenTouchPoints();
    final double distanceDelta = _baseDistance - newDistance;

    if (distanceDelta.abs() > AppInteraction.multiTouchScaleThreshold) {
      _scaleFactor = _getDistanceBetweenTouchPoints() / _baseDistance;
      _scaleFactor = max(AppInteraction.minCanvasScale, min(_scaleFactor, AppInteraction.maxCanvasScale));

      final Offset before = appProvider.toCanvas(event.localPosition);
      appProvider.layers.scale = _scaleFactor;
      final Offset after = appProvider.toCanvas(event.localPosition);
      final Offset adjustment = after - before;
      appProvider.canvasOffset += adjustment * appProvider.layers.scale;
    }

    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
    appProvider.repaintViewport();
  }

  /// Whether a canvas gesture should create or extend a selection.
  ///
  /// The selector tool must be active with no transform overlay up, AND no
  /// effect brush armed: an armed effect paints (clipped to the current
  /// selection) just like any other brush, so it takes precedence over the
  /// selector tool instead of starting a new marquee.
  bool _isSelectionGesture(final AppProvider appProvider) =>
      appProvider.selectedAction == ActionType.selector &&
      !appProvider.transformModel.isVisible &&
      !appProvider.effectBrushModel.isArmed;

  /// Finalizes an active pointer interaction and clears temporary drawing state.
  void _handlePointerEnd(
    final AppProvider appProvider,
    final PointerEvent event,
  ) async {
    appProvider.layers.selectedLayer.isUserDrawing = false;
    // Pair with beginStrokePreview: release the frozen baseline (no-op for tools
    // that never captured one, e.g. smudge/blur, which use the live preview).
    appProvider.layers.selectedLayer.clearStrokePreview();
    final bool isSelectionActive = _isSelectionGesture(appProvider);

    if (_activePointerId == event.pointer) {
      if (isSelectionActive) {
        appProvider.selectorCreationEnd();
        _restoreSelectionMath(appProvider);
        if (appProvider.selectorModel.mode != SelectorMode.line || !appProvider.selectorModel.isDrawing) {
          _clearSelectionTapTracking();
        }
      } else if (_pixelBrushLayerRestoreState != null || _effectBrushStroke) {
        _appendPixelBrushPoint(appProvider.toCanvas(event.localPosition), appProvider.brushSize);
        // Marquee stays visible across the (async) one-shot render, switching to
        // a processing shimmer while the commit generates the image, then is
        // cleared once the committed stroke is on the layer.
        appProvider.setPixelBrushCommitting(committing: true);
        if (_effectBrushStroke) {
          await _commitEffectBrushStroke(appProvider);
        } else {
          await _commitPixelBrushStroke(appProvider);
        }
        appProvider.clearPixelBrushGesture();
        _clearSelectionTapTracking();
      } else if (appProvider.selectedAction == ActionType.fill &&
          _toleranceDragAnchorScreen != null &&
          appProvider.fillModel.mode == FillMode.solid) {
        // Solid fill commits on release; gradient fill leaves its handle session
        // open (finalized later via Apply/Cancel) and just falls through.
        _commitSolidFillDrag(appProvider);
        _clearSelectionTapTracking();
      } else {
        _clearSelectionTapTracking();
      }
      appProvider.hideDrawingToolPreview();
      appProvider.hideWandToleranceHud();
      appProvider.hideFillTolerancePreview();
      appProvider.endTolerancePointerLock();
      _clearToleranceDragAnchor();
      _activePointerId = -1;
      _clearPixelBrushStroke();
      appProvider.layers.selectedLayer.clearCache();
      if (!mounted) {
        return;
      }
      final DraftFlusher controller = Provider.of<DraftFlusher>(context, listen: false);
      unawaited(controller.flushNow());
      appProvider.update();
    }
  }

  /// Starts a paint-mode effect stroke. Reuses the pixel-brush gesture capture
  /// (points, bounds, marquee); the armed Adjust effect is committed on
  /// pointer-up by [_commitEffectBrushStroke].
  void _startEffectBrushStroke(
    final AppProvider appProvider,
    final ui.Offset adjustedPosition,
  ) {
    _clearPixelBrushStroke();
    _effectBrushStroke = true;
    _pixelBrushClipPath = appProvider.selectorModel.isVisible && appProvider.selectorModel.path1 != null
        ? ui.Path.from(appProvider.selectorModel.path1!)
        : null;
    _appendPixelBrushPoint(adjustedPosition, appProvider.brushSize);
    appProvider.showPixelBrushGesture(
      points: _pixelBrushStrokePoints,
      size: appProvider.brushSize,
    );
  }

  /// Commits the active paint-mode effect stroke through the provider.
  Future<void> _commitEffectBrushStroke(final AppProvider appProvider) async {
    final ui.Rect? patchBounds = _pixelBrushStrokePatchBounds;
    final SelectionEffect? effect = appProvider.effectBrushModel.effect;
    if (patchBounds == null || effect == null || _pixelBrushStrokePoints.length < AppMath.one) {
      return;
    }
    await appProvider.commitEffectBrushStroke(
      effect: effect,
      strength: appProvider.effectBrushModel.strength,
      size: appProvider.effectBrushModel.size,
      strokePoints: List<ui.Offset>.of(_pixelBrushStrokePoints),
      strokeBounds: patchBounds,
      brushSize: appProvider.brushSize,
      clipPath: _pixelBrushClipPath,
    );
  }

  /// Handles pointer move events for drawing, selection, and eyedropper interactions.
  void _handlePointerMove(
    final AppProvider appProvider,
    final PointerEvent event,
  ) {
    if (appProvider.hasActiveTransformOverlay) {
      return;
    }

    final Offset adjustedPosition = appProvider.toCanvas(event.localPosition);
    final bool isSelectionActive = _isSelectionGesture(appProvider);

    if (appProvider.eyeDropPositionForBrush != null) {
      appProvider.eyeDropPositionForBrush = event.localPosition;
      appProvider.repaintMainView();
      return;
    }
    if (appProvider.eyeDropPositionForFill != null) {
      appProvider.eyeDropPositionForFill = event.localPosition;
      appProvider.repaintMainView();
      return;
    }

    if (isSelectionActive &&
        appProvider.selectorModel.mode == SelectorMode.line &&
        appProvider.selectorModel.isDrawing) {
      appProvider.selectorCreationPreview(adjustedPosition);
      return;
    }

    if (event.buttons == 1 && _activePointerId == event.pointer) {
      if (isSelectionActive) {
        if (appProvider.selectorModel.mode == SelectorMode.wand) {
          _updateWandToleranceFromDrag(appProvider, event.localPosition);
        } else {
          appProvider.selectorCreationAdditionalPoint(adjustedPosition);
        }
        return;
      }

      if (_pixelBrushLayerRestoreState != null || _effectBrushStroke) {
        // No live rasterization: just extend the gesture and redraw the swept-
        // band marquee. The smudge/blur is rendered once on pointer-up, so the
        // drag stays responsive at any canvas size and the marquee is the sole
        // feedback (its round-capped band already shows the affected footprint).
        _appendPixelBrushPoint(adjustedPosition, appProvider.brushSize);
        appProvider.showPixelBrushGesture(
          points: _pixelBrushStrokePoints,
          size: appProvider.brushSize,
        );
        return;
      }

      _updateDrawingToolPreview(appProvider, event.localPosition);

      if (appProvider.selectedAction == ActionType.fill) {
        // Solid fill: drag horizontally to adjust the tolerance and re-preview
        // the filled region live (gradient fill has no tolerance drag anchor).
        if (_toleranceDragAnchorScreen != null) {
          _updateFillToleranceFromDrag(appProvider, event.localPosition);
        }
        return;
      }

      if (appProvider.selectedAction == ActionType.pencil) {
        appProvider.appendLineFromLastUserAction(adjustedPosition);
      } else if (appProvider.selectedAction == ActionType.eraser) {
        appProvider.appendLineFromLastUserAction(adjustedPosition);
      } else if (appProvider.selectedAction == ActionType.brush) {
        appProvider.layers.selectedLayer.lastActionAppendPosition(position: adjustedPosition);
        appProvider.layers.repaintCanvas();
      } else {
        appProvider.updateAction(end: adjustedPosition);
        appProvider.layers.repaintCanvas();
      }
    }
  }

  /// Starts pointer interactions including drawing, selection, fill, and text placement.
  ///
  /// Acts as a dispatcher: each tool's behaviour lives in a focused handler so this
  /// method only decides which one applies for the current pointer-down.
  void _handlePointerStart(
    final AppProvider appProvider,
    final PointerDownEvent event,
  ) async {
    if (appProvider.hasActiveTransformOverlay) {
      return;
    }

    if (event.buttons != 1 || _activePointerId != -1) {
      return;
    }

    final ui.Offset adjustedPosition = appProvider.toCanvas(event.localPosition);

    if (_handleEyeDropperPointerStart(appProvider, adjustedPosition)) {
      return;
    }

    _activePointerId = event.pointer;

    final bool isSelectionActive = _isSelectionGesture(appProvider);
    if (isSelectionActive) {
      _handleSelectionPointerStart(appProvider, event, adjustedPosition);
      return;
    }

    _updateDrawingToolPreview(appProvider, event.localPosition);

    if (!_canStartDrawingOnSelectedLayer(appProvider)) {
      return;
    }

    if (appProvider.selectedAction == ActionType.text) {
      _handleTextPointerStart(appProvider, adjustedPosition);
      return;
    }

    if (appProvider.selectedAction == ActionType.fill) {
      await _handleFillPointerStart(appProvider, event.localPosition, adjustedPosition);
      return;
    }

    _startDrawingPointer(appProvider, adjustedPosition);
  }

  /// Begins a selection at [adjustedPosition], applying modifier math and
  /// closing an in-progress straight-line selection on a double tap.
  void _handleSelectionPointerStart(
    final AppProvider appProvider,
    final PointerDownEvent event,
    final ui.Offset adjustedPosition,
  ) {
    _applySelectionModifierMath(appProvider);
    if (_tryCloseStraightLineSelectionOnDoubleTap(appProvider, event, adjustedPosition)) {
      return;
    }
    final bool sampleAllLayers =
        appProvider.selectorModel.mode == SelectorMode.wand && _isSampleAllLayersModifierPressed();
    if (appProvider.selectorModel.mode == SelectorMode.wand) {
      // Anchor the sample tap so a subsequent drag can grow/shrink the selection
      // live (Edge Detection = tap to sample, drag on canvas to adjust).
      _toleranceDragAnchorScreen = event.localPosition;
      _toleranceDragAnchorCanvas = adjustedPosition;
      _toleranceDragStartTolerance = appProvider.tolerance;
      _toleranceDragSampleAllLayers = sampleAllLayers;
      _toleranceDragLastApplied = appProvider.tolerance;
      appProvider.showWandToleranceHud(tolerance: appProvider.tolerance, position: event.localPosition);
      // Pin the pointer at the sample tap: the horizontal scrub adjusts tolerance
      // in place instead of dragging the cursor across the canvas.
      appProvider.beginTolerancePointerLock(event.localPosition);
    }
    appProvider.selectorCreationStart(
      adjustedPosition,
      sampleAllLayers: sampleAllLayers,
    );
  }

  /// Computes the live tolerance for the current horizontal drag since the
  /// sample tap and fires haptics on change. Returns the new tolerance to apply,
  /// or null when there is no active drag anchor or the tolerance is unchanged.
  /// Feedback (wand finger-HUD vs. fill top-bar) is left to the callers. Shared
  /// by the Edge Detection wand and the paint-bucket tolerance drags.
  int? _toleranceForDragStep(
    final AppProvider appProvider,
    final Offset screenPosition,
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
    final AppProvider appProvider,
    final Offset screenPosition,
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
    final AppProvider appProvider,
    final Offset screenPosition,
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
  void _commitSolidFillDrag(final AppProvider appProvider) {
    final Offset? anchorCanvas = _toleranceDragAnchorCanvas;
    final bool hadPreview = appProvider.fillPreviewAction != null;
    // Cancels the pending render, invalidates in-flight ones, and commits the
    // transient (if any) as a single undo entry.
    appProvider.commitFillPreview();
    if (!hadPreview && anchorCanvas != null) {
      appProvider.floodFillSolidAction(anchorCanvas, sampleAllLayers: _toleranceDragSampleAllLayers);
    }
  }

  /// Clears the tolerance-drag anchor once the gesture ends or is cancelled
  /// (shared by the Edge Detection wand and the solid-fill tolerance drag).
  void _clearToleranceDragAnchor() {
    _toleranceDragAnchorScreen = null;
    _toleranceDragAnchorCanvas = null;
    _toleranceDragLastApplied = null;
  }

  /// Selects an existing text object under [adjustedPosition] or opens the text
  /// dialog to create a new one. Releases the active pointer because a modal may
  /// consume the matching pointer-up.
  void _handleTextPointerStart(
    final AppProvider appProvider,
    final ui.Offset adjustedPosition,
  ) {
    TextObject? selectedText;

    for (final UserActionDrawing action in appProvider.layers.selectedLayer.actionStack.reversed) {
      if (action.textObject != null && action.textObject!.containsPoint(adjustedPosition)) {
        selectedText = action.textObject;
        break;
      }
    }

    if (selectedText != null) {
      _activePointerId = -1;
      appProvider.adoptTextToolStateFromObject(selectedText);
      appProvider.selectedTextObject = selectedText;
      return;
    }

    _activePointerId = -1;
    _showTextDialog(appProvider, adjustedPosition);
  }

  void _handleUserPanningTheCanvas(
    final ShellProvider shellProvider,
    final AppProvider appProvider,
    final Offset offsetDelta,
  ) {
    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
    appProvider.canvasPan(
      offsetDelta: offsetDelta,
      notifyListener: false,
      notifyViewport: true,
    );
  }

  /// Applies user-driven canvas scaling around [anchorPoint].
  void _handleUserScalingTheCanvas(
    final ShellProvider shellProvider,
    final AppProvider appProvider,
    final Offset anchorPoint,
    final double scaleDelta,
  ) {
    if (scaleDelta == 1) {
      return;
    }

    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;

    appProvider.applyScaleToCanvas(
      scaleDelta: scaleDelta,
      anchorPoint: anchorPoint,
      notifyListener: false,
      notifyViewport: true,
    );
  }

  /// Seeds the gradient fill handles around [adjustedPosition] for the active
  /// linear or radial fill mode and commits the initial gradient action.
  void _initializeGradientFill(
    final AppProvider appProvider,
    final ui.Offset adjustedPosition, {
    required final bool sampleAllLayers,
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

  /// Returns whether the current keyboard state requests sampling from all visible layers.
  bool _isSampleAllLayersModifierPressed() {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    return keyboard.isControlPressed || keyboard.isMetaPressed;
  }

  /// Updates the shell interaction modality based on the current pointer kind.
  void _registerInputModality(
    final ShellProvider shellProvider,
    final PointerDeviceKind kind,
  ) {
    switch (kind) {
      case PointerDeviceKind.touch:
        shellProvider.interactionInputModality = InteractionInputModality.touch;
        return;
      case PointerDeviceKind.stylus:
      case PointerDeviceKind.invertedStylus:
        shellProvider.interactionInputModality = InteractionInputModality.pen;
        return;
      case PointerDeviceKind.mouse:
      case PointerDeviceKind.trackpad:
      case PointerDeviceKind.unknown:
        shellProvider.interactionInputModality = InteractionInputModality.mouse;
        return;
    }
  }

  /// Restores [selectorModel.math] to the value captured before a
  /// modifier-key override, then clears the saved value.
  void _restoreSelectionMath(final AppProvider appProvider) {
    if (_previousSelectorMath != null) {
      appProvider.selectorModel.math = _previousSelectorMath!;
      _previousSelectorMath = null;
      appProvider.repaintToolOptions();
    }
  }

  /// Returns whether the current tool should show a live size marker while drawing.
  bool _shouldShowDrawingToolPreview(final AppProvider appProvider) {
    return appProvider.selectedAction.isSupported(ActionOptions.brushSize) &&
        appProvider.selectedAction != ActionType.text;
  }

  void _showLockedLayerMessage(final AppProvider appProvider) {
    context.showSnackBarMessage(
      context.l10n.layerLockedForEditing(appProvider.layers.selectedLayer.name),
    );
  }

  /// Shows a text editor dialog at the given canvas [position].
  ///
  /// When the user finishes editing, the resulting [TextObject] is recorded
  /// as a drawing action on the currently selected layer.
  void _showTextDialog(final AppProvider appProvider, final Offset position) {
    final AppLocalizations l10n = context.l10n;
    showAppBottomSheet<void>(
      context: context,
      barrierColor: AppColors.transparent,
      builder: (final BuildContext _) {
        return TextEditorDialog(
          title: l10n.addText,
          submitLabel: l10n.addText,
          position: position,
          initialText: '',
          initialStyle: appProvider.textToolState.copy(),
          onSubmitted: (final TextObject textObject) {
            appProvider.adoptTextToolStateFromObject(textObject);
            appProvider.recordExecuteDrawingActionToSelectedLayer(
              action: UserActionDrawing(
                action: ActionType.text,
                positions: <ui.Offset>[position],
                textObject: textObject,
              ),
            );
          },
        );
      },
    );
  }

  /// Starts a brush/pencil/eraser or pixel-brush stroke at [adjustedPosition]
  /// for the active drawing tool.
  void _startDrawingPointer(
    final AppProvider appProvider,
    final ui.Offset adjustedPosition,
  ) {
    appProvider.layers.selectedLayer.isUserDrawing = true;

    if (appProvider.effectBrushModel.isArmed) {
      _startEffectBrushStroke(appProvider, adjustedPosition);
      return;
    }

    if (appProvider.selectedAction == ActionType.smudge) {
      _startPixelBrushStroke(appProvider, adjustedPosition, PixelBrushMode.smudge);
      return;
    }

    if (appProvider.selectedAction == ActionType.blurBrush) {
      _startPixelBrushStroke(appProvider, adjustedPosition, PixelBrushMode.blur);
      return;
    }

    // Freeze the committed composite so the stroke composites baseline + active
    // action each frame instead of replaying the whole stack. Captured before
    // the active action is appended below.
    appProvider.layers.selectedLayer.beginStrokePreview();
    appProvider.recordExecuteDrawingActionToSelectedLayer(
      action: UserActionDrawing(
        action: appProvider.selectedAction,
        positions: <ui.Offset>[adjustedPosition, adjustedPosition],
        brush: MyBrush(
          color: appProvider.brushColor,
          size: appProvider.brushSize,
          style: appProvider.brushStyle,
        ),
        fillColor: appProvider.fillColor,
      ),
    );
  }

  /// Returns whether [kind] can report hover location before pointer down.
  bool _supportsHoverPreview(final PointerDeviceKind kind) {
    return kind == PointerDeviceKind.mouse ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus;
  }

  /// Closes an in-progress line selection when two taps occur within the
  /// configured time and distance thresholds.
  bool _tryCloseStraightLineSelectionOnDoubleTap(
    final AppProvider appProvider,
    final PointerDownEvent event,
    final Offset canvasPosition,
  ) {
    if (appProvider.selectorModel.mode != SelectorMode.line || !appProvider.selectorModel.isDrawing) {
      return false;
    }

    final Duration eventTimestamp = event.timeStamp;
    final Duration? previousTimestamp = _lastSelectionTapTimestamp;
    final Offset? previousPosition = _lastSelectionTapCanvasPosition;
    final bool isDoubleTap =
        previousTimestamp != null &&
        previousPosition != null &&
        eventTimestamp - previousTimestamp <= AppInteraction.selectionDoubleTapTimeout &&
        (canvasPosition - previousPosition).distance <=
            AppInteraction.selectionDoubleTapSlop / appProvider.layers.scale;

    _lastSelectionTapTimestamp = eventTimestamp;
    _lastSelectionTapCanvasPosition = canvasPosition;

    if (!isDoubleTap) {
      return false;
    }

    final bool didClose = appProvider.selectorCreationClosePolygon();
    if (didClose) {
      _activePointerId = -1;
      _restoreSelectionMath(appProvider);
      _clearSelectionTapTracking();
    }
    return didClose;
  }

  /// Updates the live drawing marker to the current pointer location.
  void _updateDrawingToolPreview(
    final AppProvider appProvider,
    final Offset localPosition,
  ) {
    if (!_shouldShowDrawingToolPreview(appProvider)) {
      return;
    }

    appProvider.showDrawingToolPreviewAt(
      size: appProvider.brushSize,
      position: localPosition,
    );
  }
}
