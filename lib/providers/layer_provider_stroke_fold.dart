part of 'layer_provider.dart';

/// Folds freehand strokes into the display-resolution stroke baseline.
///
/// Mid-stroke: once the un-baked tail passes
/// [AppInteraction.strokePreviewFoldThreshold], it is rendered (async, at
/// display resolution — never a full-res or chained `toImageSync` bake) into a
/// new baseline and the fold cursor advances, so each frame replays at most
/// O(threshold) of the stroke instead of all of it.
///
/// At pen-up: dropping the baseline would leave the layer with no projection,
/// so the next frames would replay the whole action history (and rebuild the
/// projection from it) for every stroke. Instead the baseline and the rest of
/// the stroke are rendered once into the new projection — the freehand analog
/// of `updateDisplayCacheWithPatch`.
extension LayerStrokeFold on LayerProvider {
  /// Ends a freehand stroke on pen-up, keeping the display projection.
  ///
  /// Falls back to [clearStrokePreview] when there is nothing to fold (no
  /// display-res baseline, no new action, or text content, which the
  /// projection never holds). Idempotent while a fold is in flight.
  void finishStrokePreview() {
    if (_strokeFold != null) {
      return;
    }
    final ui.Image? origin = _strokeBaselineDisplayOrigin;
    if (origin == null || actionStack.length <= _strokeBaselineActionCount || _hasTextContent) {
      clearStrokePreview();
      return;
    }
    _strokeFold = (actionCount: actionStack.length, lastAction: actionStack.last);
    unawaited(_foldFinishedStroke(origin));
  }

  /// Whether a fold is in flight and the action stack is still exactly what it
  /// draws.
  bool get _isStrokeFoldCurrent {
    final ({int actionCount, UserActionDrawing lastAction})? fold = _strokeFold;
    return fold != null && actionStack.length == fold.actionCount && identical(actionStack.last, fold.lastAction);
  }

  /// Renders the stroke-start [origin] plus the whole finished stroke into a
  /// new projection and installs it, unless the layer changed meanwhile.
  Future<void> _foldFinishedStroke(ui.Image origin) async {
    final int revision = _displayCacheRevision;
    final int width = origin.width;
    final int height = origin.height;
    final ui.Image folded = await renderCanvasImage(
      width: width,
      height: height,
      draw: (ui.Canvas canvas) {
        canvas.drawImage(origin, Offset.zero, Paint());
        canvas.scale(width / size.width, height / size.height);
        _renderStrokeRange(canvas, fromIndex: _strokeBaselineActionCount, fromPoint: AppMath.zero);
      },
    );
    final bool stillOwnsBaseline = identical(_strokeBaselineDisplayOrigin, origin);
    if (!stillOwnsBaseline || revision != _displayCacheRevision || !_isStrokeFoldCurrent) {
      folded.dispose();
      if (stillOwnsBaseline) {
        clearStrokePreview();
      }
      return;
    }
    _displayCache?.dispose();
    _displayCache = folded;
    _displayCacheScale = width / size.width;
    // A projection build that started before the fold must not overwrite it.
    _displayCacheRevision++;
    clearStrokePreview();
    refreshThumbnailFromDisplayCache();
    onThumbnailChanged();
  }

  /// Draws the in-progress actions/segments not yet folded into the baseline,
  /// starting at ([_strokeFoldedActionIndex], [_strokeFoldedPointCount]).
  void _renderInProgressTail(ui.Canvas canvas) {
    _renderStrokeRange(
      canvas,
      fromIndex: _strokeFoldedActionIndex,
      fromPoint: _strokeFoldedPointCount,
    );
  }

  /// Draws the stroke from ([fromIndex], [fromPoint]) to the end of the stack.
  /// [lastActionPointLimit] caps how many points of the last action are drawn
  /// (a partial fold); null draws them all.
  void _renderStrokeRange(
    ui.Canvas canvas, {
    required int fromIndex,
    required int fromPoint,
    int? lastActionPointLimit,
  }) {
    final int count = actionStack.length;
    for (int index = fromIndex; index < count; index++) {
      final UserActionDrawing action = actionStack[index];
      final int length = action.positions.length;
      final int start = index == fromIndex ? fromPoint : AppMath.zero;
      final int end = index == count - AppMath.one && lastActionPointLimit != null
          ? min(lastActionPointLimit, length)
          : length;
      if (start <= AppMath.zero && end == length) {
        _renderAction(canvas, action);
      } else if (end > start && action is StrokeAction) {
        _renderPartialStroke(canvas, action, start, end);
      }
    }
  }

