import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';

/// Coordinate format template for handle labels.
const String _coordinatesFormat = '{x}\n{y}';
const String _placeholderX = '{x}';
const String _placeholderY = '{y}';

/// Builds a circular control button used by canvas overlays.
Widget buildOverlayCircleButton({
  required final Widget child,
  required final Color color,
  required final MouseCursor cursor,
  required final String tooltip,
  final VoidCallback? onTap,
  final GestureDragStartCallback? onPanStart,
  final GestureDragUpdateCallback? onPanUpdate,
  final GestureDragEndCallback? onPanEnd,
  final GestureDragCancelCallback? onPanCancel,
}) {
  return Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
      onPanCancel: onPanCancel,
      child: MouseRegion(
        cursor: cursor,
        child: Container(
          width: AppInteraction.imagePlacementButtonSize,
          height: AppInteraction.imagePlacementButtonSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: AppStroke.regular),
          ),
          child: Center(child: child),
        ),
      ),
    ),
  );
}

/// Builds the floating feedback bubble used by selection and transform controls.
Widget buildOverlayFeedbackBubble({required final String label}) {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xxs,
    ),
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: AppVisual.disabled),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: Colors.white, width: AppStroke.thin),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

/// A draggable handle that shows X/Y coordinates while being dragged.
///
/// Used by both the selection overlay and the transform overlay.
class OverlayDragHandle extends StatelessWidget {
  /// Creates an [OverlayDragHandle].
  const OverlayDragHandle({
    super.key,
    required this.position,
    required this.cursor,
    required this.onPanUpdate,
    this.onPanEnd,
    this.showCoordinates = false,
    this.size = AppInteraction.selectionHandleSize,
    this.borderRadius = AppRadius.lg,
  });

  /// Corner radius of the handle box.
  final double borderRadius;

  /// Mouse cursor shown when hovering.
  final MouseCursor cursor;

  /// Called when the drag ends.
  final VoidCallback? onPanEnd;

  /// Called on every drag update.
  final void Function(DragUpdateDetails) onPanUpdate;

  /// Screen-space position of the handle center.
  final Offset position;

  /// Whether to display coordinate labels inside the handle.
  final bool showCoordinates;

  /// Base size of the handle in logical pixels.
  final double size;
  @override
  Widget build(final BuildContext context) {
    final double activeSize = showCoordinates ? size * AppVisual.previewTextScale : size;

    return Positioned(
      left: position.dx - activeSize / AppMath.pair,
      top: position.dy - activeSize / AppMath.pair,
      child: GestureDetector(
        onPanUpdate: onPanUpdate,
        onPanEnd: (final DragEndDetails _) => onPanEnd?.call(),
        child: MouseRegion(
          cursor: cursor,
          child: Container(
            width: activeSize,
            height: activeSize,
            decoration: BoxDecoration(
              color: Colors.blue,
              border: Border.all(color: Colors.white, width: AppStroke.regular),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: showCoordinates
                ? Center(
                    child: Text(
                      _coordinatesFormat
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
}
