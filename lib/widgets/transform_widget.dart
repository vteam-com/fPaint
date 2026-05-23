import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/transform_helper.dart';
import 'package:fpaint/models/app_icon_enum.dart' show AppIcon;
import 'package:fpaint/models/transform_model.dart';
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
    this.onDragStart,
    required this.onDragDelta,
    this.onDragEnd,
    this.onDragCancel,
    required this.segmentStart,
    required this.segmentEnd,
  });

  /// Mouse cursor shown when hovering.
  final MouseCursor cursor;

  /// The logical transform edge this zone belongs to.
  final int edgeIndex;

  /// Called when the drag is canceled.
  final VoidCallback? onDragCancel;

  /// Called on every drag update with the delta converted to screen space.
  final ValueChanged<Offset> onDragDelta;

  /// Called when the drag ends.
  final VoidCallback? onDragEnd;

  /// Called when the drag starts.
  final VoidCallback? onDragStart;

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
          onPanStart: (final DragStartDetails _) => onDragStart?.call(),
          onPanUpdate: (final DragUpdateDetails details) {
            onDragDelta(_toScreenDelta(details.delta, zoneAngle));
          },
          onPanEnd: (final DragEndDetails _) => onDragEnd?.call(),
          onPanCancel: onDragCancel,
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

class _TransformWidgetState extends State<TransformWidget> with EscapeFocusMixin<TransformWidget> {
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

