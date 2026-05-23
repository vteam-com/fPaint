// ignore: fcheck_one_class_per_file
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/material_free.dart';

/// Coordinate format template for handle labels.
const String _coordinatesFormat = '{x}\n{y}';
const String _placeholderX = '{x}';
const String _placeholderY = '{y}';
const double _overlayControlBorderAlpha = 0.35;
const double _overlayControlShadowAlpha = 0.2;
const double _overlayControlSurfaceAlpha = 0.78;

/// Builds a circular control button used by canvas overlays.
Widget buildOverlayCircleButton({
  required final Widget child,
  required final Color color,
  required final MouseCursor cursor,
  required final String tooltip,
  final double size = AppInteraction.imagePlacementButtonSize,
  final Key? key,
  final VoidCallback? onTap,
  final GestureDragStartCallback? onPanStart,
  final GestureDragUpdateCallback? onPanUpdate,
  final GestureDragEndCallback? onPanEnd,
  final GestureDragCancelCallback? onPanCancel,
}) {
  return AppTooltip(
    key: key,
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
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: AppStroke.regular),
          ),
          child: Center(child: child),
        ),
      ),
    ),
  );
}

/// Builds a standardized mode toggle button for canvas overlays.
///
/// Visual behavior is consistent across overlays: black by default,
/// selected-blue when active, and white icon tint.
Widget buildOverlayModeButton({
  required final String tooltip,
  required final AppIcon icon,
  required final MouseCursor cursor,
  final double size = AppInteraction.imagePlacementButtonSize,
  final double iconSize = AppLayout.iconSize,
  final bool isSelected = false,
  final VoidCallback? onTap,
  final GestureDragStartCallback? onPanStart,
  final GestureDragUpdateCallback? onPanUpdate,
  final GestureDragEndCallback? onPanEnd,
  final GestureDragCancelCallback? onPanCancel,
}) {
  return buildOverlayCircleButton(
    tooltip: tooltip,
    color: isSelected ? AppColors.selected : AppColors.black,
    cursor: cursor,
    size: size,
    onTap: onTap,
    onPanStart: onPanStart,
    onPanUpdate: onPanUpdate,
    onPanEnd: onPanEnd,
    onPanCancel: onPanCancel,
    child: AppSvgIcon(
      icon: icon,
      color: AppColors.white,
      size: iconSize,
    ),
  );
}

/// Builds the floating feedback bubble used by selection and transform controls.
Widget buildOverlayFeedbackBubble({required final String label}) {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.small,
      vertical: AppSpacing.small,
    ),
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: _overlayControlSurfaceAlpha),
      borderRadius: BorderRadius.circular(AppRadius.medium),
      border: Border.all(
        color: AppColors.white.withValues(alpha: _overlayControlBorderAlpha),
        width: AppStroke.thin,
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: AppColors.black.withValues(alpha: _overlayControlShadowAlpha),
          blurRadius: AppSpacing.large,
          offset: const Offset(0, AppSpacing.small),
        ),
      ],
    ),
    child: AppText(
      label,
      variant: AppTextVariant.bodyBold,
      color: AppColors.white,
    ),
  );
}

/// Wraps overlay actions in a shared surface so related controls scan as one unit.
Widget buildOverlayControlSurface({
  required final Widget child,
  final EdgeInsetsGeometry padding = const EdgeInsets.all(AppSpacing.small),
}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.overlayDark.withValues(alpha: _overlayControlSurfaceAlpha),
      borderRadius: BorderRadius.circular(AppRadius.large),
      border: Border.all(
        color: AppColors.white.withValues(alpha: _overlayControlBorderAlpha),
        width: AppStroke.thin,
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: AppColors.black.withValues(alpha: _overlayControlShadowAlpha),
          blurRadius: AppSpacing.large,
          offset: const Offset(0, AppSpacing.small),
        ),
      ],
    ),
    child: Padding(
      padding: padding,
      child: child,
    ),
  );
}

