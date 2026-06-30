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
  /// solid fill, or gradient fill initialization.
  Future<void> _handleFillPointerStart(
    final AppProvider appProvider,
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
      appProvider.floodFillSolidAction(
        adjustedPosition,
        sampleAllLayers: sampleAllLayers,
      );
      return;
    }

    if (appProvider.fillModel.gradientPoints.isEmpty) {
      _initializeGradientFill(appProvider, adjustedPosition, sampleAllLayers: sampleAllLayers);
    }
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

  /// Finalizes an active pointer interaction and clears temporary drawing state.
  void _handlePointerEnd(
    final AppProvider appProvider,
    final PointerEvent event,
  ) async {
    appProvider.layers.selectedLayer.isUserDrawing = false;
    // Pair with beginStrokePreview: release the frozen baseline (no-op for tools
    // that never captured one, e.g. smudge/blur, which use the live preview).
    appProvider.layers.selectedLayer.clearStrokePreview();
    final bool isSelectionActive =
        appProvider.selectedAction == ActionType.selector && !appProvider.transformModel.isVisible;

    if (_activePointerId == event.pointer) {
      if (isSelectionActive) {
        appProvider.selectorCreationEnd();
        _restoreSelectionMath(appProvider);
        if (appProvider.selectorModel.mode != SelectorMode.line || !appProvider.selectorModel.isDrawing) {
          _clearSelectionTapTracking();
        }
      } else if (_pixelBrushSourceImage != null) {
        _appendPixelBrushPoint(appProvider.toCanvas(event.localPosition), appProvider.brushSize);
        await _commitPixelBrushStroke(appProvider);
        _clearSelectionTapTracking();
      } else {
        _clearSelectionTapTracking();
      }
      appProvider.hideDrawingToolPreview();
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

  /// Handles pointer move events for drawing, selection, and eyedropper interactions.
  void _handlePointerMove(
    final AppProvider appProvider,
    final PointerEvent event,
  ) {
    if (appProvider.hasActiveTransformOverlay) {
      return;
    }

    final Offset adjustedPosition = appProvider.toCanvas(event.localPosition);
    final bool isSelectionActive =
        appProvider.selectedAction == ActionType.selector && !appProvider.transformModel.isVisible;

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
        appProvider.selectorCreationAdditionalPoint(adjustedPosition);
        return;
      }

      if (_pixelBrushSourceImage != null) {
        PixelBrushProfiler.recordMove();
        // Keep the brush-size marquee tracking the cursor for the whole drag.
        // (Safe now that the GPU stroke has no readback to starve, and the
        // canvas RepaintBoundary stops repaintMainView from re-rasterizing it.)
        _updateDrawingToolPreview(appProvider, event.localPosition);
        _appendPixelBrushPoint(adjustedPosition, appProvider.brushSize);
        // GPU path: synchronous shader dabs displayed immediately. A pointer
        // moves more than one spacing between frames, so — exactly like the CPU
        // stepping in rasterizePixelBrushSegment — interpolate the move into
        // spacing-sized sub-dabs. Dabbing only at the raw pointer position would
        // leave gaps (visible dots) and a large per-dab displacement that pulls
        // the smudge source far off the cursor centre. Each dab is a full-canvas
        // `toImageSync`, so the spacing also bounds the dab count per stroke.
        if (_gpuPixelBrushStroke != null) {
          final double radius = max(
            AppInteraction.smudgeMinimumRadius,
            appProvider.brushSize * AppInteraction.smudgeBrushRadiusFactor,
          );
          final double baseSpacing = max(
            AppInteraction.smudgeInputPointSpacing,
            radius * AppInteraction.smudgeGpuStepSpacingFactor,
          );
          final ui.Offset start = _lastDabCenter ?? adjustedPosition;
          final double dist = (adjustedPosition - start).distance;
          if (dist < baseSpacing) {
            return;
          }
          final GpuPixelBrushStroke stroke = _gpuPixelBrushStroke!;
          // Fine spacing for a seamless trail, but clamp the count for one move
          // so a fast flick widens spacing slightly rather than stalling.
          int steps = (dist / baseSpacing).floor();
          final double spacing = steps > AppInteraction.smudgeGpuMaxDabsPerMove
              ? dist / AppInteraction.smudgeGpuMaxDabsPerMove
              : baseSpacing;
          steps = min(steps, AppInteraction.smudgeGpuMaxDabsPerMove);
          final ui.Offset stepDelta = (adjustedPosition - start) / dist * spacing;
          final Stopwatch? dabWatch = PixelBrushProfiler.startWatch();
          ui.Offset prev = start;
          for (int step = AppMath.one; step <= steps; step++) {
            final ui.Offset cur = start + stepDelta * step.toDouble();
            stroke.dab(
              from: prev,
              to: cur,
              brushSize: appProvider.brushSize,
              intensity: _pixelBrushIntensity,
              mode: _pixelBrushMode,
            );
            prev = cur;
          }
          PixelBrushProfiler.recordElapsed('gpuDab', dabWatch);
          // Advance by whole steps only; the sub-spacing remainder is picked up
          // once the cursor travels another full spacing, keeping displacement
          // constant at `spacing` per dab.
          _lastDabCenter = prev;
          _pixelBrushTargetLayer?.setLivePixelBrushImage(stroke.image);
          appProvider.layers.repaintCanvas();
          return;
        }
        _kickLivePixelBrushPreview(appProvider);
        return;
      }

      _updateDrawingToolPreview(appProvider, event.localPosition);

      if (appProvider.selectedAction == ActionType.fill) {
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

    final bool isSelectionActive =
        appProvider.selectedAction == ActionType.selector && !appProvider.transformModel.isVisible;
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
      await _handleFillPointerStart(appProvider, adjustedPosition);
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
    appProvider.selectorCreationStart(
      adjustedPosition,
      sampleAllLayers: appProvider.selectorModel.mode == SelectorMode.wand && _isSampleAllLayersModifierPressed(),
    );
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
    appProvider.floodFillGradientAction(appProvider.fillModel);
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
