// ignore: fcheck_one_class_per_file
part of 'canvas_gesture_handler.dart';

/// One tool's canvas pointer behaviour (Strategy).
///
/// The handler resolves a gesture once per pointer-down ([_gestureFor]),
/// after its cross-cutting pre-emptions (resize chord, layer picker,
/// eyedropper), then routes that pointer's moves and release to it. A tool
/// that behaves like an existing one needs only a [ToolKind] entry with the
/// matching [ToolGestureKind]; nothing here changes.
abstract class _ToolGesture {
  const _ToolGesture();

  /// Starts the gesture on pointer-down at [canvasPosition].
  FutureOr<void> start(
    _CanvasGestureHandlerState handler,
    AppProvider app,
    PointerDownEvent event,
    Offset canvasPosition,
  );

  /// Extends the gesture for a primary-button move of its pointer; a tap
  /// gesture ignores moves.
  void move(
    _CanvasGestureHandlerState _,
    AppProvider _,
    PointerEvent _,
    Offset _,
  ) {}

  /// Runs when the pen or finger actually lifts (not on a cancel), before the
  /// stroke preview is released.
  void lift(AppProvider _) {}

  /// Whether the gesture keeps the layer's caches valid itself, so the generic
  /// pen-up cache clear must not run after it.
  bool get maintainsLayerCaches => false;

  /// Finishes the gesture when its pointer is released or cancelled.
  ///
  /// Synchronous unless the gesture truly waits (a pixel-brush commit): a
  /// quick tap delivers its release while the start is still awaiting, and the
  /// start relies on the release having finished synchronously.
  FutureOr<void> end(
    _CanvasGestureHandlerState handler,
    AppProvider _,
    PointerEvent _,
  ) {
    handler._clearSelectionTapTracking();
  }
}

/// Resolves the gesture for the selected tool.
///
/// An armed effect is a brush too, so it replaces every gesture except the
/// tap tools (text, fill), which keep their own behaviour.
_ToolGesture _gestureFor(AppProvider app) {
  final ToolGestureKind kind = app.selectedTool.gesture;
  final bool tapTool = kind == ToolGestureKind.text || kind == ToolGestureKind.fill;
  if (app.effectBrushModel.isArmed && !tapTool) {
    return const _PixelBrushGesture();
  }
  return switch (kind) {
    ToolGestureKind.polyline => const _PolylineGesture(),
    ToolGestureKind.pressureStroke => const _PressureStrokeGesture(),
    ToolGestureKind.shape => const _ShapeGesture(),
    ToolGestureKind.pixelBrush => const _PixelBrushGesture(),
    ToolGestureKind.fill => const _FillGesture(),
    ToolGestureKind.text => const _TextGesture(),
    ToolGestureKind.selection => const _SelectionGesture(),
  };
}

/// A gesture that edits the selected layer: it shows the brush-size ring and
/// refuses a hidden or locked layer before [begin] runs.
abstract class _LayerEditGesture extends _ToolGesture {
  const _LayerEditGesture();

  @override
  FutureOr<void> start(
    _CanvasGestureHandlerState handler,
    AppProvider app,
    PointerDownEvent event,
    Offset canvasPosition,
  ) {
    handler._updateDrawingToolPreview(app, event.localPosition);
    if (!handler._canStartDrawing(app, isEraser: app.selectedTool == ToolKind.eraser)) {
      // Nothing started, so this pointer's moves must not draw.
      handler._activeGesture = null;
      return null;
    }
    return begin(handler, app, event, canvasPosition);
  }

  /// Starts the edit once the layer accepts it.
  FutureOr<void> begin(
    _CanvasGestureHandlerState handler,
    AppProvider app,
    PointerDownEvent event,
    Offset canvasPosition,
  );
}

/// A freehand or shape stroke recorded as a [StrokeAction] of the tool's
/// record type.
abstract class _StrokeGesture extends _LayerEditGesture {
  const _StrokeGesture();

  @override
  void begin(
    _CanvasGestureHandlerState handler,
    AppProvider app,
    PointerDownEvent event,
    Offset canvasPosition,
  ) {
    final bool isEraser = app.selectedTool == ToolKind.eraser;
    if (handler._isCrossLayerEraserStroke(app, isEraser: isEraser)) {
      app.startCrossLayerEraserStroke(canvasPosition);
      return;
    }
    handler._beginStroke(
      app,
      app.selectedTool.recordType!,
      canvasPosition,
      pressures: pressuresFor(handler, event),
    );
  }