  /// Draws points [start]..[end) of a partially foldable [action], restarting
  /// one point back so the new segments join the folded ones.
  void _renderPartialStroke(ui.Canvas canvas, StrokeAction action, int start, int end) {
    final int from = max(AppMath.zero, start - AppMath.one);
    final List<Offset> points = action.positions.sublist(from, end);
    if (action.action != ActionType.brush) {
      _renderStrokeAction(canvas, action, points);
      return;
    }
    final List<double>? pressures = action.pressures;
    final List<double>? pressureRange = pressures != null && pressures.length == action.positions.length
        ? pressures.sublist(from, end)
        : null;
    applyAction(
      canvas,
      action.clipPath,
      (Canvas target) => renderPath(target, points, action.brush, pressures: pressureRange),
    );
  }

  /// Whether [action] can be split mid-way without a visible seam.
  ///
  /// Pencil/eraser segments partition the polyline. A solid, opaque brush is
  /// one filled outline whose pieces overlap only inside the shared round cap,
  /// which is invisible when opaque; a translucent or soft (blurred) brush
  /// would double up there, so it only ever folds whole.
  bool _isPartiallyFoldable(UserActionDrawing action) {
    if (action is! StrokeAction) {
      return false;
    }
    switch (action.action) {
      case ActionType.pencil:
      case ActionType.eraser:
        return true;
      case ActionType.brush:
        final List<double>? pressures = action.pressures;
        return action.brush.style == BrushStyle.solid &&
            action.brush.color.a >= AppVisual.full &&
            (pressures == null || pressures.length == action.positions.length);
      default:
        return false;
    }
  }

  /// Starts a mid-stroke fold once the un-baked tail drawn on top of
  /// [baseline] has outgrown [AppInteraction.strokePreviewFoldThreshold].
  void _foldLiveStrokeIfTailLarge(ui.Image baseline) {
    if (_liveStrokeFoldInFlight) {
      return;
    }
    final int count = actionStack.length;
    final int fromIndex = _strokeFoldedActionIndex;
    final int fromPoint = _strokeFoldedPointCount;
    if (fromIndex >= count) {
      return;
    }
    final UserActionDrawing last = actionStack[count - AppMath.one];
    final bool cursorOnLast = fromIndex == count - AppMath.one;
    final int pendingPoints = last.positions.length - (cursorOnLast ? fromPoint : AppMath.zero);
    if (count - fromIndex <= AppInteraction.strokePreviewFoldThreshold &&
        pendingPoints <= AppInteraction.strokePreviewFoldThreshold) {
      return;
    }
    // The last point stays live: the pen-lift taper may still rewrite its
    // pressure.
    final int foldablePoints = _isPartiallyFoldable(last)
        ? max(AppMath.zero, last.positions.length - AppMath.one)
        : AppMath.zero;
    final int targetPoint = cursorOnLast ? max(fromPoint, foldablePoints) : foldablePoints;
    if (cursorOnLast && targetPoint <= fromPoint) {
      return;
    }
    unawaited(
      _foldLiveStroke(
        baseline: baseline,
        fromIndex: fromIndex,
        fromPoint: fromPoint,
        last: last,
        lastIndex: count - AppMath.one,
        targetPoint: targetPoint,
      ),
    );
  }

  /// Renders [baseline] plus the stroke up to ([lastIndex], [targetPoint])
  /// into a new baseline and advances the fold cursor, unless the stroke or
  /// baseline changed meanwhile.
  Future<void> _foldLiveStroke({
    required ui.Image baseline,
    required int fromIndex,
    required int fromPoint,
    required UserActionDrawing last,
    required int lastIndex,
    required int targetPoint,
  }) async {
    _liveStrokeFoldInFlight = true;
    final ui.Image folded;
    try {
      folded = await renderCanvasImage(
        width: baseline.width,
        height: baseline.height,
        draw: (ui.Canvas canvas) {
          canvas.drawImage(baseline, Offset.zero, Paint());
          canvas.scale(baseline.width / size.width, baseline.height / size.height);
          _renderStrokeRange(
            canvas,
            fromIndex: fromIndex,
            fromPoint: fromPoint,
            lastActionPointLimit: targetPoint,
          );
        },
      );
    } finally {
      _liveStrokeFoldInFlight = false;
    }
    final bool stillCurrent =
        isUserDrawing &&
        identical(_strokeBaselineDisplay, baseline) &&
        _strokeFoldedActionIndex == fromIndex &&
        _strokeFoldedPointCount == fromPoint &&
        actionStack.length > lastIndex &&
        identical(actionStack[lastIndex], last);
    if (!stillCurrent) {
      folded.dispose();
      return;
    }
    _strokeBaselineDisplay = folded;
    if (!identical(baseline, _strokeBaselineDisplayOrigin)) {
      baseline.dispose();
    }
    _strokeFoldedActionIndex = lastIndex;
    _strokeFoldedPointCount = targetPoint;
  }
}
