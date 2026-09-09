import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/smudge_helper.dart';
import 'package:fpaint/helpers/transform_helper.dart';
import 'package:fpaint/helpers/viewport_transform_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/inherited_scope.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/recovery/draft_recovery_controller.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/text_editor_dialog.dart';

part 'canvas_gesture_handler_eyedropper.dart';
part 'canvas_gesture_handler_rotation.dart';
part 'canvas_gesture_handler_state_methods.dart';

/// Handles pointer, pan, and zoom gestures over the canvas widget tree.
class CanvasGestureHandler extends StatefulWidget {
  const CanvasGestureHandler({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<CanvasGestureHandler> createState() => _CanvasGestureHandlerState();
}

class _CanvasGestureHandlerState extends State<CanvasGestureHandler> {
  int _activePointerId = -1;
  final List<int> _activePointers = <int>[];

  /// Screen-space anchor of a hold-modifiers-and-drag brush resize. Non-null
  /// only while that gesture is active; horizontal distance from here drives the
  /// live size.
  Offset? _brushSizeDragAnchorScreen;

  /// Brush size captured when the resize drag began, so the drag is absolute
  /// (distance from the anchor) rather than accumulating rounding per step.
  double _brushSizeDragStartSize = AppDefaults.brushSize;

  /// Whether the current gesture's twist has cleared the dead zone.
  bool _hasGestureTwistEngaged = false;

  /// Whether the active right-drag rotates the view rather than panning it.
  bool _isMouseRotateDrag = false;
  Offset? _lastMultiTouchFocalPoint;
  double _lastScaleDistance = 0.0;
  Offset? _lastSelectionTapCanvasPosition;
  Duration? _lastSelectionTapTimestamp;

  /// Angle between the two controlling touch contacts on the previous update.
  double? _lastTouchContactAngle;

  /// Absolute trackpad gesture rotation seen on the previous update.
  double _lastTrackpadRotation = 0;
  final Set<int> _multiTouchPointersMoved = <int>{};
  int _panningPointerId = -1;

  /// Raw gesture twist accumulated so far, including the part still absorbed
  /// by the rotation dead zone.
  double _pendingGestureTwist = 0;
  PointerDownEvent? _pendingTouchDownEvent;
  final Map<int, Offset> _pointerPositions = <int, ui.Offset>{};

  /// The selector math mode active before a modifier-key override was applied.
  /// Non-null only during a modifier-driven selection gesture.
  SelectorMath? _previousSelectorMath;

  /// Fades out the live angle readout once twisting stops.
  Timer? _rotationHudTimer;

  /// Canvas-space sample anchor re-sampled / re-previewed on every drag step.
  Offset? _toleranceDragAnchorCanvas;

  /// Screen-space anchor of the sample tap; horizontal drag distance from here
  /// drives the live tolerance. Non-null only during a tolerance-drag gesture.
  Offset? _toleranceDragAnchorScreen;

  /// Last tolerance applied during the drag, to skip redundant re-runs.
  int? _toleranceDragLastApplied;

  /// Whether the active tolerance-drag gesture samples all visible layers.
  bool _toleranceDragSampleAllLayers = false;

  /// Tolerance captured when the tolerance-drag gesture began.
  int _toleranceDragStartTolerance = AppDefaults.tolerance;
  bool _viewportRepaintScheduled = false;
  @override
  void dispose() {
    _rotationHudTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context, listen: false);
    final AppPreferences appPreferences = AppPreferences.of(context);
    final ShellProvider shellProvider = ShellProvider.of(context);

    return ListenableBuilder(
      // Rebuild only the cursor wrapper when the tool / selector mode changes,
      // keeping the (expensive) Listener gesture subtree built once.
      listenable: appProvider.toolOptionsRepaintListenable,
      builder: (BuildContext _, Widget? listenerChild) {
        return MouseRegion(
          cursor: _canvasCursor(appProvider),
          onExit: (PointerExitEvent _) {
            if (_activePointerId == -1 && appProvider.brushSizePreviewPosition != null) {
              appProvider.hideDrawingToolPreview();
            }
          },
          child: listenerChild,
        );
      },
      child: Listener(
        onPointerSignal: (PointerSignalEvent event) {
          _registerInputModality(shellProvider, event.kind);
          if (event is PointerScrollEvent) {
            _handleUserScalingTheCanvas(
              shellProvider,
              appProvider,
              event.localPosition,
              exp(-event.scrollDelta.dy / AppInteraction.mouseWheelZoomScrollPixels),
            );
          } else {
            if (event is PointerScaleEvent) {
              _handleUserScalingTheCanvas(
                shellProvider,
                appProvider,
                event.localPosition,
                event.scale,
              );
            }
          }
        },
        onPointerHover: (PointerHoverEvent event) {
          _registerInputModality(shellProvider, event.kind);
          if (_activePointerId != -1 || !_supportsHoverPreview(event.kind)) {
            return;
          }

          appProvider.lastPointerPosition = event.localPosition;

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

          if (_shouldShowDrawingToolPreview(appProvider) && !appProvider.hasActiveTransformOverlay) {
            _updateDrawingToolPreview(appProvider, event.localPosition);
            return;
          }

          if (appProvider.brushSizePreviewPosition != null) {
            appProvider.hideDrawingToolPreview();
          }
        },
        onPointerPanZoomStart: (PointerPanZoomStartEvent _) {
          shellProvider.interactionInputModality = InteractionInputModality.mouse;
          _lastTrackpadRotation = 0;
          _resetGestureTwist();
        },
        onPointerPanZoomUpdate: (PointerPanZoomUpdateEvent event) {
          _registerInputModality(shellProvider, event.kind);
          // Trackpad rotation arrives as an absolute angle for the gesture, so
          // it is differenced into a per-update delta.
          final double rotationDelta = event.rotation - _lastTrackpadRotation;
          _lastTrackpadRotation = event.rotation;
          final bool didRotate = _applyGestureTwist(
            appProvider,
            shellProvider,
            rotationDelta,
            event.localPosition,
          );

          if (event.scale == 1) {
            // Panning
            _handleUserPanningTheCanvas(
              shellProvider,
              appProvider,
              event.panDelta,
            );
          } else {
            // Scaling
            _handleUserScalingTheCanvas(
              shellProvider,
              appProvider,
              event.localPosition,
              event.scale,
            );
          }

          if (didRotate) {
            _scheduleViewportRepaint(appProvider);
          }
        },
        onPointerPanZoomEnd: (PointerPanZoomEndEvent _) {
          _lastTrackpadRotation = 0;
          _resetGestureTwist();
        },
        onPointerDown: (PointerDownEvent event) {
          _registerInputModality(shellProvider, event.kind);
          if (event.kind == PointerDeviceKind.touch) {
            // A centered brush-size preview may still be visible from a recent
            // size adjustment. Clear it as soon as touch navigation begins so
            // it cannot flash between the first and second pinch contacts.
            appProvider.hideDrawingToolPreview();
            _pointerPositions[event.pointer] = event.localPosition;
            if (!_activePointers.contains(event.pointer)) {
              _activePointers.add(event.pointer);
            }

            if (_activePointers.length >= AppMath.pair) {
              if (_activePointers.length == AppMath.pair) {
                if (_activePointerId != -1) {
                  _cancelActiveTouchInteraction(appProvider);
                }
                _lastScaleDistance = _getDistanceBetweenTouchPoints();
                _lastMultiTouchFocalPoint = _getMultiTouchFocalPoint();
                _lastTouchContactAngle = _getTouchContactAngle();
                _resetGestureTwist();
                _multiTouchPointersMoved.clear();
                appProvider.layers.beginInteractiveViewportChange();
              }
              _pendingTouchDownEvent = null;
              appProvider.hideDrawingToolPreview();
            } else {
              if (event.buttons == 1 && !appPreferences.penOnlyDrawing) {
                _pendingTouchDownEvent = event;
              }
            }
          } else {
            if (event.kind == PointerDeviceKind.mouse && event.buttons == kSecondaryMouseButton) {
              _panningPointerId = event.pointer;
              // A mouse cannot twist, so Shift turns the existing right-drag
              // navigation gesture into a rotate.
              _isMouseRotateDrag = HardwareKeyboard.instance.isShiftPressed;
              _resetGestureTwist();
              return;
            }
            _handlePointerStart(appProvider, event);
          }
        },
        onPointerMove: (PointerMoveEvent event) {
          _registerInputModality(shellProvider, event.kind);
          if (event.kind == PointerDeviceKind.touch) {
            _pointerPositions[event.pointer] = event.localPosition;

            if (_shouldProcessMultiTouchUpdate(event.pointer)) {
              _handleMultiTouchUpdate(
                appProvider,
                shellProvider,
              );
              _multiTouchPointersMoved.clear();
            } else {
              if (event.buttons == 1 && !appPreferences.penOnlyDrawing) {
                final PointerDownEvent? pendingTouchDownEvent = _pendingTouchDownEvent;
                if (pendingTouchDownEvent != null && pendingTouchDownEvent.pointer == event.pointer) {
                  if ((event.localPosition - pendingTouchDownEvent.localPosition).distance <
                      AppInteraction.singleTouchDrawSlop) {
                    return;
                  }
                  _pendingTouchDownEvent = null;
                  _handlePointerStart(appProvider, pendingTouchDownEvent);
                }
                _handlePointerMove(appProvider, event);
              }
            }
          } else {
            if (_panningPointerId == event.pointer) {
              if (_isMouseRotateDrag) {
                _handleMouseRotateDrag(appProvider, shellProvider, event);
                return;
              }
              _handleUserPanningTheCanvas(
                shellProvider,
                appProvider,
                event.delta,
              );
              return;
            }
            _handlePointerMove(appProvider, event);
          }
        },
        onPointerUp: (PointerUpEvent event) {
          if (event.kind == PointerDeviceKind.touch) {
            final bool wasMultiTouch = _activePointers.length >= AppMath.pair;
            _pointerPositions.remove(event.pointer);
            _activePointers.remove(event.pointer);
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
              _lastScaleDistance = _getDistanceBetweenTouchPoints();
              _lastMultiTouchFocalPoint = _getMultiTouchFocalPoint();
              _lastTouchContactAngle = _getTouchContactAngle();
              _multiTouchPointersMoved.clear();
            }
            if (wasMultiTouch) {
              _pendingTouchDownEvent = null;
            } else {
              final PointerDownEvent? pendingTouchDownEvent = _pendingTouchDownEvent;
              if (pendingTouchDownEvent != null && pendingTouchDownEvent.pointer == event.pointer) {
                _pendingTouchDownEvent = null;
                _handlePointerStart(appProvider, pendingTouchDownEvent);
              }
              _handlePointerEnd(appProvider, event);
            }
          } else {
            if (_panningPointerId == event.pointer) {
              _panningPointerId = -1;
              _isMouseRotateDrag = false;
              _resetGestureTwist();
              return;
            }
            _handlePointerEnd(appProvider, event);
          }
        },
        onPointerCancel: (PointerCancelEvent event) {
          if (event.kind == PointerDeviceKind.touch) {
            final bool wasMultiTouch = _activePointers.length >= AppMath.pair;
            _pointerPositions.remove(event.pointer);
            _activePointers.remove(event.pointer);
            _pendingTouchDownEvent = null;
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
              _lastScaleDistance = _getDistanceBetweenTouchPoints();
              _lastMultiTouchFocalPoint = _getMultiTouchFocalPoint();
              _lastTouchContactAngle = _getTouchContactAngle();
              _multiTouchPointersMoved.clear();
            }
            if (!wasMultiTouch && _activePointerId == event.pointer) {
              _cancelActiveTouchInteraction(appProvider);
            }
            // Release a tolerance pointer lock so a cancelled touch cannot leave
            // the cursor hidden for a later mouse user.
            appProvider.endTolerancePointerLock();
          } else {
            if (_panningPointerId == event.pointer) {
              _panningPointerId = -1;
              _isMouseRotateDrag = false;
              _resetGestureTwist();
              return;
            }
            _handlePointerEnd(appProvider, event);
          }
        },
        child: widget.child,
      ),
    );
  }

  /// The cursor shown over the canvas for the active tool.
  ///
  /// The Edge Detection (magic wand) selector uses a crosshair to signal
  /// "click a point to sample a color region"; every other tool defers to the
  /// default cursor (and to any overlay handles layered above the canvas).
  MouseCursor _canvasCursor(AppProvider appProvider) {
    // A horizontal tolerance drag pins the pointer at its start: hide the OS
    // cursor so it does not appear to wander across the canvas while scrubbing.
    if (appProvider.isTolerancePointerLocked) {
      return SystemMouseCursors.none;
    }
    return appProvider.isWandSelectionActive ? SystemMouseCursors.precise : MouseCursor.defer;
  }

  /// Collapses high-frequency input samples into one canvas rebuild per frame.
  void _scheduleViewportRepaint(AppProvider appProvider) {
    if (_viewportRepaintScheduled) {
      return;
    }

    _viewportRepaintScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((Duration _) {
      _viewportRepaintScheduled = false;
      if (mounted) {
        appProvider.repaintViewport();
      }
    });
  }
}
