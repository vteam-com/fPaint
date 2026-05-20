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

/// Invisible drag target aligned to a transform edge segment.
class TransformEdgeDragZone extends StatelessWidget {
  /// Creates a [TransformEdgeDragZone].
  const TransformEdgeDragZone({
    super.key,
    required this.edgeIndex,
    required this.cursor,
    required this.onDragDelta,
    required this.segmentStart,
    required this.segmentEnd,
  });

  /// Mouse cursor shown when hovering.
  final MouseCursor cursor;

  /// The logical transform edge this zone belongs to.
  final int edgeIndex;

  /// Called on every drag update with the delta converted to screen space.
  final ValueChanged<Offset> onDragDelta;

  /// End point of the draggable edge segment in screen coordinates.
  final Offset segmentEnd;

  /// Start point of the draggable edge segment in screen coordinates.
  final Offset segmentStart;
  @override
  Widget build(final BuildContext context) {
    final Offset segmentDelta = segmentEnd - segmentStart;
    final double zoneThickness = max(
      AppInteraction.selectionHandleSize,
      AppInteraction.transformEdgeHandleSize * AppVisual.previewTextScale,
    );
    final double zoneLength = max(segmentDelta.distance, zoneThickness);
    final Offset zoneCenter = Offset(
      (segmentStart.dx + segmentEnd.dx) / AppMath.pair,
      (segmentStart.dy + segmentEnd.dy) / AppMath.pair,
    );
    final double zoneAngle = atan2(segmentDelta.dy, segmentDelta.dx);

    return Positioned(
      left: zoneCenter.dx - zoneLength / AppMath.pair,
      top: zoneCenter.dy - zoneThickness / AppMath.pair,
      child: Transform.rotate(
        angle: zoneAngle,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanUpdate: (final DragUpdateDetails details) {
            onDragDelta(_toScreenDelta(details.delta, zoneAngle));
          },
          child: MouseRegion(
            cursor: cursor,
            child: SizedBox(width: zoneLength, height: zoneThickness),
          ),
        ),
      ),
    );
  }

  /// Converts the rotated drag-zone local delta back into screen space.
  Offset _toScreenDelta(final Offset localDelta, final double angle) {
    final double cosine = cos(angle);
    final double sine = sin(angle);

    return Offset(
      (localDelta.dx * cosine) - (localDelta.dy * sine),
      (localDelta.dx * sine) + (localDelta.dy * cosine),
    );
  }
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
    final List<Offset> screenEdgeMidpoints = model.effectiveEdgeMidpoints
        .map((final Offset c) => _toScreen(c))
        .toList();
    final List<Offset> screenBoundaryPoints = model.boundaryPoints.map((final Offset c) => _toScreen(c)).toList();
    final bool areCornerHandlesEnabled = model.areCornerHandlesEnabled;
    final bool areEdgeHandlesEnabled = model.areEdgeHandlesEnabled;
    final bool areEdgeDragZonesEnabled = areCornerHandlesEnabled || areEdgeHandlesEnabled;
    final bool isCenterHandleEnabled = model.isCenterHandleEnabled;

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
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: _TransformPreviewPainter(
                image: image,
                screenCorners: screenCorners,
                screenEdgeMidpoints: screenEdgeMidpoints,
                screenBoundaryPoints: screenBoundaryPoints,
              ),
            ),
          ),

          if (model.isDeformMode) ...<Widget>[
            if (areEdgeDragZonesEnabled)
              ..._buildEdgeDragZones(
                screenCorners: screenCorners,
                screenEdgeMidpoints: screenEdgeMidpoints,
              ),

            if (areCornerHandlesEnabled) ...<Widget>[
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
            ],

            if (areEdgeHandlesEnabled) ...<Widget>[
              // Edge midpoint handles (skew)
              OverlayDragHandle(
                position: topMid,
                cursor: SystemMouseCursors.grab,
                onPanUpdate: (final DragUpdateDetails details) {
                  model.moveEdgeHandle(TransformModel.topEdgeIndex, details.delta / canvasScale);
                  onChanged();
                },
              ),
              OverlayDragHandle(
                position: rightMid,
                cursor: SystemMouseCursors.grab,
                onPanUpdate: (final DragUpdateDetails details) {
                  model.moveEdgeHandle(TransformModel.rightEdgeIndex, details.delta / canvasScale);
                  onChanged();
                },
              ),
              OverlayDragHandle(
                position: bottomMid,
                cursor: SystemMouseCursors.grab,
                onPanUpdate: (final DragUpdateDetails details) {
                  model.moveEdgeHandle(TransformModel.bottomEdgeIndex, details.delta / canvasScale);
                  onChanged();
                },
              ),
              OverlayDragHandle(
                position: leftMid,
                cursor: SystemMouseCursors.grab,
                onPanUpdate: (final DragUpdateDetails details) {
                  model.moveEdgeHandle(TransformModel.leftEdgeIndex, details.delta / canvasScale);
                  onChanged();
                },
              ),
            ],

            if (isCenterHandleEnabled)
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
            screenCorners: screenBoundaryPoints,
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

  /// Builds one invisible drag target for a single edge segment.
  Widget _buildEdgeDragZone({
    required final int edgeIndex,
    required final Offset segmentStart,
    required final Offset segmentEnd,
  }) {
    return TransformEdgeDragZone(
      edgeIndex: edgeIndex,
      cursor: SystemMouseCursors.grab,
      onDragDelta: (final Offset delta) {
        model.moveConnectedEdge(edgeIndex, delta / canvasScale);
        onChanged();
      },
      segmentStart: segmentStart,
      segmentEnd: segmentEnd,
    );
  }

  /// Builds drag targets along each visible edge segment of the transform mesh.
  List<Widget> _buildEdgeDragZones({
    required final List<Offset> screenCorners,
    required final List<Offset> screenEdgeMidpoints,
  }) {
    return <Widget>[
      _buildEdgeDragZone(
        edgeIndex: TransformModel.topEdgeIndex,
        segmentStart: screenCorners[TransformModel.topLeftIndex],
        segmentEnd: screenEdgeMidpoints[TransformModel.topEdgeIndex],
      ),
      _buildEdgeDragZone(
        edgeIndex: TransformModel.topEdgeIndex,
        segmentStart: screenEdgeMidpoints[TransformModel.topEdgeIndex],
        segmentEnd: screenCorners[TransformModel.topRightIndex],
      ),
      _buildEdgeDragZone(
        edgeIndex: TransformModel.rightEdgeIndex,
        segmentStart: screenCorners[TransformModel.topRightIndex],
        segmentEnd: screenEdgeMidpoints[TransformModel.rightEdgeIndex],
      ),
      _buildEdgeDragZone(
        edgeIndex: TransformModel.rightEdgeIndex,
        segmentStart: screenEdgeMidpoints[TransformModel.rightEdgeIndex],
        segmentEnd: screenCorners[TransformModel.bottomRightIndex],
      ),
      _buildEdgeDragZone(
        edgeIndex: TransformModel.bottomEdgeIndex,
        segmentStart: screenCorners[TransformModel.bottomRightIndex],
        segmentEnd: screenEdgeMidpoints[TransformModel.bottomEdgeIndex],
      ),
      _buildEdgeDragZone(
        edgeIndex: TransformModel.bottomEdgeIndex,
        segmentStart: screenEdgeMidpoints[TransformModel.bottomEdgeIndex],
        segmentEnd: screenCorners[TransformModel.bottomLeftIndex],
      ),
      _buildEdgeDragZone(
        edgeIndex: TransformModel.leftEdgeIndex,
        segmentStart: screenCorners[TransformModel.bottomLeftIndex],
        segmentEnd: screenEdgeMidpoints[TransformModel.leftEdgeIndex],
      ),
      _buildEdgeDragZone(
        edgeIndex: TransformModel.leftEdgeIndex,
        segmentStart: screenEdgeMidpoints[TransformModel.leftEdgeIndex],
        segmentEnd: screenCorners[TransformModel.topLeftIndex],
      ),
    ];
  }

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
                child: const AppSvgIcon(icon: AppIcon.openInFull, size: AppLayout.iconSize, color: AppColors.white),
              ),
              buildOverlayCircleButton(
                tooltip: l10n.resizeRotate,
                color: AppColors.green,
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
                child: const AppSvgIcon(icon: AppIcon.rotateRight, size: AppLayout.iconSize, color: AppColors.white),
              ),
              buildOverlayCircleButton(
                tooltip: l10n.transform,
                color: AppColors.transformCornerHandle,
                cursor: SystemMouseCursors.click,
                onTap: () {
                  if (!model.isDeformMode) {
                    model.setDeformMode();
                  } else {
                    model.cycleHandleSet();
                  }
                  onChanged();
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
    required this.screenEdgeMidpoints,
    required this.screenBoundaryPoints,
  });

  final ui.Image image;
  final List<Offset> screenCorners;
  final List<Offset> screenEdgeMidpoints;
  final List<Offset> screenBoundaryPoints;

  @override
  void paint(final Canvas canvas, final Size size) {
    // Draw warped image
    drawPerspectiveImage(
      canvas,
      image,
      screenCorners,
      AppInteraction.transformGridSubdivisions,
      edgeMidpoints: screenEdgeMidpoints,
    );

    // Draw quad outline
    final Paint outlinePaint = Paint()
      ..color = AppColors.transformCornerHandle
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.regular;

    final Path outlinePath = Path()..moveTo(screenBoundaryPoints.first.dx, screenBoundaryPoints.first.dy);
    for (int i = 1; i < screenBoundaryPoints.length; i++) {
      outlinePath.lineTo(screenBoundaryPoints[i].dx, screenBoundaryPoints[i].dy);
    }
    outlinePath.close();

    canvas.drawPath(outlinePath, outlinePaint);
  }

  @override
  bool shouldRepaint(final _TransformPreviewPainter oldDelegate) => true;
}
