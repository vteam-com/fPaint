import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';

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