  /// The stroke's initial pressure samples, or null when it records none.
  List<double>? pressuresFor(_CanvasGestureHandlerState _, PointerDownEvent _) => null;
}

/// Pencil and eraser: a polyline extended point by point.
class _PolylineGesture extends _StrokeGesture {
  const _PolylineGesture();

  @override
  void move(
    _CanvasGestureHandlerState handler,
    AppProvider app,
    PointerEvent event,
    Offset canvasPosition,
  ) {
    handler._updateDrawingToolPreview(app, event.localPosition);
    if (app.crossLayerEraser.isActive) {
      app.extendCrossLayerEraserStroke(canvasPosition);
      return;
    }
    app.appendLineFromLastUserAction(canvasPosition);
  }
}

/// Brush: a freehand stroke that records stylus pressure per point.
class _PressureStrokeGesture extends _StrokeGesture {
  const _PressureStrokeGesture();

  @override
  List<double>? pressuresFor(_CanvasGestureHandlerState handler, PointerDownEvent event) {
    final bool trackpadPressureEnabled = handler._trackpadPressureEnabled;
    final double? pressure = brushPointerPressure(event, trackpadPressureEnabled: trackpadPressureEnabled);
    if (pressure != null) {
      return <double>[pressure, pressure];
    }
    // A trackpad stroke's pressure may only arrive after the click: it starts
    // with no samples and back-fills them from the first one (see
    // [LayerProvider.lastActionAppendPosition]).
    return usesTrackpadPressure(event, enabled: trackpadPressureEnabled) ? <double>[] : null;
  }

  @override
  void move(
    _CanvasGestureHandlerState handler,
    AppProvider app,
    PointerEvent event,
    Offset canvasPosition,
  ) {
    handler._updateDrawingToolPreview(app, event.localPosition);
    app.layers.selectedLayer.lastActionAppendPosition(
      position: canvasPosition,
      pressure: brushPointerPressure(event, trackpadPressureEnabled: handler._trackpadPressureEnabled),
    );
    app.layers.repaintCanvas();
  }

  /// A pen lifting off a fading press ends the stroke in a 1 px tip.
  @override
  void lift(AppProvider app) {
    app.layers.selectedLayer.taperLastPressureStrokeTip();
  }
}

/// Line, rectangle and circle: a two-point shape dragged from its start.
class _ShapeGesture extends _StrokeGesture {
  const _ShapeGesture();

  @override
  void move(
    _CanvasGestureHandlerState handler,
    AppProvider app,
    PointerEvent event,
    Offset canvasPosition,
  ) {
    handler._updateDrawingToolPreview(app, event.localPosition);
    app.updateAction(end: canvasPosition);
    app.layers.repaintCanvas();
  }
}

/// Smudge, blur and armed effect brushes: the gesture is swept as a marquee
/// and rendered once on release.
class _PixelBrushGesture extends _LayerEditGesture {
  const _PixelBrushGesture();

  /// The smudge/blur commit folds its patch into the display projection, and
  /// an effect stroke's append already clears the caches; a pen-up clear would
  /// discard that projection and force a full-history rebuild per stroke.
  @override
  bool get maintainsLayerCaches => true;

  @override
  void begin(
    _CanvasGestureHandlerState handler,
    AppProvider app,
    PointerDownEvent event,
    Offset canvasPosition,
  ) {
    app.layers.selectedLayer.isUserDrawing = true;
    if (app.effectBrushModel.isArmed) {
      app.startEffectBrushStroke(canvasPosition);
      return;
    }
    app.startPixelBrushStroke(
      canvasPosition,
      app.selectedTool == ToolKind.smudge ? PixelBrushMode.smudge : PixelBrushMode.blur,
    );
  }

  /// No live rasterization: extending the gesture redraws the swept-band
  /// marquee, so the drag stays responsive at any canvas size.
  @override
  void move(
    _CanvasGestureHandlerState handler,
    AppProvider app,
    PointerEvent event,
    Offset canvasPosition,
  ) {
    if (app.pixelBrushSession.isStrokeActive) {
      app.extendPixelBrushStroke(canvasPosition);
    }
  }

  @override
  Future<void> end(
    _CanvasGestureHandlerState handler,
    AppProvider app,
    PointerEvent event,
  ) async {
    if (app.pixelBrushSession.isStrokeActive) {
      app.extendPixelBrushStroke(app.toCanvas(event.localPosition));
      // The marquee stays visible across the (async) one-shot render,
      // switching to a processing shimmer, and clears once the committed
      // stroke is on the layer.
      app.setPixelBrushCommitting(committing: true);
      await app.commitPixelBrushGesture();
      app.clearPixelBrushGesture();
    }
    handler._clearSelectionTapTracking();
  }
}

