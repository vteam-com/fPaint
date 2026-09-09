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

  /// Returns the distance between the two contacts controlling touch navigation.
  double _getDistanceBetweenTouchPoints() {
    if (_activePointers.length < AppMath.pair) {
      return 0.0;
    }
    final Offset? firstPosition = _pointerPositions[_activePointers[AppMath.zero]];
    final Offset? secondPosition = _pointerPositions[_activePointers[AppMath.one]];
    if (firstPosition == null || secondPosition == null) {
      return 0.0;
    }
    return (secondPosition - firstPosition).distance;
  }

  /// Returns the midpoint between the first two active touch pointers.
  Offset? _getMultiTouchFocalPoint() {
    if (_activePointers.length < AppMath.pair) {
      return null;
    }
    final Offset? firstPosition = _pointerPositions[_activePointers[AppMath.zero]];
    final Offset? secondPosition = _pointerPositions[_activePointers[AppMath.one]];
    if (firstPosition == null || secondPosition == null) {
      return null;
    }
    return Offset(
      (firstPosition.dx + secondPosition.dx) / AppMath.pair,
      (firstPosition.dy + secondPosition.dy) / AppMath.pair,
    );
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
      appProvider.selectedAction == ActionType.selector &&
      !appProvider.transformModel.isVisible &&
      !appProvider.effectBrushModel.isArmed;

  /// Cancels transient state for a touch that became a pinch or was cancelled.
  /// Pixel/effect brushes must not run their expensive pointer-up commit here.
  void _cancelActiveTouchInteraction(AppProvider appProvider) {
    appProvider.layers.selectedLayer.isUserDrawing = false;
    appProvider.layers.selectedLayer.clearStrokePreview();
    appProvider.hideDrawingToolPreview();
    appProvider.hideWandToleranceHud();
    appProvider.hideFillTolerancePreview();
    appProvider.endTolerancePointerLock();
    appProvider.clearPixelBrushGesture();
    _clearToleranceDragAnchor();
    appProvider.cancelPixelBrushStroke();
    _activePointerId = -1;
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

    appProvider.layers.selectedLayer.isUserDrawing = false;
    // Pair with beginStrokePreview: release the frozen baseline (no-op for tools
    // that never captured one, e.g. smudge/blur, which use the live preview).
    appProvider.layers.selectedLayer.clearStrokePreview();
    final bool isSelectionActive = _isSelectionGesture(appProvider);

    if (_activePointerId == event.pointer) {
      if (_handleEyeDropperPointerEnd(appProvider, event.localPosition)) {
        _activePointerId = -1;
        appProvider.update();
        return;
      }

      if (isSelectionActive) {
        appProvider.selectorCreationEnd();
        _restoreSelectionMath(appProvider);
        if (appProvider.selectorModel.mode != SelectorMode.line || !appProvider.selectorModel.isDrawing) {
          _clearSelectionTapTracking();
        }
      } else if (appProvider.pixelBrushSession.isStrokeActive) {
        appProvider.extendPixelBrushStroke(appProvider.toCanvas(event.localPosition));
        // Marquee stays visible across the (async) one-shot render, switching to
        // a processing shimmer while the commit generates the image, then is
        // cleared once the committed stroke is on the layer.
        appProvider.setPixelBrushCommitting(committing: true);
        await appProvider.commitPixelBrushGesture();
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
      appProvider.cancelPixelBrushStroke();
      appProvider.layers.selectedLayer.clearCache();
      if (!mounted) {
        return;
      }
      final DraftRecoveryController? controller = InheritedScope.maybeOf<DraftRecoveryController>(context);
      if (controller != null) {
        unawaited(controller.flushNow());
      }
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

    final bool isBrushDrop = appProvider.eyeDropPositionForBrush != null;
    final bool isFillDrop = appProvider.eyeDropPositionForFill != null;
    if (isBrushDrop || isFillDrop) {
      if (isBrushDrop) {
        appProvider.eyeDropPositionForBrush = event.localPosition;
      } else {
        appProvider.eyeDropPositionForFill = event.localPosition;
      }
      if (appProvider.isEyeDropShortcutActive && (event.buttons & kPrimaryButton) != 0) {
        unawaited(
          appProvider.layers.getColorAtOffset(adjustedPosition, useCachedImage: true).then<void>((Color? color) {
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
      // The Surface pen eraser (invertedStylus) extends its erase stroke here
      // regardless of the selected tool. It must not fall through into the
      // selection / fill / pixel-brush / armed-effect dispatch below.
      if (event.kind == PointerDeviceKind.invertedStylus) {
        _updateDrawingToolPreview(appProvider, event.localPosition);
        _appendPenEraserStrokeLine(appProvider, adjustedPosition);
        return;
      }

      if (isSelectionActive) {
        if (appProvider.selectorModel.mode == SelectorMode.wand) {
          _updateWandToleranceFromDrag(appProvider, event.localPosition);
        } else {
          appProvider.selectorCreationAdditionalPoint(adjustedPosition);
        }
        return;
      }

      if (appProvider.pixelBrushSession.isStrokeActive) {
        // No live rasterization: just extend the gesture and redraw the swept-
        // band marquee. The smudge/blur is rendered once on pointer-up, so the
        // drag stays responsive at any canvas size and the marquee is the sole
        // feedback (its round-capped band already shows the affected footprint).
        appProvider.extendPixelBrushStroke(adjustedPosition);
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
      _activePointerId = event.pointer;
      _updateDrawingToolPreview(appProvider, event.localPosition);
      if (_canStartDrawingOnSelectedLayer(appProvider)) {
        _startDrawingPointer(appProvider, adjustedPosition, forcedAction: ActionType.eraser);
      }
      return;
    }

    if (_handleEyeDropperPointerStart(appProvider, event.localPosition)) {
      _activePointerId = event.pointer;
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
    return appProvider.selectedAction.isSupported(ActionOptions.brushSize) &&
        appProvider.selectedAction != ActionType.text;
  }

  void _showLockedLayerMessage(AppProvider appProvider) {
    context.showSnackBarMessage(
      context.l10n.layerLockedForEditing(appProvider.layers.selectedLayer.name),
    );
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

  /// Starts a brush/pencil/eraser or pixel-brush stroke at [adjustedPosition]
  /// for the active drawing tool.
  ///
  /// When [forcedAction] is provided (the Surface pen eraser), that action is
  /// drawn instead of the persisted [AppProvider.selectedAction] — the pen
  /// eraser must always erase, and arming it must not mutate the persisted
  /// selected action (which would disturb an armed effect, eyedropper, or wand
  /// selection).
  void _startDrawingPointer(
    AppProvider appProvider,
    ui.Offset adjustedPosition, {
    ActionType? forcedAction,
  }) {
    final ActionType action = forcedAction ?? appProvider.selectedAction;
    appProvider.layers.selectedLayer.isUserDrawing = true;

    // An armed effect is a brush too, but a forced (pen-eraser) stroke always
    // takes precedence: a physical eraser end must not trigger an effect.
    if (appProvider.effectBrushModel.isArmed && forcedAction == null) {
      appProvider.startEffectBrushStroke(adjustedPosition);
      return;
    }

    if (action == ActionType.smudge) {
      appProvider.startPixelBrushStroke(adjustedPosition, PixelBrushMode.smudge);
      return;
    }

    if (action == ActionType.blurBrush) {
      appProvider.startPixelBrushStroke(adjustedPosition, PixelBrushMode.blur);
      return;
    }

    // Freeze the committed composite so the stroke composites baseline + active
    // action each frame instead of replaying the whole stack. Captured before
    // the active action is appended below.
    appProvider.layers.selectedLayer.beginStrokePreview();
    appProvider.recordExecuteDrawingActionToSelectedLayer(
      action: StrokeAction(
        action: action,
        positions: <ui.Offset>[adjustedPosition, adjustedPosition],
        brush: MyBrush(
          color: appProvider.brushColor,
          size: appProvider.brushSize,
          style: appProvider.brushStyle,
          hatch: appProvider.hatchPattern,
          marks: appProvider.hatchMarks,
        ),
        fillColor: appProvider.fillColor,
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
  /// on [AppProvider.selectedAction] being the eraser.
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
        brush: MyBrush(
          color: appProvider.brushColor,
          size: appProvider.brushSize,
          style: appProvider.brushStyle,
          hatch: appProvider.hatchPattern,
          marks: appProvider.hatchMarks,
        ),
        clipPath: appProvider.selectorModel.isVisible ? appProvider.selectorModel.path1 : null,
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
      _activePointerId = -1;
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
