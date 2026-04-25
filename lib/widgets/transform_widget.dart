import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/transform_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart' show AppIcon;
import 'package:fpaint/models/transform_model.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/overlay_control_widgets.dart';

/// An overlay widget that lets the user interactively skew and change
/// perspective of a selected region by dragging corner and edge handles.
class TransformWidget extends StatefulWidget {
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
  State<TransformWidget> createState() => _TransformWidgetState();
}

class _TransformWidgetState extends State<TransformWidget> {
  @override
  Widget build(final BuildContext context) {
    final ui.Image? image = model.sourceImage;
    if (image == null || model.corners.isEmpty) {
      return const SizedBox();
    }

    final AppLocalizations l10n = context.l10n;

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

          if (model.isDeformMode) ...<Widget>[
            // Corner handles (perspective)
            OverlayDragHandle(
              position: screenCorners[TransformModel.topLeftIndex],
              cursor: SystemMouseCursors.grab,
              onPanUpdate: (final DragUpdateDetails details) {
                model.moveCorner(TransformModel.topLeftIndex, details.delta / canvasScale);
                onChanged();
              },
            ),
            OverlayDragHandle(
              position: screenCorners[TransformModel.topRightIndex],
              cursor: SystemMouseCursors.grab,
              onPanUpdate: (final DragUpdateDetails details) {
                model.moveCorner(TransformModel.topRightIndex, details.delta / canvasScale);
                onChanged();
              },
            ),
            OverlayDragHandle(
              position: screenCorners[TransformModel.bottomRightIndex],
              cursor: SystemMouseCursors.grab,
              onPanUpdate: (final DragUpdateDetails details) {
                model.moveCorner(TransformModel.bottomRightIndex, details.delta / canvasScale);
                onChanged();
              },
            ),
            OverlayDragHandle(
              position: screenCorners[TransformModel.bottomLeftIndex],
              cursor: SystemMouseCursors.grab,
              onPanUpdate: (final DragUpdateDetails details) {
                model.moveCorner(TransformModel.bottomLeftIndex, details.delta / canvasScale);
                onChanged();
              },
            ),

            // Edge midpoint handles (skew)
            OverlayDragHandle(
              position: topMid,
              cursor: SystemMouseCursors.grab,
              onPanUpdate: (final DragUpdateDetails details) {
                model.moveEdge(TransformModel.topLeftIndex, TransformModel.topRightIndex, details.delta / canvasScale);
                onChanged();
              },
            ),
            OverlayDragHandle(
              position: rightMid,
              cursor: SystemMouseCursors.grab,
              onPanUpdate: (final DragUpdateDetails details) {
                model.moveEdge(
                  TransformModel.topRightIndex,
                  TransformModel.bottomRightIndex,
                  details.delta / canvasScale,
                );
                onChanged();
              },
            ),
            OverlayDragHandle(
              position: bottomMid,
              cursor: SystemMouseCursors.grab,
              onPanUpdate: (final DragUpdateDetails details) {
                model.moveEdge(
                  TransformModel.bottomRightIndex,
                  TransformModel.bottomLeftIndex,
                  details.delta / canvasScale,
                );
                onChanged();
              },
            ),
            OverlayDragHandle(
              position: leftMid,
              cursor: SystemMouseCursors.grab,
              onPanUpdate: (final DragUpdateDetails details) {
                model.moveEdge(
                  TransformModel.bottomLeftIndex,
                  TransformModel.topLeftIndex,
                  details.delta / canvasScale,
                );
                onChanged();
              },
            ),

            // Center handle (move)
            OverlayDragHandle(
              position: screenCenter,
              cursor: SystemMouseCursors.move,
              onPanUpdate: (final DragUpdateDetails details) {
                model.moveAll(details.delta / canvasScale);
                onChanged();
              },
            ),
          ],

          _buildModeControls(
            l10n: l10n,
            screenCenter: screenCenter,
            screenCorners: screenCorners,
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
            child: buildOverlayConfirmCancelButtons(
              l10n: l10n,
              onConfirm: onConfirm,
              onCancel: onCancel,
            ),
          ),
        ],
      ),
    );
  }

  /// The canvas translation offset in screen coordinates.
  Offset get canvasOffset => widget.canvasOffset;

  /// The canvas zoom scale factor.
  double get canvasScale => widget.canvasScale;

  /// The current transform state.
  TransformModel get model => widget.model;

  /// Called when the user cancels the transform.
  VoidCallback get onCancel => widget.onCancel;

  /// Called whenever the user drags a handle.
  VoidCallback get onChanged => widget.onChanged;

  /// Called when the user commits the transform.
  VoidCallback get onConfirm => widget.onConfirm;

  /// Builds the transform mode controls and their live feedback bubble.
  Widget _buildModeControls({
    required final AppLocalizations l10n,
    required final Offset screenCenter,
    required final List<Offset> screenCorners,
  }) {
    const double buttonSize = AppInteraction.imagePlacementButtonSize;
    const double spacing = AppInteraction.imagePlacementButtonSpacing;
    const double controlsWidth = buttonSize * AppMath.triple + spacing * AppMath.pair;
    final double controlsTop = _screenQuadTop(screenCorners) - buttonSize - AppInteraction.imagePlacementHandleSize;
    final double controlsLeft = screenCenter.dx - controlsWidth / AppMath.pair;
    final Offset scaleHandleCenter = Offset(
      controlsLeft + buttonSize / AppMath.pair,
      controlsTop + buttonSize / AppMath.pair,
    );
    final Offset rotationHandleCenter = Offset(
      controlsLeft + buttonSize + spacing + buttonSize / AppMath.pair,
      controlsTop + buttonSize / AppMath.pair,
    );

    return Positioned(
      left: controlsLeft,
      top: model.isFeedbackVisible ? controlsTop - buttonSize : controlsTop,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (model.isFeedbackVisible)
            buildOverlayFeedbackBubble(
              label: model.isScaleFeedbackVisible
                  ? l10n.percentageValue(model.activeScalePercent.round())
                  : l10n.degreesValue(model.activeRotationDegrees.round()),
            ),
          if (model.isFeedbackVisible) const SizedBox(height: AppInteraction.imagePlacementButtonSpacing),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: spacing,
            children: <Widget>[
              buildOverlayCircleButton(
                tooltip: l10n.scale,
                color: AppColors.selected,
                cursor: SystemMouseCursors.grab,
                onTap: () {
                  if (!model.isScaleMode) {
                    model.setScaleMode();
                    onChanged();
                  }
                },
                onPanStart: (final DragStartDetails _) {
                  model.beginScaleGesture();
                  onChanged();
                },
                onPanUpdate: (final DragUpdateDetails details) {
                  if (!model.isScaleMode || !model.isScaleFeedbackVisible) {
                    model.beginScaleGesture();
                  }

                  final double previousDistance = (scaleHandleCenter - screenCenter).distance;
                  final Offset pointer = scaleHandleCenter + details.delta;
                  final double currentDistance = (pointer - screenCenter).distance;
                  if (previousDistance <= AppMath.tinyPercentage) {
                    return;
                  }

                  model.scaleUniform(currentDistance / previousDistance);
                  onChanged();
                },
                onPanEnd: (final DragEndDetails _) {
                  model.endScaleGesture();
                  onChanged();
                },
                onPanCancel: () {
                  model.endScaleGesture();
                  onChanged();
                },
                child: const AppSvgIcon(icon: AppIcon.openInFull, size: AppLayout.iconSize, color: AppPalette.white),
              ),
              buildOverlayCircleButton(
                tooltip: l10n.resizeRotate,
                color: AppPalette.green,
                cursor: SystemMouseCursors.grab,
                onTap: () {
                  if (!model.isRotateMode) {
                    model.setRotateMode();
                    onChanged();
                  }
                },
                onPanStart: (final DragStartDetails _) {
                  model.beginRotateGesture();
                  onChanged();
                },
                onPanUpdate: (final DragUpdateDetails details) {
                  if (!model.isRotateMode || !model.isRotationFeedbackVisible) {
                    model.beginRotateGesture();
                  }
                  final double previousAngle = atan2(
                    rotationHandleCenter.dy - screenCenter.dy,
                    rotationHandleCenter.dx - screenCenter.dx,
                  );
                  final Offset pointer = rotationHandleCenter + details.delta;
                  final double currentAngle = atan2(
                    pointer.dy - screenCenter.dy,
                    pointer.dx - screenCenter.dx,
                  );
                  final double angleDelta = currentAngle - previousAngle;
                  model.rotate(angleDelta);
                  model.updateRotationFeedback(angleDelta);
                  onChanged();
                },
                onPanEnd: (final DragEndDetails _) {
                  model.endRotateGesture();
                  onChanged();
                },
                onPanCancel: () {
                  model.endRotateGesture();
                  onChanged();
                },
                child: const AppSvgIcon(icon: AppIcon.rotateRight, size: AppLayout.iconSize, color: AppPalette.white),
              ),
              buildOverlayCircleButton(
                tooltip: l10n.transform,
                color: AppColors.transformCornerHandle,
                cursor: SystemMouseCursors.click,
                onTap: () {
                  if (!model.isDeformMode) {
                    model.setDeformMode();
                    onChanged();
                  }
                },
                child: const AppSvgIcon(icon: AppIcon.transform),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Returns the lowest on-screen Y value of the transformed quad.
  double _screenQuadBottom(final List<Offset> screenCorners) {
    double maxY = screenCorners[TransformModel.topLeftIndex].dy;
    for (final Offset corner in screenCorners) {
      if (corner.dy > maxY) {
        maxY = corner.dy;
      }
    }
    return maxY;
  }

  /// Returns the highest on-screen Y value of the transformed quad.
  double _screenQuadTop(final List<Offset> screenCorners) {
    double minY = screenCorners[TransformModel.topLeftIndex].dy;
    for (final Offset corner in screenCorners) {
      if (corner.dy < minY) {
        minY = corner.dy;
      }
    }
    return minY;
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
      ..moveTo(screenCorners[TransformModel.topLeftIndex].dx, screenCorners[TransformModel.topLeftIndex].dy)
      ..lineTo(screenCorners[TransformModel.topRightIndex].dx, screenCorners[TransformModel.topRightIndex].dy)
      ..lineTo(screenCorners[TransformModel.bottomRightIndex].dx, screenCorners[TransformModel.bottomRightIndex].dy)
      ..lineTo(screenCorners[TransformModel.bottomLeftIndex].dx, screenCorners[TransformModel.bottomLeftIndex].dy)
      ..close();

    canvas.drawPath(outlinePath, outlinePaint);
  }

  @override
  bool shouldRepaint(final _TransformPreviewPainter oldDelegate) => true;
}
