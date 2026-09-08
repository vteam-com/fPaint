part of 'canvas_gesture_handler.dart';

/// Viewport rotation gestures: two-finger twist (touch), trackpad twist, and
/// the keyboard/mouse fallbacks.
///
/// Rotation is a pure view change — it shares the pinch-zoom gesture rather
/// than living behind a modal tool, so pan, zoom and rotate are one continuous
/// motion about the same focal point. Two rules make it feel deliberate rather
/// than accidental:
///
///  * a dead zone, so an ordinary pinch-zoom never leaves the canvas crooked;
///  * a snap band at each 45° multiple, matching the transform overlay's snap.
extension _CanvasGestureHandlerRotation on _CanvasGestureHandlerState {
  /// Feeds [twistDelta] radians of raw gesture twist into the viewport.
  ///
  /// Returns whether the viewport rotation actually changed, so callers can
  /// skip a repaint when the twist was absorbed by the dead zone.
  bool _applyGestureTwist(
    AppProvider appProvider,
    ShellProvider shellProvider,
    double twistDelta,
    Offset anchorPoint,
  ) {
    if (twistDelta == 0) {
      return false;
    }

    _pendingGestureTwist += twistDelta;

    // Hold the canvas upright until the twist clears the dead zone. Fingers
    // never pinch along a perfectly fixed axis, so without this every zoom
    // would leave the canvas a degree or two off-axis.
    // On the update that clears the dead zone, apply the whole accumulated
    // twist: using only this update's delta would drop the ~7° already turned
    // and leave the canvas lagging behind the fingers.
    double effectiveDelta = twistDelta;
    if (!_hasGestureTwistEngaged) {
      final double pendingDegrees = radiansToDegrees(_pendingGestureTwist).abs();
      if (pendingDegrees < AppInteraction.viewportRotationDeadzoneDegrees) {
        return false;
      }
      _hasGestureTwistEngaged = true;
      effectiveDelta = _pendingGestureTwist;
    }

    final double target = snapAngleToInterval(
      appProvider.canvasRotation + effectiveDelta,
      snapIntervalDegrees: AppMath.rotationSnapInterval,
      snapToleranceDegrees: AppInteraction.viewportRotationSnapToleranceDegrees,
    );
    final double delta = target - appProvider.canvasRotation;
    if (delta == 0) {
      return false;
    }

    shellProvider.canvasPlacement = CanvasAutoPlacement.manual;
    appProvider.applyRotationToCanvas(
      rotationDelta: delta,
      anchorPoint: anchorPoint,
      notifyListener: false,
    );
    _showRotationHud(appProvider);
    return true;
  }

  /// Rotates the view from a Shift + right-drag, about the viewport centre.
  ///
  /// A mouse has no twist, so horizontal drag distance stands in for angle.
  void _handleMouseRotateDrag(
    AppProvider appProvider,
    ShellProvider shellProvider,
    PointerMoveEvent event,
  ) {
    final double twist = degreesToRadians(
      event.delta.dx / AppInteraction.viewportRotationDragPixelsPerDegree,
    );
    if (_applyGestureTwist(appProvider, shellProvider, twist, appProvider.canvasCenter)) {
      _scheduleViewportRepaint(appProvider);
    }
  }

  /// Clears the twist accumulator so the next gesture re-earns the dead zone.
  void _resetGestureTwist() {
    _pendingGestureTwist = 0;
    _hasGestureTwistEngaged = false;
  }

  /// Shows the live angle readout and schedules its fade-out.
  void _showRotationHud(AppProvider appProvider) {
    appProvider.showViewportRotationFeedback();
    _rotationHudTimer?.cancel();
    _rotationHudTimer = Timer(AppInteraction.viewportRotationHudLinger, () {
      if (mounted) {
        appProvider.hideViewportRotationFeedback();
      }
    });
  }

  /// The signed angle between the two controlling touch contacts.
  double? _getTouchContactAngle() {
    if (_activePointers.length < AppMath.pair) {
      return null;
    }
    final Offset? firstPosition = _pointerPositions[_activePointers[AppMath.zero]];
    final Offset? secondPosition = _pointerPositions[_activePointers[AppMath.one]];
    if (firstPosition == null || secondPosition == null) {
      return null;
    }
    final Offset span = secondPosition - firstPosition;
    return atan2(span.dy, span.dx);
  }
}