    return wrapWithEscapeFocus(
      child: SizedBox.expand(
        child: Stack(
          children: <Widget>[
            // Warped image preview + outline
            IgnorePointer(
              child: CustomPaint(
                size: Size.infinite,
                painter: _TransformPreviewPainter(
                  activeEdgeIndex: model.activeEdgeIndex,
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
                _buildCornerHandle(TransformModel.topLeftIndex, screenCorners),
                _buildCornerHandle(TransformModel.topRightIndex, screenCorners),
                _buildCornerHandle(TransformModel.bottomRightIndex, screenCorners),
                _buildCornerHandle(TransformModel.bottomLeftIndex, screenCorners),
              ],

              if (areEdgeHandlesEnabled) ...<Widget>[
                _buildEdgeHandle(TransformModel.topEdgeIndex, topMid),
                _buildEdgeHandle(TransformModel.rightEdgeIndex, rightMid),
                _buildEdgeHandle(TransformModel.bottomEdgeIndex, bottomMid),
                _buildEdgeHandle(TransformModel.leftEdgeIndex, leftMid),
              ],

              if (isCenterHandleEnabled) _buildCenterHandle(screenCenter),
            ],

            _buildModeControls(
              l10n: l10n,
              screenCenter: screenCenter,
              screenCorners: screenBoundaryPoints,
            ),
          ],
        ),
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
  @override
  void onEscapePressed() => onCancel();

  /// Builds the centre move handle at [screenCenter].
  Widget _buildCenterHandle(final Offset screenCenter) {
    return OverlayDragHandle(
      backgroundColor: model.isCenterActive ? AppColors.selected : AppColors.overlayDark,
      borderColor: AppColors.overlayLight,
      position: screenCenter,
      cursor: SystemMouseCursors.move,
      onPanStart: (final DragStartDetails _) {
        model.setActiveCenter();
        onChanged();
      },
      onPanUpdate: (final DragUpdateDetails details) {
        model.moveAll(details.delta / canvasScale);
        onChanged();
      },
      onPanEnd: () {
        model.clearActiveControl();
        onChanged();
      },
      onPanCancel: () {
        model.clearActiveControl();
        onChanged();
      },
    );
  }

  /// Builds a corner perspective-drag handle for [index].
  Widget _buildCornerHandle(final int index, final List<Offset> screenCorners) {
    return OverlayDragHandle(
      backgroundColor: model.isCornerActive(index) ? AppColors.selected : AppColors.overlayDark,
      borderColor: AppColors.overlayLight,
      position: screenCorners[index],
      cursor: SystemMouseCursors.grab,
      onPanStart: (final DragStartDetails _) {
        model.setActiveCorner(index);
        onChanged();
      },
      onPanUpdate: (final DragUpdateDetails details) {
        model.moveCorner(index, details.delta / canvasScale);
        onChanged();
      },
      onPanEnd: () {
        model.clearActiveControl();
        onChanged();
      },
      onPanCancel: () {
        model.clearActiveControl();
        onChanged();
      },
    );
  }

  /// Builds one invisible drag target for a single edge segment.
  Widget _buildEdgeDragZone({
    required final int edgeIndex,
    required final Offset segmentStart,
    required final Offset segmentEnd,
  }) {
    return TransformEdgeDragZone(
      edgeIndex: edgeIndex,
      cursor: SystemMouseCursors.grab,
      onDragStart: () {
        model.setActiveEdgeLine(edgeIndex);
        onChanged();
      },
      onDragDelta: (final Offset delta) {
        model.moveConnectedEdge(edgeIndex, delta / canvasScale);
        onChanged();
      },
      onDragEnd: () {
        model.clearActiveControl();
        onChanged();
      },
      onDragCancel: () {
        model.clearActiveControl();
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

  /// Builds an edge midpoint skew-drag handle for [edgeIndex] at [position].
  Widget _buildEdgeHandle(final int edgeIndex, final Offset position) {
    return OverlayDragHandle(
      backgroundColor: model.isEdgeActive(edgeIndex) ? AppColors.selected : AppColors.overlayDark,
      borderColor: AppColors.overlayLight,
      position: position,
      cursor: SystemMouseCursors.grab,
      onPanStart: (final DragStartDetails _) {
        model.setActiveEdgeHandle(edgeIndex);
        onChanged();
      },
      onPanUpdate: (final DragUpdateDetails details) {
        model.moveEdgeHandle(edgeIndex, details.delta / canvasScale);
        onChanged();
      },
      onPanEnd: () {
        model.clearActiveControl();
        onChanged();
      },
      onPanCancel: () {
        model.clearActiveControl();
        onChanged();
      },
    );
  }

  /// Builds the transform mode controls, confirm/cancel buttons, and feedback bubble.
  /// Groups all controls together at the top of the selection to avoid overlap with handles.
  Widget _buildModeControls({
    required final AppLocalizations l10n,
    required final Offset screenCenter,
    required final List<Offset> screenCorners,
  }) {
    const double buttonSize = AppInteraction.imagePlacementButtonSize;
    const double spacing = AppInteraction.imagePlacementButtonSpacing;
    const double modeButtonsWidth = buttonSize * AppMath.four + spacing * AppMath.triple; // 4 mode buttons
    const double confirmCancelWidth = buttonSize * AppMath.pair + spacing; // 2 confirm/cancel buttons
    const double totalWidth = modeButtonsWidth + spacing + confirmCancelWidth; // All buttons with inter-group spacing
    final double viewportHeight = MediaQuery.sizeOf(context).height;

    final double idealControlsTop =
        _screenQuadTop(screenCorners) - buttonSize - AppInteraction.imagePlacementHandleSize;
    final double bottomControlsTop = _screenQuadBottom(screenCorners) + AppInteraction.imagePlacementHandleSize;
    final OverlayPlacement placement = computeOverlayPlacement(
      viewportHeight: viewportHeight,
      idealTop: idealControlsTop,
      bottomTop: bottomControlsTop,
      isFeedbackVisible: model.isFeedbackVisible,
    );
    final double controlsLeft = screenCenter.dx - totalWidth / AppMath.pair;

    final Offset translateHandleCenter = Offset(
      controlsLeft + buttonSize / AppMath.pair,
      placement.controlsTop + buttonSize / AppMath.pair,
    );
    final Offset scaleHandleCenter = Offset(
      controlsLeft + buttonSize + spacing + buttonSize / AppMath.pair,
      placement.controlsTop + buttonSize / AppMath.pair,
    );
    final Offset rotationHandleCenter = Offset(
      controlsLeft + (buttonSize + spacing) * AppMath.pair + buttonSize / AppMath.pair,
      placement.controlsTop + buttonSize / AppMath.pair,
    );

    final Widget feedbackBubble = buildOverlayFeedbackBubble(
      label: model.isScaleFeedbackVisible
          ? l10n.percentageValue(model.activeScalePercent.round())
          : l10n.degreesValue(model.activeRotationDegrees.round()),
    );
    final Widget feedbackSpacer = const SizedBox(height: AppInteraction.imagePlacementButtonSpacing);
    final Widget buttonsRow = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: spacing,
      children: <Widget>[
        buildOverlayModeButton(
          tooltip: l10n.translate,
          icon: AppIcon.move,
          isSelected: model.isTranslateMode,
          cursor: SystemMouseCursors.move,
          onTap: () {
            if (!model.isTranslateMode) {
              model.setTranslateMode();
              onChanged();
            }
          },
          onPanStart: (final DragStartDetails _) {
            if (!model.isTranslateMode) {
              model.setTranslateMode();
              onChanged();
            }
          },
          onPanUpdate: (final DragUpdateDetails details) {
            if (!model.isTranslateMode) {
              model.setTranslateMode();
            }
            final Offset pointer = translateHandleCenter + details.delta;
            model.moveAll((pointer - translateHandleCenter) / canvasScale);
            onChanged();
          },
        ),
        buildOverlayModeButton(
          tooltip: l10n.scale,
          icon: AppIcon.openInFull,
          isSelected: model.isScaleMode,
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
        ),
        buildOverlayModeButton(
          tooltip: l10n.resizeRotate,
          icon: AppIcon.rotateRight,
          isSelected: model.isRotateMode,
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
        ),
        buildOverlayModeButton(
          tooltip: l10n.transform,
          icon: AppIcon.transform,
          isSelected: model.isDeformMode && !model.isCenterHandleEnabled,
          cursor: SystemMouseCursors.click,
          onTap: () {
            if (!model.isDeformMode) {
              model.setDeformMode();
            } else {
              model.cycleHandleSet();
            }
            onChanged();
          },
        ),
        buildOverlayConfirmCancelButtons(
          l10n: l10n,
          onConfirm: onConfirm,
          onCancel: onCancel,
        ),
      ],
    );

    return Positioned(
      left: controlsLeft,
      top: placement.positionedTop,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: placement.orderedColumnChildren(
          buttonsRow: buttonsRow,
          isFeedbackVisible: model.isFeedbackVisible,
          feedbackBubble: feedbackBubble,
          feedbackSpacer: feedbackSpacer,
        ),
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
    required this.activeEdgeIndex,
    required this.image,
    required this.screenCorners,
    required this.screenEdgeMidpoints,
    required this.screenBoundaryPoints,
  });

  final int? activeEdgeIndex;

  final ui.Image image;
  final List<Offset> screenCorners;
  final List<Offset> screenEdgeMidpoints;
  final List<Offset> screenBoundaryPoints;

  static const int _topLeftBoundaryPointIndex = AppMath.zero;
  static const int _topMidBoundaryPointIndex = AppMath.one;
  static const int _topRightBoundaryPointIndex = AppMath.two;
  static const int _rightMidBoundaryPointIndex = AppMath.triple;
  static const int _bottomRightBoundaryPointIndex = AppMath.four;
  static const int _bottomMidBoundaryPointIndex = AppMath.four + AppMath.one;
  static const int _bottomLeftBoundaryPointIndex = AppMath.six;
  static const int _leftMidBoundaryPointIndex = AppMath.six + AppMath.one;

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

    final Path outlinePath = Path()..moveTo(screenBoundaryPoints.first.dx, screenBoundaryPoints.first.dy);
    for (int i = 1; i < screenBoundaryPoints.length; i++) {
      outlinePath.lineTo(screenBoundaryPoints[i].dx, screenBoundaryPoints[i].dy);
    }
    outlinePath.close();

    final Paint outlineBorderPaint = Paint()
      ..color = AppColors.overlayLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.regular * AppMath.pair;
    final Paint outlineCenterPaint = Paint()
      ..color = AppColors.overlayDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.regular;

    canvas.drawPath(outlinePath, outlineBorderPaint);
    canvas.drawPath(outlinePath, outlineCenterPaint);

    if (activeEdgeIndex != null) {
      final Path activeEdgePath = _edgePath(activeEdgeIndex!);
      final Paint activeEdgeBorderPaint = Paint()
        ..color = AppColors.overlayLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppStroke.regular * AppMath.pair;
      final Paint activeEdgeCenterPaint = Paint()
        ..color = AppColors.selected
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppStroke.regular;
      canvas.drawPath(activeEdgePath, activeEdgeBorderPaint);
      canvas.drawPath(activeEdgePath, activeEdgeCenterPaint);
    }
  }

  /// Returns the polyline segment for one highlighted boundary edge.
  ///
  /// Each transform edge uses three boundary points: corner -> midpoint -> corner.
  Path _edgePath(final int edgeIndex) {
    final Path edgePath = Path();
    switch (edgeIndex) {
      case TransformModel.topEdgeIndex:
        edgePath
          ..moveTo(
            screenBoundaryPoints[_topLeftBoundaryPointIndex].dx,
            screenBoundaryPoints[_topLeftBoundaryPointIndex].dy,
          )
          ..lineTo(
            screenBoundaryPoints[_topMidBoundaryPointIndex].dx,
            screenBoundaryPoints[_topMidBoundaryPointIndex].dy,
          )
          ..lineTo(
            screenBoundaryPoints[_topRightBoundaryPointIndex].dx,
            screenBoundaryPoints[_topRightBoundaryPointIndex].dy,
          );
      case TransformModel.rightEdgeIndex:
        edgePath
          ..moveTo(
            screenBoundaryPoints[_topRightBoundaryPointIndex].dx,
            screenBoundaryPoints[_topRightBoundaryPointIndex].dy,
          )
          ..lineTo(
            screenBoundaryPoints[_rightMidBoundaryPointIndex].dx,
            screenBoundaryPoints[_rightMidBoundaryPointIndex].dy,
          )
          ..lineTo(
            screenBoundaryPoints[_bottomRightBoundaryPointIndex].dx,
            screenBoundaryPoints[_bottomRightBoundaryPointIndex].dy,
          );
      case TransformModel.bottomEdgeIndex:
        edgePath
          ..moveTo(
            screenBoundaryPoints[_bottomRightBoundaryPointIndex].dx,
            screenBoundaryPoints[_bottomRightBoundaryPointIndex].dy,
          )
          ..lineTo(
            screenBoundaryPoints[_bottomMidBoundaryPointIndex].dx,
            screenBoundaryPoints[_bottomMidBoundaryPointIndex].dy,
          )
          ..lineTo(
            screenBoundaryPoints[_bottomLeftBoundaryPointIndex].dx,
            screenBoundaryPoints[_bottomLeftBoundaryPointIndex].dy,
          );
      case TransformModel.leftEdgeIndex:
        edgePath
          ..moveTo(
            screenBoundaryPoints[_bottomLeftBoundaryPointIndex].dx,
            screenBoundaryPoints[_bottomLeftBoundaryPointIndex].dy,
          )
          ..lineTo(
            screenBoundaryPoints[_leftMidBoundaryPointIndex].dx,
            screenBoundaryPoints[_leftMidBoundaryPointIndex].dy,
          )
          ..lineTo(
            screenBoundaryPoints[_topLeftBoundaryPointIndex].dx,
            screenBoundaryPoints[_topLeftBoundaryPointIndex].dy,
          );
      default:
        edgePath.addPath(Path(), Offset.zero);
    }
    return edgePath;
  }

  @override
  bool shouldRepaint(final _TransformPreviewPainter oldDelegate) => true;
}
