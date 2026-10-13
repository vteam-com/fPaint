part of 'canvas_gesture_handler.dart';

/// Opening and driving the on-canvas quick menu from canvas pointers: a
/// right-click, a pen barrel-button press, or a touch-and-hold.
///
/// A pen or finger that opens the menu stays "tracking": sliding it out past
/// the colors highlights the ring slot it points at, and lifting it there picks
/// that slot (a marking-menu flick). Lifting it without aiming leaves the menu
/// open for taps.
extension _CanvasGestureHandlerStateQuickMenuMethods on _CanvasGestureHandlerState {
  /// Arms the touch-and-hold for a lone finger, or cancels it once a second
  /// finger joins (a pinch / twist, never a hold).
  void _updateQuickMenuHoldForTouchDown(AppProvider appProvider, PointerDownEvent event) {
    _cancelQuickMenuHold();
    if (_activePointers.length != AppMath.one || _activePointerId != -1) {
      return;
    }

    _quickMenuHoldOrigin = event.localPosition;
    _quickMenuHoldTimer = Timer(AppInteraction.quickMenuHoldDelay, () {
      _quickMenuHoldTimer = null;
      _quickMenuHoldOrigin = null;
      // Still the only finger and it never became a stroke.
      if (!mounted || _activePointerId != -1 || !_activePointers.contains(event.pointer)) {
        return;
      }
      if (_activePointers.length != AppMath.one) {
        return;
      }
      _pendingTouchDownEvent = null;
      _openQuickMenu(
        appProvider,
        _pointerPositions[event.pointer] ?? event.localPosition,
        trackingPointer: event.pointer,
      );
    });
  }

  /// Cancels a pending touch-and-hold.
  void _cancelQuickMenuHold() {
    _quickMenuHoldTimer?.cancel();
    _quickMenuHoldTimer = null;
    _quickMenuHoldOrigin = null;
  }

  /// Cancels a pending touch-and-hold once the finger drifts past the draw
  /// slop, where it becomes a stroke instead.
  void _cancelQuickMenuHoldIfMoved(PointerMoveEvent event) {
    final Offset? origin = _quickMenuHoldOrigin;
    if (origin != null && (event.localPosition - origin).distance >= AppInteraction.singleTouchDrawSlop) {
      _cancelQuickMenuHold();
    }
  }

  /// Opens the menu, still tracking the pen, when it lands with its barrel
  /// button held. Returns whether the press was claimed.
  bool _startQuickMenuFromStylusButton(AppProvider appProvider, PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.stylus || (event.buttons & kSecondaryStylusButton) == 0) {
      return false;
    }
    _openQuickMenu(appProvider, event.localPosition, trackingPointer: event.pointer);
    return true;
  }

  /// Forgets the right-button press once it drifts far enough to be a pan.
  void _forgetSecondaryClickIfMoved(Offset position) {
    final Offset? pressPosition = _secondaryPressPosition;
    if (pressPosition != null && (position - pressPosition).distance > AppInteraction.quickMenuClickSlop) {
      _secondaryPressPosition = null;
    }
  }

  /// Opens the menu (for clicks) when a right-button press is released
  /// without having dragged; a right-drag stays a pan / rotate.
  void _openQuickMenuOnSecondaryClick(AppProvider appProvider, Offset position) {
    final bool wasClick = _secondaryPressPosition != null && !_isMouseRotateDrag;
    _secondaryPressPosition = null;
    if (wasClick) {
      _openQuickMenu(appProvider, position);
    }
  }

  /// Opens the menu at [position], kept fully on-screen. A [trackingPointer]
  /// is the still-pressed pointer whose release can pick a slot.
  void _openQuickMenu(AppProvider appProvider, Offset position, {int trackingPointer = -1}) {
    if (appProvider.hasActiveTransformOverlay) {
      return;
    }
    final Size? viewport = context.size;
    _quickMenuPointer = trackingPointer;
    appProvider.openQuickMenu(viewport == null ? position : clampQuickMenuAnchor(position, viewport));
  }

  /// Highlights the ring slot the tracking pointer aims at. Returns whether
  /// [event] belonged to that pointer (and so must not reach any tool).
  bool _trackQuickMenuPointer(AppProvider appProvider, PointerEvent event) {
    if (event.pointer != _quickMenuPointer) {
      return false;
    }
    final QuickMenuModel menu = appProvider.quickMenuModel;
    final Offset? anchor = menu.anchor;
    if (anchor != null) {
      menu.highlightedSlot = quickMenuSlotAt(
        center: anchor,
        point: event.localPosition,
        count: appProvider.quickMenuSlots.length,
      );
    }
    return true;
  }

  /// Ends the tracking pointer: with [pickHighlighted], lifting it over a
  /// highlighted slot picks that slot; otherwise the menu stays open for taps.
  /// Returns whether [event] belonged to that pointer.
  bool _releaseQuickMenuPointer(AppProvider appProvider, PointerEvent event, {required bool pickHighlighted}) {
    if (event.kind == PointerDeviceKind.touch) {
      _cancelQuickMenuHold();
    }
    if (event.pointer != _quickMenuPointer) {
      return false;
    }

    _quickMenuPointer = -1;
    _pointerPositions.remove(event.pointer);
    _activePointers.remove(event.pointer);

    final QuickMenuModel menu = appProvider.quickMenuModel;
    final int? slot = menu.highlightedSlot;
    if (pickHighlighted && menu.isOpen && slot != null) {
      final List<QuickMenuSlot> slots = appProvider.quickMenuSlots;
      if (slot < slots.length) {
        appProvider.pickQuickMenuSlot(slots[slot]);
        return true;
      }
    }
    menu.endTracking();
    return true;
  }
}
