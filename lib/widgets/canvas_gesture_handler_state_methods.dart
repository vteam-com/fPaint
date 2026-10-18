part of 'canvas_gesture_handler.dart';

extension _CanvasGestureHandlerStateMethods on _CanvasGestureHandlerState {
  /// Whether Brush strokes follow Force Touch trackpad pressure (Settings).
  bool get _trackpadPressureEnabled => AppPreferences.of(context).trackpadPressure;

  /// Reads the current keyboard modifier state and temporarily overrides
  /// [selectorModel.math] for the upcoming selection gesture:
  ///   Shift + Option/Alt -> intersect
  ///   Shift             -> add
  ///   Option/Alt        -> remove
  ///   (none)            -> no override; existing math is preserved
  ///
  /// The original value is saved in [_previousSelectorMath] and restored by
  /// [_restoreSelectionMath] once the gesture completes.
  void _applySelectionModifierMath(AppProvider appProvider) {
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
  bool _canStartDrawingOnSelectedLayer(AppProvider appProvider) {
    if (appProvider.layers.selectedLayer.isVisible == false) {
      final AppLocalizations l10n = context.l10n;
      context.showSnackBarMessage(
        l10n.selectionIsHidden,
      );
      return false;
    }

    if (!guardSelectedLayerUnlocked(context, appProvider)) {
      _releaseActivePointer();
      return false;
    }

    return true;
  }

  /// Whether an eraser stroke ([isEraser]) erases every visible, unlocked
  /// layer: the eraser (or the pen's eraser end, [isForced]) under the sticky
  /// "All layers" scope. An armed effect brush still wins over a non-forced
  /// stroke.
  bool _isCrossLayerEraserStroke(
    AppProvider appProvider, {
    required bool isEraser,
    bool isForced = false,
  }) {
    return isEraser && (isForced || !appProvider.effectBrushModel.isArmed) && appProvider.isCrossLayerEraserScope;
  }

  /// Returns whether a stroke may start. A cross-layer erase only needs some
  /// visible, unlocked layer; when none exists the selected layer is hidden or
  /// locked too, so its message explains why nothing happens.
  bool _canStartDrawing(
    AppProvider appProvider, {
    required bool isEraser,
    bool isForced = false,
  }) {
    if (_isCrossLayerEraserStroke(appProvider, isEraser: isEraser, isForced: isForced) &&
        appProvider.hasCrossLayerEditTargets) {
      return true;
    }
    return _canStartDrawingOnSelectedLayer(appProvider);
  }

  /// Releases the active pointer and forgets the gesture it started.
  void _releaseActivePointer() {
    _activePointerId = -1;
    _activeGesture = null;
  }

  void _clearSelectionTapTracking() {
    _lastSelectionTapTimestamp = null;
    _lastSelectionTapCanvasPosition = null;
  }

  /// Allows a navigation update only after both controlling contacts advance.
  bool _shouldProcessMultiTouchUpdate(int pointer) {
    if (_activePointers.length < AppMath.pair) {
      return false;
    }

    final int firstPointer = _activePointers[AppMath.zero];
    final int secondPointer = _activePointers[AppMath.one];
    if (pointer != firstPointer && pointer != secondPointer) {
      return false;
    }

    _multiTouchPointersMoved.add(pointer);
    return _multiTouchPointersMoved.contains(firstPointer) && _multiTouchPointersMoved.contains(secondPointer);
  }

  /// Handles synchronized two-finger panning and pinch scaling.
  void _handleMultiTouchUpdate(
    AppProvider appProvider,
    ShellProvider shellProvider,
  ) {
    final double newDistance = _getDistanceBetweenTouchPoints();
    final Offset? focalPoint = _getMultiTouchFocalPoint();
    final Offset? previousFocalPoint = _lastMultiTouchFocalPoint;
    if (_lastScaleDistance <= 0.0 || newDistance <= 0.0 || focalPoint == null || previousFocalPoint == null) {
      return;
    }

    appProvider.canvasPan(
      offsetDelta: focalPoint - previousFocalPoint,
      notifyListener: false,
    );

    final double scaleFactor = newDistance / _lastScaleDistance;
    if ((scaleFactor - AppMath.one).abs() >= AppInteraction.touchPinchScaleDeadzone) {
      appProvider.applyScaleToCanvas(
        scaleDelta: scaleFactor,
        anchorPoint: focalPoint,
        notifyListener: false,
      );
    }

    // Two-finger twist shares this gesture with pan and pinch, so the canvas
    // can be turned, moved and zoomed in one continuous motion about the same
    // focal point.
    final double? contactAngle = _getTouchContactAngle();
    final double? previousContactAngle = _lastTouchContactAngle;
    if (contactAngle != null) {
      if (previousContactAngle != null) {
        _applyGestureTwist(
          appProvider,
          shellProvider,
          normalizeRadians(contactAngle - previousContactAngle),
          focalPoint,
        );
      }
      _lastTouchContactAngle = contactAngle;
    }

    _lastScaleDistance = newDistance;
    _lastMultiTouchFocalPoint = focalPoint;
    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
    _scheduleViewportRepaint(appProvider);
  }

  /// Whether a canvas gesture should create or extend a selection.
  ///
  /// The selector tool must be active with no transform overlay up, AND no
  /// effect brush armed: an armed effect paints (clipped to the current
  /// selection) just like any other brush, so it takes precedence over the
  /// selector tool instead of starting a new marquee.
  bool _isSelectionGesture(AppProvider appProvider) =>
      appProvider.selectedTool == ToolKind.selector &&
      !appProvider.transformModel.isVisible &&
      !appProvider.effectBrushModel.isArmed;

  /// Cancels transient state for a touch that became a pinch or was cancelled.
  /// Pixel/effect brushes must not run their expensive pointer-up commit here.
  void _cancelActiveTouchInteraction(AppProvider appProvider) {
    appProvider.layers.selectedLayer.isUserDrawing = false;
    appProvider.layers.selectedLayer.clearStrokePreview();
    appProvider.endCrossLayerEraserStroke();
    appProvider.clearPixelBrushGesture();
    _resetTransientPointerState(appProvider);
  }

  /// Hides the per-gesture HUDs and previews, releases the tolerance pointer
  /// lock and drag anchor, drops any uncommitted pixel-brush stroke, and
  /// releases the active pointer. Shared by pointer-up and touch-cancel.
  void _resetTransientPointerState(AppProvider appProvider) {
    appProvider.hideDrawingToolPreview();
    appProvider.hideWandToleranceHud();
    appProvider.hideFillTolerancePreview();
    appProvider.endTolerancePointerLock();
    _clearToleranceDragAnchor();
    appProvider.cancelPixelBrushStroke();
    _releaseActivePointer();
  }

  /// Finalizes an active pointer interaction and clears temporary drawing state.
  void _handlePointerEnd(
    AppProvider appProvider,
    PointerEvent event,
  ) async {
    // A resize scrub never touched the layer, so it releases here instead of
    // running the drawing teardown (stroke commit, cache clear, draft flush).
    if (_isBrushSizeDragActive) {
      if (_activePointerId == event.pointer) {
        _endBrushSizeDrag(appProvider);
        _activePointerId = -1;
        appProvider.update();
      }
      return;
    }

    final _ToolGesture? gesture = _activePointerId == event.pointer ? _activeGesture : null;
    appProvider.layers.selectedLayer.isUserDrawing = false;
    if (event is PointerUpEvent) {
      gesture?.lift(appProvider);
    }
    // Pair with beginStrokePreview: fold the finished stroke into the display
    // projection, or release the frozen baseline (no-op for tools that never
    // captured one, e.g. smudge/blur, which use the live preview).
    appProvider.layers.selectedLayer.finishStrokePreview();
    appProvider.endCrossLayerEraserStroke();

    if (_activePointerId == event.pointer) {
      // Single-shot: the pick commits on release and the puck disarms, so the
      // next stroke paints instead of re-picking.
      if (appProvider.layerPickerPosition != null) {
        _releaseActivePointer();
        appProvider.disarmLayerPicker();
        unawaited(_pickLayerOwningPixel(appProvider, appProvider.toCanvas(event.localPosition)));
        return;
      }

      if (_handleEyeDropperPointerEnd(appProvider, event.localPosition)) {
        _releaseActivePointer();
        appProvider.update();
        return;
      }

      // Awaited only when the gesture truly waits, so a synchronous release
      // finishes before a still-awaiting start of the same quick tap resumes.
      final FutureOr<void> ended = gesture?.end(this, appProvider, event);
      if (ended is Future<void>) {
        await ended;
      }
      if (gesture == null) {
        _clearSelectionTapTracking();
      }
      _resetTransientPointerState(appProvider);
      if (gesture?.maintainsLayerCaches != true) {
        appProvider.layers.selectedLayer.clearCache();
      }
      if (!mounted) {
        return;
      }
      // No recovery flush here: a draft re-encodes every layer (seconds on a
      // large canvas), so it is left to the controller's debounce/max-wait and
      // to the app-lifecycle flush rather than run on every pen-up.
      appProvider.update();
    }
  }

  /// Handles pointer move events for drawing, selection, and eyedropper interactions.
  void _handlePointerMove(
    AppProvider appProvider,
    PointerEvent event,
  ) {
    if (appProvider.hasActiveTransformOverlay) {
      return;
    }

    appProvider.lastPointerPosition = event.localPosition;

    if (_isBrushSizeDragActive) {
      if (_activePointerId == event.pointer) {
        _updateBrushSizeFromDrag(appProvider, event.localPosition);
      }
      return;
    }

    final Offset adjustedPosition = appProvider.toCanvas(event.localPosition);
    final bool isSelectionActive = _isSelectionGesture(appProvider);

    if (appProvider.layerPickerPosition != null) {
      appProvider.layerPickerPosition = event.localPosition;
      appProvider.repaintMainView();
      return;
    }

    final bool? isBrushDrop = appProvider.moveActiveEyeDrop(event.localPosition);
    if (isBrushDrop != null) {
      if (appProvider.isEyeDropShortcutActive && (event.buttons & kPrimaryButton) != 0) {
        unawaited(_adoptEyeDropColor(appProvider, adjustedPosition, isBrushDrop: isBrushDrop));
      }
      appProvider.repaintMainView();
      return;
    }

    if (isSelectionActive &&
        appProvider.selectorModel.mode == SelectorMode.line &&
        appProvider.selectorModel.isDrawing) {
      appProvider.selectorCreationPreview(adjustedPosition);
      return;
    }

    if ((event.buttons & kPrimaryButton) != 0 && _activePointerId == event.pointer) {
      _activeGesture?.move(this, appProvider, event, adjustedPosition);
    }
  }

  /// Starts pointer interactions including drawing, selection, fill, and text placement.
  ///
  /// Claims the cross-cutting gestures first (resize chord, pen eraser, layer
  /// picker, eyedropper); anything else starts the selected tool's
  /// [_ToolGesture], which then owns this pointer's moves and release.
  void _handlePointerStart(
    AppProvider appProvider,
    PointerDownEvent event,
  ) async {
    if (appProvider.hasActiveTransformOverlay) {
      return;
    }

    // A valid stroke press must carry the primary "operation" bit (the pen tip
    // / finger / mouse button is down). The Windows Surface pen's eraser end is
    // reported as an [PointerDeviceKind.invertedStylus] whose buttons combine
    // the stylus-contact bit (== kPrimaryButton) with the stylus-secondary /
    // eraser bit, so it is accepted here too (the old `buttons == 1` exact test
    // silently dropped eraser contact, which reports buttons == 0x05).
    final bool isPenEraser = event.kind == PointerDeviceKind.invertedStylus;
    if ((event.buttons & kPrimaryButton) == 0 || _activePointerId != -1) {
      return;
    }

    // Cmd+Option (macOS) / Ctrl+Alt (elsewhere) turns the press into a brush
    // resize scrub. Claimed before every tool gesture so the drag never also
    // paints, samples, or starts a selection.
    if (appProvider.isBrushSizeDragModifierPressed && _shouldShowDrawingToolPreview(appProvider)) {
      _activePointerId = event.pointer;
      _startBrushSizeDrag(appProvider, event.localPosition);
      return;
    }

    final ui.Offset adjustedPosition = appProvider.toCanvas(event.localPosition);

    // The pen eraser physically should always erase, regardless of the armed
    // tool, so it takes precedence over tool-specific gestures (eyedropper,
    // selection, text, fill, smudge/blur, armed effects). It is routed straight
    // into the drawing path with a forced eraser action and needs no toggle of
    // the persisted selected action (which would disturb the armed effect,
    // eyedropper, and wand-selection state).
    if (isPenEraser) {
      await _startGesture(const _PenEraserGesture(), appProvider, event, adjustedPosition);
      return;
    }

    // Shift+Alt+click selects the topmost visible layer that owns the pixel
    // under the pointer instead of drawing, so the artist can find which
    // layer to pick without hunting through the panel.
    if (appProvider.isLayerPickerModifierActive) {
      _activePointerId = event.pointer;
      unawaited(_pickLayerOwningPixel(appProvider, adjustedPosition));
      return;
    }

    // The armed picker puck tracks the pointer while it is down and commits on
    // release, so a finger can be dragged into place while the puck (offset
    // from the contact point) shows which layer is about to be picked.
    if (appProvider.layerPickerPosition != null) {
      _activePointerId = event.pointer;
      appProvider.layerPickerPosition = event.localPosition;
      return;
    }

    if (_handleEyeDropperPointerStart(appProvider, event.localPosition)) {
      _activePointerId = event.pointer;
      return;
    }

    await _startGesture(_gestureFor(appProvider), appProvider, event, adjustedPosition);
  }

  /// Makes [gesture] the active pointer's gesture and starts it.
  FutureOr<void> _startGesture(
    _ToolGesture gesture,
    AppProvider appProvider,
    PointerDownEvent event,
    ui.Offset adjustedPosition,
  ) {
    _activePointerId = event.pointer;
    _activeGesture = gesture;
    return gesture.start(this, appProvider, event, adjustedPosition);
  }

  /// Begins a selection at [adjustedPosition], applying modifier math and
  /// closing an in-progress straight-line selection on a double tap.
  void _handleSelectionPointerStart(
    AppProvider appProvider,
    PointerDownEvent event,
    ui.Offset adjustedPosition,
  ) {
    _applySelectionModifierMath(appProvider);
    if (_tryCloseStraightLineSelectionOnDoubleTap(appProvider, event, adjustedPosition)) {
      return;
    }
    final bool sampleAllLayers =
        appProvider.selectorModel.mode == SelectorMode.wand &&
        (appProvider.selectorModel.allLayers || _isSampleAllLayersModifierPressed());
    if (appProvider.selectorModel.mode == SelectorMode.wand) {
      // Anchor the sample tap so a subsequent drag can grow/shrink the selection
      // live (Edge Detection = tap to sample, drag on canvas to adjust).
      _beginToleranceDrag(
        appProvider,
        event.localPosition,
        adjustedPosition,
        sampleAllLayers: sampleAllLayers,
        showFeedback: () =>
            appProvider.showWandToleranceHud(tolerance: appProvider.tolerance, position: event.localPosition),
      );
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
  /// Selects an existing text object under [adjustedPosition] or opens the text
  /// dialog to create a new one. Releases the active pointer because a modal may
  /// consume the matching pointer-up.
  void _handleTextPointerStart(
    AppProvider appProvider,
    ui.Offset adjustedPosition,
  ) {
    TextObject? selectedText;

    for (final UserActionDrawing action in appProvider.layers.selectedLayer.actionStack.reversed) {
      if (action.textObject != null && action.textObject!.containsPoint(adjustedPosition)) {
        selectedText = action.textObject;
        break;
      }
    }

    // A modal may consume the matching pointer-up, so the pointer is released
    // now rather than on release.
    _releaseActivePointer();
    if (selectedText != null) {
      appProvider.adoptTextToolStateFromObject(selectedText);
      appProvider.selectedTextObject = selectedText;
      return;
    }

    _showTextDialog(appProvider, adjustedPosition);
  }

  void _handleUserPanningTheCanvas(
    ShellProvider shellProvider,
    AppProvider appProvider,
    Offset offsetDelta,
  ) {
    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
    appProvider.canvasPan(
      offsetDelta: offsetDelta,
      notifyListener: false,
    );
    _scheduleViewportRepaint(appProvider);
  }

  /// Applies user-driven canvas scaling around [anchorPoint].
  void _handleUserScalingTheCanvas(
    ShellProvider shellProvider,
    AppProvider appProvider,
    Offset anchorPoint,
    double scaleDelta,
  ) {
    if (scaleDelta == 1) {
      return;
    }

    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;

    appProvider.applyScaleToCanvas(
      scaleDelta: scaleDelta,
      anchorPoint: anchorPoint,
      notifyListener: false,
    );
    _scheduleViewportRepaint(appProvider);
  }

  /// Returns whether the current keyboard state requests sampling from all visible layers.
  bool _isSampleAllLayersModifierPressed() {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    return keyboard.isControlPressed || keyboard.isMetaPressed;
  }

  /// Updates the shell interaction modality based on the current pointer kind.
  void _registerInputModality(ShellProvider shellProvider, PointerDeviceKind kind) {
    switch (kind) {
      case PointerDeviceKind.touch:
        shellProvider.interactionInputModality = InteractionInputModality.touch;
      case PointerDeviceKind.stylus:
      case PointerDeviceKind.invertedStylus:
        shellProvider.interactionInputModality = InteractionInputModality.pen;
      case PointerDeviceKind.mouse:
      case PointerDeviceKind.trackpad:
      case PointerDeviceKind.unknown:
        shellProvider.interactionInputModality = InteractionInputModality.mouse;
    }
  }

  /// Restores [selectorModel.math] to the value captured before a
  /// modifier-key override, then clears the saved value.
  void _restoreSelectionMath(AppProvider appProvider) {
    if (_previousSelectorMath != null) {
      appProvider.selectorModel.math = _previousSelectorMath!;
      _previousSelectorMath = null;
      appProvider.repaintToolOptions();
    }
  }

  /// Returns whether the current tool should show a live size marker while drawing.
  bool _shouldShowDrawingToolPreview(AppProvider appProvider) {
    // An armed pick-layer gesture already owns the cursor with its loupe, so
    // the brush-size ring stays hidden until the pick commits.
    return appProvider.canAdjustBrushSize && !appProvider.isLayerPickerActive;
  }

  /// Selects the topmost visible layer owning the pixel at canvas
  /// [canvasPosition] and adopts that pixel's color as the active paint color,
  /// surfacing a snackbar with the outcome. Triggered by the Shift+Alt
  /// click-to-pick-layer chord and by the armed on-canvas picker puck.
  Future<void> _pickLayerOwningPixel(
    AppProvider appProvider,
    ui.Offset canvasPosition,
  ) async {
    final LayerPixelPick pick = await appProvider.layers.pickPixelAt(canvasPosition);
    if (!mounted) {
      return;
    }

    final LayerProvider? owningLayer = pick.owningLayer;
    if (owningLayer == null) {
      context.showSnackBarMessage(context.l10n.layerPickerNoLayerFound);
      return;
    }

    appProvider.layers.selectedLayerIndex = appProvider.layers.getLayerIndex(owningLayer);
    HapticFeedback.selectionClick();
    context.showSnackBarMessage(context.l10n.layerPickerSelected(owningLayer.name));

    // The pick doubles as an eyedrop: the pixel that identified the layer also
    // becomes the active paint color, so one gesture answers both "which layer
    // is this?" and "what color is this?".
    final Color? color = pick.color;
    if (color != null) {
      if (appProvider.selectedTool == ToolKind.fill) {
        appProvider.fillColor = color;
      } else {
        appProvider.brushColor = color;
      }
    }
    appProvider.update();
  }

  /// Shows a text editor dialog at the given canvas [position].
  ///
  /// When the user finishes editing, the resulting [TextObject] is recorded
  /// as a drawing action on the currently selected layer.
  void _showTextDialog(AppProvider appProvider, Offset position) {
    final AppLocalizations l10n = context.l10n;
    showAppBottomSheet<void>(
      context: context,
      barrierColor: AppColors.transparent,
      builder: (BuildContext _) {
        // The sheet is pushed onto the overlay, above the editor's provider
        // scope; re-provide the layer model so a color picker opened from the
        // text editor can still resolve [LayersProvider.of].
        return InheritedControllerScope<LayersProvider>(
          controller: appProvider.layers,
          child: TextEditorDialog(
            title: l10n.addText,
            submitLabel: l10n.addText,
            position: position,
            initialText: '',
            initialStyle: appProvider.textToolState.copy(),
            onSubmitted: (TextObject textObject) {
              appProvider.adoptTextToolStateFromObject(textObject);
              appProvider.recordExecuteDrawingActionToSelectedLayer(
                action: TextAction(
                  positions: <ui.Offset>[position],
                  textObject: textObject,
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Starts a [StrokeAction] of [type] at [adjustedPosition] on the selected
  /// layer, with [pressures] when the stroke is pressure-sensitive.
  void _beginStroke(
    AppProvider appProvider,
    ActionType type,
    ui.Offset adjustedPosition, {
    List<double>? pressures,
  }) {
    appProvider.layers.selectedLayer.isUserDrawing = true;
    // Freeze the committed composite so the stroke composites baseline + active
    // action each frame instead of replaying the whole stack. Captured before
    // the active action is appended below.
    appProvider.layers.selectedLayer.beginStrokePreview();
    appProvider.recordExecuteDrawingActionToSelectedLayer(
      action: StrokeAction(
        action: type,
        positions: <ui.Offset>[adjustedPosition, adjustedPosition],
        brush: appProvider.currentBrush,
        fillColor: appProvider.fillColor,
        pressures: pressures,
      ),
    );
  }

  /// Extends the Surface pen eraser (invertedStylus) stroke toward
  /// [adjustedPosition], appending to the active eraser stroke when it continues
  /// or starting a new eraser segment otherwise.
  ///
  /// Mirrors the pencil/eraser line extension in
  /// [AppProvider.appendLineFromLastUserAction] but is driven by the physical
  /// eraser side of the pen rather than the selected tool, so it never depends
  /// on [AppProvider.selectedTool] being the eraser.
  void _appendPenEraserStrokeLine(
    AppProvider appProvider,
    Offset adjustedPosition,
  ) {
    final UserActionDrawing? last = appProvider.layers.selectedLayer.lastUserAction;
    if (last == null || last.positions.isEmpty) {
      return;
    }

    if (last.action == ActionType.eraser) {
      appProvider.layers.selectedLayer.lastActionAppendPosition(position: adjustedPosition);
      appProvider.layers.repaintCanvas();
      return;
    }

    appProvider.recordExecuteDrawingActionToSelectedLayer(
      action: StrokeAction(
        positions: <Offset>[
          last.positions.last,
          adjustedPosition,
        ],
        action: ActionType.eraser,
        brush: appProvider.currentBrush,
        clipPath: appProvider.selectorModel.activeClipPath,
      ),
    );
  }

  /// Returns whether [kind] can report hover location before pointer down.
  bool _supportsHoverPreview(PointerDeviceKind kind) {
    return kind == PointerDeviceKind.mouse ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus;
  }

  /// Closes an in-progress line selection when two taps occur within the
  /// configured time and distance thresholds.
  bool _tryCloseStraightLineSelectionOnDoubleTap(
    AppProvider appProvider,
    PointerDownEvent event,
    Offset canvasPosition,
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
      _releaseActivePointer();
      _restoreSelectionMath(appProvider);
      _clearSelectionTapTracking();
    }
    return didClose;
  }

  /// Updates the live drawing marker to the current pointer location.
  void _updateDrawingToolPreview(
    AppProvider appProvider,
    Offset localPosition,
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
