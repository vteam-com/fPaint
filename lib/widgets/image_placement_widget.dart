import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/image_placement_model.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/overlay_control_widgets.dart';
import 'package:fpaint/widgets/rotation_handle_widgets.dart';

/// An overlay widget that lets the user move, scale, and rotate a pasted image
/// before committing it to the canvas.
class ImagePlacementWidget extends StatelessWidget {
  /// Creates an [ImagePlacementWidget].
  const ImagePlacementWidget({
    super.key,
    required this.model,
    required this.canvasOffset,
    required this.canvasScale,
    required this.onChanged,
    required this.onConfirm,
    required this.onCancel,
  });

  /// The canvas translation offset in screen coordinates.
  final Offset canvasOffset;

  /// The canvas zoom scale factor.
  final double canvasScale;

  /// The current placement state.
  final ImagePlacementModel model;

  /// Called when the user cancels the placement.
  final VoidCallback onCancel;

  /// Called whenever the user moves, scales, or rotates the image.
  final VoidCallback onChanged;

  /// Called when the user commits the placement.
  final VoidCallback onConfirm;
  @override
  Widget build(final BuildContext context) {
    final ui.Image? image = model.image;
    if (image == null) {
      return const SizedBox();
    }

    final AppLocalizations l10n = context.l10n;

    // Screen-space bounding rect of the image
    final Offset screenTopLeft = _toScreen(model.position);
    final double screenWidth = model.displayWidth * canvasScale;
    final double screenHeight = model.displayHeight * canvasScale;
    final Rect screenBounds = Rect.fromLTWH(
      screenTopLeft.dx,
      screenTopLeft.dy,
      screenWidth,
      screenHeight,
    );
    final Offset screenCenter = screenBounds.center;

    return SizedBox.expand(
      child: Stack(
        children: <Widget>[
          // Transformed image preview
          Positioned(
            left: screenBounds.left,
            top: screenBounds.top,
            child: Transform.rotate(
              angle: model.rotation,
              child: CustomPaint(
                size: Size(screenWidth, screenHeight),
                painter: _ImagePreviewPainter(image: image),
              ),
            ),
          ),

          // Dashed border around the image
          Positioned(
            left: screenBounds.left,
            top: screenBounds.top,
            child: Transform.rotate(
              angle: model.rotation,
              child: IgnorePointer(
                child: Container(
                  width: screenWidth,
                  height: screenHeight,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppPalette.blue,
                      width: AppStroke.thin,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Move handle (center)
          _buildHandle(
            position: screenCenter,
            cursor: SystemMouseCursors.move,
            onPanUpdate: (final DragUpdateDetails details) {
              model.position += details.delta / canvasScale;
              onChanged();
            },
          ),

          // Corner resize handles
          ..._buildCornerHandles(screenBounds),

          // Rotation handle above the top center
          _buildRotationHandle(screenBounds, screenCenter, l10n),

          // Rotation stem line
          buildRotationStem(
            screenBounds,
            handleSize: AppInteraction.imagePlacementButtonSize,
          ),

          // Confirm / Cancel buttons below the image
          Positioned(
            left:
                screenCenter.dx -
                (AppInteraction.imagePlacementButtonSize + AppInteraction.imagePlacementButtonSpacing / AppMath.pair),
            top:
                screenBounds.bottom +
                AppInteraction.imagePlacementButtonSpacing +
                AppInteraction.imagePlacementHandleSize,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: AppInteraction.imagePlacementButtonSpacing,
              children: <Widget>[
                buildOverlayCircleButton(
                  tooltip: l10n.apply,
                  color: AppPalette.green,
                  cursor: SystemMouseCursors.click,
                  onTap: onConfirm,
                  child: const AppSvgIcon(icon: AppIcon.check, color: AppPalette.white, size: AppLayout.iconSize),
                ),
                buildOverlayCircleButton(
                  tooltip: l10n.cancel,
                  color: AppPalette.red,
                  cursor: SystemMouseCursors.click,
                  onTap: onCancel,
                  child: const AppSvgIcon(icon: AppIcon.close, color: AppPalette.white, size: AppLayout.iconSize),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the four corner handles that let the user uniformly scale the
  /// image while keeping the opposite corner anchored.
  List<Widget> _buildCornerHandles(final Rect screenBounds) {
    return <Widget>[
      // Bottom-right: scale uniformly
      _buildHandle(
        position: screenBounds.bottomRight,
        cursor: SystemMouseCursors.resizeDownRight,
        onPanUpdate: (final DragUpdateDetails details) {
          final double dx = details.delta.dx / canvasScale;
          final double dy = details.delta.dy / canvasScale;
          // Use the larger movement axis to keep aspect ratio
          final double delta = dx.abs() > dy.abs() ? dx : dy;
          final double newScale = (model.scale + delta / (model.image!.width.toDouble())).clamp(
            AppInteraction.imagePlacementMinScale,
            AppInteraction.imagePlacementMaxScale,
          );
          model.scale = newScale;
          onChanged();
        },
      ),
      // Top-left: scale from opposite corner
      _buildHandle(
        position: screenBounds.topLeft,
        cursor: SystemMouseCursors.resizeUpLeft,
        onPanUpdate: (final DragUpdateDetails details) {
          final double dx = details.delta.dx / canvasScale;
          final double dy = details.delta.dy / canvasScale;
          final double delta = dx.abs() > dy.abs() ? -dx : -dy;
          final double oldWidth = model.displayWidth;
          final double oldHeight = model.displayHeight;
          final double newScale = (model.scale + delta / (model.image!.width.toDouble())).clamp(
            AppInteraction.imagePlacementMinScale,
            AppInteraction.imagePlacementMaxScale,
          );
          model.scale = newScale;
          // Adjust position so the bottom-right corner stays fixed
          model.position += Offset(
            oldWidth - model.displayWidth,
            oldHeight - model.displayHeight,
          );
          onChanged();
        },
      ),
      // Top-right
      _buildHandle(
        position: screenBounds.topRight,
        cursor: SystemMouseCursors.resizeUpRight,
        onPanUpdate: (final DragUpdateDetails details) {
          final double dx = details.delta.dx / canvasScale;
          final double dy = details.delta.dy / canvasScale;
          final double delta = dx.abs() > dy.abs() ? dx : -dy;
          final double oldHeight = model.displayHeight;
          final double newScale = (model.scale + delta / (model.image!.width.toDouble())).clamp(
            AppInteraction.imagePlacementMinScale,
            AppInteraction.imagePlacementMaxScale,
          );
          model.scale = newScale;
          // Bottom-left stays fixed: only Y shifts
          model.position += Offset(0, oldHeight - model.displayHeight);
          onChanged();
        },
      ),
      // Bottom-left
      _buildHandle(
        position: screenBounds.bottomLeft,
        cursor: SystemMouseCursors.resizeDownLeft,
        onPanUpdate: (final DragUpdateDetails details) {
          final double dx = details.delta.dx / canvasScale;
          final double dy = details.delta.dy / canvasScale;
          final double delta = dx.abs() > dy.abs() ? -dx : dy;
          final double oldWidth = model.displayWidth;
          final double newScale = (model.scale + delta / (model.image!.width.toDouble())).clamp(
            AppInteraction.imagePlacementMinScale,
            AppInteraction.imagePlacementMaxScale,
          );
          model.scale = newScale;
          // Top-right stays fixed: only X shifts
          model.position += Offset(oldWidth - model.displayWidth, 0);
          onChanged();
        },
      ),
    ];
  }

  /// Builds a single draggable handle at [position] with the given mouse
  /// [cursor] and pan-update [onPanUpdate] callback.
  Widget _buildHandle({
    required final Offset position,
    required final MouseCursor cursor,
    required final void Function(DragUpdateDetails) onPanUpdate,
  }) {
    const double handleSize = AppInteraction.imagePlacementHandleSize;
    return Positioned(
      left: position.dx - handleSize / AppMath.pair,
      top: position.dy - handleSize / AppMath.pair,
      child: GestureDetector(
        onPanUpdate: onPanUpdate,
        child: MouseRegion(
          cursor: cursor,
          child: Container(
            width: handleSize,
            height: handleSize,
            decoration: BoxDecoration(
              color: AppPalette.blue,
              border: Border.all(color: AppPalette.white, width: AppStroke.regular),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the circular green rotation handle above the bounding box.
  ///
  /// Dragging this handle rotates the image around [screenCenter].
  Widget _buildRotationHandle(
    final Rect screenBounds,
    final Offset screenCenter,
    final AppLocalizations l10n,
  ) {
    const double handleSize = AppInteraction.imagePlacementButtonSize;
    final Offset handleCenter = Offset(
      screenBounds.center.dx,
      screenBounds.top - AppInteraction.rotationHandleDistance,
    );

    return Positioned(
      left: handleCenter.dx - handleSize / AppMath.pair,
      top: handleCenter.dy - handleSize / AppMath.pair,
      child: buildOverlayCircleButton(
        tooltip: l10n.resizeRotate,
        color: AppPalette.green,
        cursor: SystemMouseCursors.grab,
        onPanUpdate: (final DragUpdateDetails details) {
          final Offset pointer = handleCenter + details.delta;
          final double previousAngle = atan2(
            handleCenter.dy - screenCenter.dy,
            handleCenter.dx - screenCenter.dx,
          );
          final double currentAngle = atan2(
            pointer.dy - screenCenter.dy,
            pointer.dx - screenCenter.dx,
          );
          model.rotation += currentAngle - previousAngle;
          onChanged();
        },
        child: const AppSvgIcon(icon: AppIcon.rotateRight, size: AppLayout.iconSize, color: AppPalette.white),
      ),
    );
  }

  /// Converts a canvas-space point to screen-space.
  Offset _toScreen(final Offset canvasPoint) {
    return canvasPoint * canvasScale + canvasOffset;
  }
}

/// Paints a [ui.Image] scaled to fill the given size.
class _ImagePreviewPainter extends CustomPainter {
  _ImagePreviewPainter({required this.image});

  final ui.Image image;

  @override
  void paint(final Canvas canvas, final Size size) {
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: image,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant final _ImagePreviewPainter oldDelegate) => oldDelegate.image != image;
}
