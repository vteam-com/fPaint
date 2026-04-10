import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/transform_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/transform_model.dart';

/// An overlay widget that lets the user interactively skew and change
/// perspective of a selected region by dragging corner and edge handles.
class TransformWidget extends StatelessWidget {
  /// Creates a [TransformWidget].
  const TransformWidget({
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

  /// The current transform state.
  final TransformModel model;

  /// Called when the user cancels the transform.
  final VoidCallback onCancel;

  /// Called whenever the user drags a handle.
  final VoidCallback onChanged;

  /// Called when the user commits the transform.
  final VoidCallback onConfirm;

  @override
  Widget build(final BuildContext context) {
    final ui.Image? image = model.sourceImage;
    if (image == null || model.corners.isEmpty) {
      return const SizedBox();
    }

    final AppLocalizations l10n = AppLocalizations.of(context)!;

    // Convert corners to screen space
    final List<Offset> screenCorners = model.corners.map((final Offset c) => _toScreen(c)).toList();

    final Offset screenCenter = _toScreen(model.center);

    // Edge midpoints in screen space
    final Offset topMid = _toScreen(
      model.edgeMidpoint(TransformModel.topLeftIndex, TransformModel.topRightIndex),
    );
    final Offset rightMid = _toScreen(
      model.edgeMidpoint(TransformModel.topRightIndex, TransformModel.bottomRightIndex),
    );
    final Offset bottomMid = _toScreen(
      model.edgeMidpoint(TransformModel.bottomRightIndex, TransformModel.bottomLeftIndex),
    );
    final Offset leftMid = _toScreen(
      model.edgeMidpoint(TransformModel.bottomLeftIndex, TransformModel.topLeftIndex),
    );

    return SizedBox.expand(
      child: Stack(
        children: <Widget>[
          // Warped image preview + outline
          CustomPaint(
            size: Size.infinite,
            painter: _TransformPreviewPainter(
              image: image,
              screenCorners: screenCorners,
            ),
          ),

          // Corner handles (perspective)
          _buildCornerHandle(TransformModel.topLeftIndex, screenCorners[TransformModel.topLeftIndex]),
          _buildCornerHandle(TransformModel.topRightIndex, screenCorners[TransformModel.topRightIndex]),
          _buildCornerHandle(TransformModel.bottomRightIndex, screenCorners[TransformModel.bottomRightIndex]),
          _buildCornerHandle(TransformModel.bottomLeftIndex, screenCorners[TransformModel.bottomLeftIndex]),

          // Edge midpoint handles (skew)
          _buildEdgeHandle(
            TransformModel.topLeftIndex,
            TransformModel.topRightIndex,
            topMid,
          ),
          _buildEdgeHandle(
            TransformModel.topRightIndex,
            TransformModel.bottomRightIndex,
            rightMid,
          ),
          _buildEdgeHandle(
            TransformModel.bottomRightIndex,
            TransformModel.bottomLeftIndex,
            bottomMid,
          ),
          _buildEdgeHandle(
            TransformModel.bottomLeftIndex,
            TransformModel.topLeftIndex,
            leftMid,
          ),

          // Center handle (move)
          _buildHandle(
            position: screenCenter,
            size: AppInteraction.imagePlacementHandleSize,
            color: Colors.blue,
            cursor: SystemMouseCursors.move,
            onPanUpdate: (final DragUpdateDetails details) {
              model.moveAll(details.delta / canvasScale);
              onChanged();
            },
          ),

          // Confirm / Cancel buttons
          Positioned(
            left:
                screenCenter.dx -
                (AppInteraction.imagePlacementButtonSize + AppInteraction.imagePlacementButtonSpacing / AppMath.pair),
            top:
                _screenQuadBottom(screenCorners) +
                AppInteraction.imagePlacementButtonSpacing +
                AppInteraction.imagePlacementHandleSize,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: AppInteraction.imagePlacementButtonSpacing,
              children: <Widget>[
                _actionButton(
                  icon: Icons.check,
                  color: Colors.green,
                  tooltip: l10n.apply,
                  onPressed: onConfirm,
                ),
                _actionButton(
                  icon: Icons.close,
                  color: Colors.red,
                  tooltip: l10n.cancel,
                  onPressed: onCancel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required final IconData icon,
    required final Color color,
    required final String tooltip,
    required final VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: AppInteraction.imagePlacementButtonSize,
          height: AppInteraction.imagePlacementButtonSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: AppStroke.regular),
          ),
          child: Icon(icon, color: Colors.white, size: AppLayout.iconSize),
        ),
      ),
    );
  }

  Widget _buildCornerHandle(final int index, final Offset position) {
    return _buildHandle(
      position: position,
      size: AppInteraction.imagePlacementHandleSize,
      color: AppColors.transformCornerHandle,
      cursor: SystemMouseCursors.grab,
      onPanUpdate: (final DragUpdateDetails details) {
        model.moveCorner(index, details.delta / canvasScale);
        onChanged();
      },
    );
  }

  Widget _buildEdgeHandle(final int index1, final int index2, final Offset position) {
    return _buildHandle(
      position: position,
      size: AppInteraction.transformEdgeHandleSize,
      color: AppColors.transformEdgeHandle,
      cursor: SystemMouseCursors.grab,
      onPanUpdate: (final DragUpdateDetails details) {
        model.moveEdge(index1, index2, details.delta / canvasScale);
        onChanged();
      },
    );
  }

  Widget _buildHandle({
    required final Offset position,
    required final double size,
    required final Color color,
    required final MouseCursor cursor,
    required final void Function(DragUpdateDetails) onPanUpdate,
  }) {
    return Positioned(
      left: position.dx - size / AppMath.pair,
      top: position.dy - size / AppMath.pair,
      child: GestureDetector(
        onPanUpdate: onPanUpdate,
        child: MouseRegion(
          cursor: cursor,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.white, width: AppStroke.regular),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ),
      ),
    );
  }

  double _screenQuadBottom(final List<Offset> screenCorners) {
    double maxY = screenCorners[0].dy;
    for (final Offset corner in screenCorners) {
      if (corner.dy > maxY) {
        maxY = corner.dy;
      }
    }
    return maxY;
  }

  Offset _toScreen(final Offset canvasPoint) {
    return canvasPoint * canvasScale + canvasOffset;
  }
}

/// Custom painter that renders the perspective-warped image preview and quad outline.
class _TransformPreviewPainter extends CustomPainter {
  _TransformPreviewPainter({
    required this.image,
    required this.screenCorners,
  });

  final ui.Image image;
  final List<Offset> screenCorners;

  @override
  void paint(final Canvas canvas, final Size size) {
    // Draw warped image
    drawPerspectiveImage(
      canvas,
      image,
      screenCorners,
      AppInteraction.transformGridSubdivisions,
    );

    // Draw quad outline
    final Paint outlinePaint = Paint()
      ..color = AppColors.transformCornerHandle
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.regular;

    final Path outlinePath = Path()
      ..moveTo(screenCorners[0].dx, screenCorners[0].dy)
      ..lineTo(screenCorners[1].dx, screenCorners[1].dy)
      ..lineTo(screenCorners[2].dx, screenCorners[2].dy)
      ..lineTo(screenCorners[3].dx, screenCorners[3].dy)
      ..close();

    canvas.drawPath(outlinePath, outlinePaint);
  }

  @override
  bool shouldRepaint(final _TransformPreviewPainter oldDelegate) => true;
}