/// The paint bucket: tap to fill, drag horizontally to adjust tolerance.
class _FillGesture extends _LayerEditGesture {
  const _FillGesture();

  @override
  FutureOr<void> begin(
    _CanvasGestureHandlerState handler,
    AppProvider app,
    PointerDownEvent event,
    Offset canvasPosition,
  ) {
    return handler._handleFillPointerStart(app, event.localPosition, canvasPosition, pointer: event.pointer);
  }

  @override
  void move(
    _CanvasGestureHandlerState handler,
    AppProvider app,
    PointerEvent event,
    Offset canvasPosition,
  ) {
    // Gradient fill has no tolerance drag anchor.
    if (handler._toleranceDragAnchorScreen != null) {
      handler._updateFillToleranceFromDrag(app, event.localPosition);
    }
  }

  /// Solid fill commits on release; gradient fill leaves its handle session
  /// open (finalized later via Apply/Cancel).
  @override
  void end(
    _CanvasGestureHandlerState handler,
    AppProvider app,
    PointerEvent event,
  ) {
    if (handler._toleranceDragAnchorScreen != null && app.fillModel.mode == FillMode.solid) {
      handler._commitSolidFillDrag(app);
    }
    handler._clearSelectionTapTracking();
  }
}

/// Text: a tap selects the text object under it or opens the add-text dialog.
class _TextGesture extends _LayerEditGesture {
  const _TextGesture();

  @override
  void begin(
    _CanvasGestureHandlerState handler,
    AppProvider app,
    PointerDownEvent event,
    Offset canvasPosition,
  ) {
    handler._handleTextPointerStart(app, canvasPosition);
  }
}

/// Selection: marquee, lasso, line, brush or Edge Detection wand.
class _SelectionGesture extends _ToolGesture {
  const _SelectionGesture();

  @override
  void start(
    _CanvasGestureHandlerState handler,
    AppProvider app,
    PointerDownEvent event,
    Offset canvasPosition,
  ) {
    handler._handleSelectionPointerStart(app, event, canvasPosition);
  }

  @override
  void move(
    _CanvasGestureHandlerState handler,
    AppProvider app,
    PointerEvent event,
    Offset canvasPosition,
  ) {
    if (app.selectorModel.mode == SelectorMode.wand) {
      handler._updateWandToleranceFromDrag(app, event.localPosition);
      return;
    }
    // The size ring rides along a selection-brush stroke like any brush.
    if (app.isSelectionBrushActive) {
      handler._updateDrawingToolPreview(app, event.localPosition);
    }
    app.selectorCreationAdditionalPoint(canvasPosition);
  }

  @override
  void end(
    _CanvasGestureHandlerState handler,
    AppProvider app,
    PointerEvent event,
  ) {
    app.selectorCreationEnd();
    handler._restoreSelectionMath(app);
    // A straight-line selection keeps its taps tracked across segments so a
    // double tap can close it.
    if (app.selectorModel.mode != SelectorMode.line || !app.selectorModel.isDrawing) {
      handler._clearSelectionTapTracking();
    }
  }
}

/// The Surface pen's eraser end: always erases, whatever tool is armed, and
/// never touches the persisted tool (which would disturb an armed effect,
/// eyedropper or wand selection).
class _PenEraserGesture extends _ToolGesture {
  const _PenEraserGesture();

  @override
  void start(
    _CanvasGestureHandlerState handler,
    AppProvider app,
    PointerDownEvent event,
    Offset canvasPosition,
  ) {
    handler._updateDrawingToolPreview(app, event.localPosition);
    if (!handler._canStartDrawing(app, isEraser: true, isForced: true)) {
      handler._activeGesture = null;
      return;
    }
    if (handler._isCrossLayerEraserStroke(app, isEraser: true, isForced: true)) {
      app.startCrossLayerEraserStroke(canvasPosition);
      return;
    }
    handler._beginStroke(app, ActionType.eraser, canvasPosition);
  }

  @override
  void move(
    _CanvasGestureHandlerState handler,
    AppProvider app,
    PointerEvent event,
    Offset canvasPosition,
  ) {
    handler._updateDrawingToolPreview(app, event.localPosition);
    if (app.crossLayerEraser.isActive) {
      app.extendCrossLayerEraserStroke(canvasPosition);
      return;
    }
    handler._appendPenEraserStrokeLine(app, canvasPosition);
  }
}