/// Builds the standard Apply (green check) and Cancel (red X) button row
/// used by canvas overlays such as transform, image placement, and eye dropper.
Widget buildOverlayConfirmCancelButtons({
  required final AppLocalizations l10n,
  required final VoidCallback onConfirm,
  required final VoidCallback onCancel,
  final double buttonSize = AppInteraction.imagePlacementButtonSize,
  final double spacing = AppInteraction.imagePlacementButtonSpacing,
  final double iconSize = AppLayout.iconSize,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    spacing: spacing,
    children: <Widget>[
      buildOverlayCircleButton(
        tooltip: l10n.apply,
        color: AppColors.green,
        cursor: SystemMouseCursors.click,
        size: buttonSize,
        onTap: onConfirm,
        child: AppSvgIcon(icon: AppIcon.check, color: AppColors.white, size: iconSize),
      ),
      buildOverlayCircleButton(
        tooltip: l10n.cancel,
        color: AppColors.red,
        cursor: SystemMouseCursors.click,
        size: buttonSize,
        onTap: onCancel,
        child: AppSvgIcon(icon: AppIcon.close, color: AppColors.white, size: iconSize),
      ),
    ],
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
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.onPanCancel,
    this.size = AppInteraction.selectionHandleSize,
    this.borderRadius = AppRadius.large,
    this.backgroundColor = AppColors.overlayDark,
    this.borderColor = AppColors.overlayLight,
  });

  /// Background color of the handle box.
  final Color backgroundColor;

  /// Border color of the handle box.
  final Color borderColor;

  /// Corner radius of the handle box.
  final double borderRadius;

  /// Mouse cursor shown when hovering.
  final MouseCursor cursor;

  /// Called when the drag is canceled.
  final GestureDragCancelCallback? onPanCancel;

  /// Called when the drag ends.
  final VoidCallback? onPanEnd;

  /// Called when the drag starts.
  final GestureDragStartCallback? onPanStart;

  /// Called on every drag update.
  final void Function(DragUpdateDetails)? onPanUpdate;

  /// Screen-space position of the handle center.
  final Offset position;

  /// Base size of the handle in logical pixels.
  final double size;
  @override
  Widget build(final BuildContext context) {
    final double activeSize = size * AppVisual.previewTextScale;

    return Positioned(
      left: position.dx - activeSize / AppMath.pair,
      top: position.dy - activeSize / AppMath.pair,
      child: GestureDetector(
        onPanStart: onPanStart,
        onPanUpdate: onPanUpdate,
        onPanEnd: (final DragEndDetails _) => onPanEnd?.call(),
        onPanCancel: onPanCancel,
        child: MouseRegion(
          cursor: cursor,
          child: Container(
            width: activeSize,
            height: activeSize,
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(color: borderColor, width: AppStroke.regular),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Center(
              child: AppText(
                _coordinatesFormat
                    .replaceFirst(_placeholderX, position.dx.toInt().toString())
                    .replaceFirst(_placeholderY, position.dy.toInt().toString()),
                textAlign: TextAlign.center,
                variant: AppTextVariant.label,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Adds Escape key handling to an overlay [State] class.
///
/// Manages a [FocusNode] lifecycle and requests focus when the widget mounts.
/// When the Escape key is pressed, [onEscapePressed] is called.
///
/// Usage:
/// ```dart
/// class _MyState extends State<MyWidget> with EscapeFocusMixin {
///   @override
///   void onEscapePressed() => widget.onCancel();
///
///   @override
///   Widget build(BuildContext context) {
///     return wrapWithEscapeFocus(child: ...);
///   }
/// }
/// ```
mixin EscapeFocusMixin<T extends StatefulWidget> on State<T> {
  late FocusNode _escapeFocusNode;

  /// Called when the user presses the Escape key while this widget has focus.
  void onEscapePressed();

  @override
  void initState() {
    super.initState();
    _escapeFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _escapeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _escapeFocusNode.dispose();
    super.dispose();
  }

  /// Wraps [child] in a [Focus] widget that calls [onEscapePressed] on Escape.
  Widget wrapWithEscapeFocus({required final Widget child}) {
    return Focus(
      focusNode: _escapeFocusNode,
      onKeyEvent: (final FocusNode _, final KeyEvent _) {
        if (HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.escape)) {
          onEscapePressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

/// Result of [computeOverlayPlacement]: pre-computed vertical positioning
/// values for an overlay controls row (mode buttons + optional feedback bubble).
class OverlayPlacement {
  const OverlayPlacement._({
    required this.positionedTop,
    required this.controlsTop,
    required this.centeredTop,
    required this.isFlippedToBottom,
    required this.isCentered,
  });

  /// Top offset for the outermost [Positioned] widget.
  final double positionedTop;

  /// Top offset of the buttons row itself (used for handle-centre calculations).
  final double controlsTop;

  /// Vertical mid-point used when placement falls back to centred.
  final double centeredTop;

  /// Whether the controls were flipped below the content to avoid top clipping.
  final bool isFlippedToBottom;

  /// Whether the controls were centred because both top and bottom would clip.
  final bool isCentered;

  /// Returns the children for a [Column] in the correct order for this placement.
  ///
  /// The feedback bubble appears above the buttons row for top/centred placement,
  /// and below for bottom placement.
  List<Widget> orderedColumnChildren({
    required final Widget buttonsRow,
    required final bool isFeedbackVisible,
    required final Widget feedbackBubble,
    required final Widget feedbackSpacer,
  }) {
    if (isFlippedToBottom) {
      return <Widget>[
        buttonsRow,
        if (isFeedbackVisible) feedbackSpacer,
        if (isFeedbackVisible) feedbackBubble,
      ];
    }
    return <Widget>[
      if (isFeedbackVisible) feedbackBubble,
      if (isFeedbackVisible) feedbackSpacer,
      buttonsRow,
    ];
  }
}

/// Computes the vertical placement for an overlay controls row, avoiding
/// viewport clipping at both top and bottom edges.
///
/// Pass [idealTop] (the preferred top-above-content position) and [bottomTop]
/// (the fallback position below content). When both positions would clip,
/// the controls are centred within [viewportHeight].
OverlayPlacement computeOverlayPlacement({
  required final double viewportHeight,
  required final double idealTop,
  required final double bottomTop,
  required final bool isFeedbackVisible,
}) {
  const double buttonSize = AppInteraction.imagePlacementButtonSize;
  final double controlsHeight = isFeedbackVisible
      ? buttonSize + AppInteraction.imagePlacementButtonSpacing + buttonSize
      : buttonSize;

  final double topPositionedTop = isFeedbackVisible ? idealTop - buttonSize : idealTop;
  final bool topClips = topPositionedTop < 0;
  final bool bottomClips = bottomTop + controlsHeight > viewportHeight;

  final bool isBottom = topClips && !bottomClips;
  final bool isCentered = topClips && bottomClips;
  final double centeredTop = max(AppMath.zero.toDouble(), (viewportHeight - controlsHeight) / AppMath.pair);
  final double controlsTop = isCentered
      ? centeredTop + (isFeedbackVisible ? buttonSize + AppInteraction.imagePlacementButtonSpacing : 0)
      : (isBottom ? bottomTop : idealTop);
  final double positionedTop = isCentered
      ? centeredTop
      : isBottom
      ? controlsTop
      : isFeedbackVisible
      ? controlsTop - buttonSize
      : controlsTop;

  return OverlayPlacement._(
    positionedTop: positionedTop,
    controlsTop: controlsTop,
    centeredTop: centeredTop,
    isFlippedToBottom: isBottom,
    isCentered: isCentered,
  );
}
