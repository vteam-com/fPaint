part of 'canvas_gesture_handler.dart';

/// Bookkeeping for the two-finger navigation gesture: which contacts control
/// it, its pinch/pan/twist baseline, and releasing contacts.
extension _CanvasGestureHandlerMultiTouch on _CanvasGestureHandlerState {
  /// Returns the positions of the first two active touch pointers — the pair
  /// controlling touch navigation — or `null` when fewer than two are known.
  (Offset, Offset)? _controllingTouchPair() {
    if (_activePointers.length < AppMath.pair) {
      return null;
    }
    final Offset? firstPosition = _pointerPositions[_activePointers[AppMath.zero]];
    final Offset? secondPosition = _pointerPositions[_activePointers[AppMath.one]];
    if (firstPosition == null || secondPosition == null) {
      return null;
    }
    return (firstPosition, secondPosition);
  }

  /// Returns the distance between the two contacts controlling touch navigation.
  double _getDistanceBetweenTouchPoints() {
    final (Offset, Offset)? pair = _controllingTouchPair();
    if (pair == null) {
      return 0.0;
    }
    final (Offset firstPosition, Offset secondPosition) = pair;
    return (secondPosition - firstPosition).distance;
  }

  /// Returns the midpoint between the first two active touch pointers.
  Offset? _getMultiTouchFocalPoint() {
    final (Offset, Offset)? pair = _controllingTouchPair();
    if (pair == null) {
      return null;
    }
    final (Offset firstPosition, Offset secondPosition) = pair;
    return Offset(
      (firstPosition.dx + secondPosition.dx) / AppMath.pair,
      (firstPosition.dy + secondPosition.dy) / AppMath.pair,
    );
  }

  /// Captures the current pinch distance, focal point and contact angle as the
  /// baseline the next multi-touch update is measured against.
  void _seedMultiTouchBaseline() {
    _lastScaleDistance = _getDistanceBetweenTouchPoints();
    _lastMultiTouchFocalPoint = _getMultiTouchFocalPoint();
    _lastTouchContactAngle = _getTouchContactAngle();
  }

  /// Forgets touch [pointer] after it lifted or was cancelled.
  ///
  /// Dropping below two contacts ends the navigation gesture (closing the
  /// interactive viewport change when one was running); otherwise the
  /// remaining pair is re-baselined. Returns whether a multi-touch gesture
  /// was in progress before the release.
  bool _releaseTouchPointer(AppProvider appProvider, int pointer) {
    final bool wasMultiTouch = _activePointers.length >= AppMath.pair;
    _pointerPositions.remove(pointer);
    _activePointers.remove(pointer);
    if (_activePointers.length < AppMath.pair) {
      _lastScaleDistance = 0.0;
      _lastMultiTouchFocalPoint = null;
      _lastTouchContactAngle = null;
      _resetGestureTwist();
      _multiTouchPointersMoved.clear();
      if (wasMultiTouch) {
        appProvider.layers.endInteractiveViewportChange();
      }
    } else if (wasMultiTouch) {
      _seedMultiTouchBaseline();
      _multiTouchPointersMoved.clear();
    }
    return wasMultiTouch;
  }

  /// Ends a right-button pan / Shift+right-button rotate drag.
  void _endSecondaryPan() {
    _panningPointerId = -1;
    _isMouseRotateDrag = false;
    _resetGestureTwist();
  }
}
