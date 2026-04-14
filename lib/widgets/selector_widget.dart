import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';
import 'package:fpaint/helpers/transform_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/widgets/marching_ants_path.dart';
import 'package:fpaint/widgets/overlay_control_widgets.dart';
import 'package:fpaint/widgets/svg_icon.dart';

const String _selectorCoordinatesFormat = '{x}\n{y}';
const String _placeholderX = '{x}';
const String _placeholderY = '{y}';

enum _SelectionOverlayFeedbackMode {
  none,
  resize,
  scale,
  rotate,
}

/// A widget that displays a selection rectangle with handles for resizing and moving.
class SelectionRectWidget extends StatefulWidget {
  /// Creates a [SelectionRectWidget].
  ///
  /// The [path1] parameter specifies the primary path of the selection rectangle.
  /// The [path2] parameter specifies an optional secondary path for the selection rectangle.
  /// The [onDrag] parameter is a callback that is called when the selection rectangle is dragged.
  /// The [onResize] parameter is a callback that is called when the selection rectangle is resized.
  /// The [enableMoveAndResize] parameter specifies whether the selection rectangle can be moved and resized.
  const SelectionRectWidget({
    super.key,
    required this.path1,
    required this.path2,
    required this.onDrag,
    required this.onScale,
    required this.onResize,
    required this.onRotate,
    required this.onToggleTransformMode,
    this.enableMoveAndResize = true,
    this.isDrawing = false,
  });

  /// Whether the selection rectangle can be moved and resized.
  final bool enableMoveAndResize;

  /// Whether a new selection is actively being drawn.
  final bool isDrawing;

  /// A callback that is called when the selection rectangle is dragged.
  final void Function(Offset) onDrag;

  /// A callback that is called when the selection rectangle is resized.
  final void Function(NineGridHandle, Offset) onResize;

  /// A callback that is called when the selection is rotated by [angleRadians].
  final void Function(double angleRadians) onRotate;

  /// A callback that is called when the selection is uniformly scaled.
  final void Function(double factor) onScale;

  /// A callback that toggles between resize/rotate and perspective/skew modes.
  final VoidCallback onToggleTransformMode;

  /// The primary path of the selection rectangle.
  final Path? path1;

  /// An optional secondary path for the selection rectangle.
  final Path? path2;
  @override
  State<SelectionRectWidget> createState() => _SelectionRectWidgetState();
}

const int defaultHandleSize = AppInteraction.selectionHandleSize;

class _SelectionRectWidgetState extends State<SelectionRectWidget> {
  double _activeRotationDegrees = 0;
  double _activeScalePercent = AppMath.percentScale;
  Size _activeResizeDimensions = Size.zero;
  _SelectionOverlayFeedbackMode _feedbackMode = _SelectionOverlayFeedbackMode.none;
  bool showCoordinate = false;
  @override
  Widget build(final BuildContext context) {
    if (widget.path1 == null) {
      return const SizedBox();
    }

    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Rect bounds = widget.path1!.getBounds();
    final double modeToggleSize = AppInteraction.imagePlacementButtonSize;
    final double modeToggleSpacing = AppInteraction.imagePlacementButtonSpacing;
    final double controlsWidth = modeToggleSize * AppMath.triple + modeToggleSpacing * AppMath.pair;
    final double width = max(
      bounds.left + bounds.width + defaultHandleSize,
      bounds.center.dx + controlsWidth / AppMath.pair,
    );

    // Extra space above for the rotation handle stem + handle
    final double rotationOverhead = widget.enableMoveAndResize
        ? AppInteraction.rotationHandleDistance + modeToggleSize
        : 0;
    final double height = bounds.bottom + bounds.height + defaultHandleSize + rotationOverhead;

    final List<Widget> stackChildren = <Widget>[
      AnimatedMarchingAntsPath(path: widget.path1!),
      if (widget.path2 != null) AnimatedMarchingAntsPath(path: widget.path2!),
      _buildModeControls(bounds, l10n),
    ];

    if (widget.enableMoveAndResize) {
      stackChildren.addAll(<Widget>[
        // Center handle for moving
        _buildHandle(
          position: bounds.center,
          cursor: SystemMouseCursors.move,
          onPanUpdate: (final DragUpdateDetails details) => widget.onDrag(
            details.delta,
          ),
        ),

        // Top Left
        _buildHandle(
          position: bounds.topLeft,
          cursor: SystemMouseCursors.resizeUpLeft,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
            NineGridHandle.topLeft,
            details.delta,
          ),
        ),

        // Top Right
        _buildHandle(
          position: bounds.topRight,
          cursor: SystemMouseCursors.resizeUpRight,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
            NineGridHandle.topRight,
            details.delta,
          ),
        ),

        // Bottom Left
        _buildHandle(
          position: bounds.bottomLeft,
          cursor: SystemMouseCursors.resizeDownLeft,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
            NineGridHandle.bottomLeft,
            details.delta,
          ),
        ),

        // Bottom right
        _buildHandle(
          position: bounds.bottomRight,
          cursor: SystemMouseCursors.resizeDownRight,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
            NineGridHandle.bottomRight,
            details.delta,
          ),
        ),

        // Side Left
        _buildHandle(
          position: Offset(
            bounds.left,
            bounds.center.dy,
          ),
          cursor: SystemMouseCursors.resizeLeft,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
            NineGridHandle.left,
            details.delta,
          ),
        ),

        // Side Right
        _buildHandle(
          position: Offset(
            bounds.right,
            bounds.center.dy,
          ),
          cursor: SystemMouseCursors.resizeRight,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
            NineGridHandle.right,
            details.delta,
          ),
        ),

        // Center Top
        _buildHandle(
          position: Offset(
            bounds.center.dx,
            bounds.top,
          ),
          cursor: SystemMouseCursors.resizeUp,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
            NineGridHandle.top,
            details.delta,
          ),
        ),

        // Center Bottom
        _buildHandle(
          position: Offset(
            bounds.center.dx,
            bounds.bottom,
          ),
          cursor: SystemMouseCursors.resizeDown,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
            NineGridHandle.bottom,
            details.delta,
          ),
        ),
      ]);
    }

    return SizedBox(
      width: width < 0 ? 0 : width,
      height: height < 0 ? 0 : height,
      child: Stack(children: stackChildren),
    );
  }

  void _beginRotateFeedback() {
    setState(() {
      _feedbackMode = _SelectionOverlayFeedbackMode.rotate;
      _activeRotationDegrees = 0;
    });
  }

  void _beginScaleFeedback() {
    setState(() {
      _feedbackMode = _SelectionOverlayFeedbackMode.scale;
      _activeScalePercent = AppMath.percentScale;
    });
  }

  /// Builds a handle for resizing or moving the selection rectangle.
  ///
  /// The [position] parameter specifies the position of the handle.
  /// The [cursor] parameter specifies the cursor to display when the mouse is over the handle.
  /// The [onPanUpdate] parameter is a callback that is called when the handle is dragged.
  Widget _buildHandle({
    required final Offset position,
    required final MouseCursor cursor,
    required final void Function(DragUpdateDetails) onPanUpdate,
  }) {
    final int handleSize = (showCoordinate ? (defaultHandleSize * AppVisual.previewTextScale) : defaultHandleSize)
        .toInt();

    return Positioned(
      left: position.dx - (handleSize / AppMath.pair),
      top: position.dy - (handleSize / AppMath.pair),
      child: GestureDetector(
        onPanUpdate: (final DragUpdateDetails details) {
          setState(() {
            showCoordinate = true;
          });
          onPanUpdate(details);
          _updateResizeFeedback();
        },
        onPanEnd: (final DragEndDetails _) {
          setState(() => showCoordinate = false);
          _endFeedback();
        },
        child: MouseRegion(
          cursor: cursor,
          child: Container(
            width: handleSize.toDouble(),
            height: handleSize.toDouble(),
            decoration: BoxDecoration(
              color: Colors.blue,
              border: Border.all(color: Colors.white, width: AppStroke.regular),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: showCoordinate
                ? Center(
                    child: Text(
                      _selectorCoordinatesFormat
                          .replaceFirst(_placeholderX, position.dx.toInt().toString())
                          .replaceFirst(_placeholderY, position.dy.toInt().toString()),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: AppSpacing.sm, color: Colors.white),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  /// Builds the scale, rotate, and transform mode controls shown above the selection.
  Widget _buildModeControls(
    final Rect bounds,
    final AppLocalizations l10n,
  ) {
    final double buttonSize = AppInteraction.imagePlacementButtonSize;
    final double spacing = AppInteraction.imagePlacementButtonSpacing;
    final double controlsWidth = buttonSize * AppMath.triple + spacing * AppMath.pair;
    final double controlsTop = bounds.top - AppInteraction.rotationHandleDistance - buttonSize / AppMath.pair;
    final double controlsLeft = bounds.center.dx - controlsWidth / AppMath.pair;
    final Offset scaleHandleCenter = Offset(
      controlsLeft + buttonSize / AppMath.pair,
      controlsTop + buttonSize / AppMath.pair,
    );
    final Offset rotateHandleCenter = Offset(
      controlsLeft + buttonSize + spacing + buttonSize / AppMath.pair,
      controlsTop + buttonSize / AppMath.pair,
    );

    return Positioned(
      left: controlsLeft,
      top: _isFeedbackVisible ? controlsTop - buttonSize : controlsTop,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_isFeedbackVisible) buildOverlayFeedbackBubble(label: _feedbackLabel(l10n)),
          if (_isFeedbackVisible) const SizedBox(height: AppInteraction.imagePlacementButtonSpacing),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: spacing,
            children: <Widget>[
              buildOverlayCircleButton(
                tooltip: l10n.scale,
                color: AppColors.selected,
                cursor: SystemMouseCursors.grab,
                onPanStart: (final DragStartDetails _) => _beginScaleFeedback(),
                onPanUpdate: (final DragUpdateDetails details) {
                  final double previousDistance = (scaleHandleCenter - bounds.center).distance;
                  final Offset pointer = scaleHandleCenter + details.delta;
                  final double currentDistance = (pointer - bounds.center).distance;
                  if (previousDistance <= AppMath.tinyPercentage) {
                    return;
                  }
                  final double factor = currentDistance / previousDistance;
                  _updateScaleFeedback(factor);
                  widget.onScale(factor);
                },
                onPanEnd: (final DragEndDetails _) => _endFeedback(),
                onPanCancel: _endFeedback,
                child: const Icon(
                  Icons.open_in_full,
                  size: AppLayout.iconSize,
                  color: Colors.white,
                ),
              ),
              buildOverlayCircleButton(
                tooltip: l10n.resizeRotate,
                color: Colors.green,
                cursor: SystemMouseCursors.grab,
                onPanStart: (final DragStartDetails _) => _beginRotateFeedback(),
                onPanUpdate: (final DragUpdateDetails details) {
                  final Offset pointer = rotateHandleCenter + details.delta;
                  final double previousAngle = atan2(
                    rotateHandleCenter.dy - bounds.center.dy,
                    rotateHandleCenter.dx - bounds.center.dx,
                  );
                  final double currentAngle = atan2(
                    pointer.dy - bounds.center.dy,
                    pointer.dx - bounds.center.dx,
                  );
                  final double angleDelta = currentAngle - previousAngle;
                  _updateRotateFeedback(angleDelta);
                  widget.onRotate(angleDelta);
                },
                onPanEnd: (final DragEndDetails _) => _endFeedback(),
                onPanCancel: _endFeedback,
                child: const Icon(
                  Icons.rotate_right,
                  size: AppLayout.iconSize,
                  color: Colors.white,
                ),
              ),
              buildOverlayCircleButton(
                tooltip: l10n.transform,
                color: AppColors.transformCornerHandle,
                cursor: SystemMouseCursors.click,
                onTap: widget.onToggleTransformMode,
                child: iconFromSvgAsset(AppAssets.transformIcon),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _endFeedback() {
    setState(() {
      _feedbackMode = _SelectionOverlayFeedbackMode.none;
      _activeScalePercent = AppMath.percentScale;
      _activeRotationDegrees = 0;
      _activeResizeDimensions = Size.zero;
    });
  }

  /// Returns the localized label for the active feedback bubble.
  String _feedbackLabel(final AppLocalizations l10n) {
    if (widget.isDrawing && widget.path1 != null) {
      final Rect bounds = widget.path1!.getBounds();
      return l10n.dimensionsValue(
        bounds.width.round(),
        bounds.height.round(),
      );
    }
    switch (_feedbackMode) {
      case _SelectionOverlayFeedbackMode.scale:
        return l10n.percentageValue(_activeScalePercent.round());
      case _SelectionOverlayFeedbackMode.rotate:
        return l10n.degreesValue(_activeRotationDegrees.round());
      case _SelectionOverlayFeedbackMode.resize:
        return l10n.dimensionsValue(
          _activeResizeDimensions.width.round(),
          _activeResizeDimensions.height.round(),
        );
      case _SelectionOverlayFeedbackMode.none:
        return '';
    }
  }

  bool get _isFeedbackVisible => _feedbackMode != _SelectionOverlayFeedbackMode.none || widget.isDrawing;

  /// Accumulates [angleRadians] into the live rotation feedback and triggers
  /// haptic feedback when the cumulative angle crosses a snap interval.
  void _updateRotateFeedback(final double angleRadians) {
    setState(() {
      if (_feedbackMode != _SelectionOverlayFeedbackMode.rotate) {
        _feedbackMode = _SelectionOverlayFeedbackMode.rotate;
        _activeRotationDegrees = 0;
      }
      final double previousDegrees = _activeRotationDegrees;
      _activeRotationDegrees += angleRadians * AppMath.degreesPerHalfTurn / pi;
      triggerRotationSnapHaptic(previousDegrees, _activeRotationDegrees);
    });
  }

  /// Multiplies the live scale percentage by [factor] and triggers haptic
  /// feedback when the cumulative scale crosses a snap interval.
  void _updateScaleFeedback(final double factor) {
    setState(() {
      if (_feedbackMode != _SelectionOverlayFeedbackMode.scale) {
        _feedbackMode = _SelectionOverlayFeedbackMode.scale;
        _activeScalePercent = AppMath.percentScale;
      }
      final double previousPercent = _activeScalePercent;
      _activeScalePercent *= factor;
      triggerScaleSnapHaptic(previousPercent, _activeScalePercent);
    });
  }

  /// Updates the resize dimensions feedback from the current path bounds.
  void _updateResizeFeedback() {
    if (widget.path1 == null) {
      return;
    }
    setState(() {
      _feedbackMode = _SelectionOverlayFeedbackMode.resize;
      final Rect bounds = widget.path1!.getBounds();
      _activeResizeDimensions = bounds.size;
    });
  }
}
