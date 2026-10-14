import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/transform_helper.dart';
import 'package:fpaint/helpers/viewport_transform_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart' show AppIcon;
import 'package:fpaint/models/transform_model.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/overlay_control_widgets.dart';

/// An overlay widget that lets the user interactively skew and change
/// perspective of a selected region by dragging corner and edge handles.
class TransformWidget extends StatefulWidget {
  /// Creates a [TransformWidget].
  const TransformWidget({
    super.key,
    required this.model,
    required this.viewport,
    required this.onChanged,
    required this.onConfirm,
    required this.onCancel,
  });

  /// The current transform state.
  final TransformModel model;

  /// Called when the user cancels the transform.
  final VoidCallback onCancel;

  /// Called whenever the user drags a handle.
  final VoidCallback onChanged;

  /// Called when the user commits the transform.
  final VoidCallback onConfirm;

  /// The canvas-to-screen viewport transform (pan, zoom and rotation).
  final ViewportTransform viewport;
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
    required this.interactionProfile,
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

  /// Active interaction sizing profile.
  final InteractionLayoutProfile interactionProfile;

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
  Widget build(BuildContext context) {
    final Offset segmentDelta = segmentEnd - segmentStart;
    final double zoneThickness = max(
      interactionProfile.dragHandleSize,
      interactionProfile.edgeHandleSize * AppVisual.previewTextScale,
    );
    final double zoneLength = max(segmentDelta.distance, zoneThickness);
    final Offset zoneCenter = Offset(
      (segmentStart.dx + segmentEnd.dx) / AppMath.pair,
      (segmentStart.dy + segmentEnd.dy) / AppMath.pair,
    );
    final double zoneAngle = atan2(segmentDelta.dy, segmentDelta.dx);

    return centeredPositioned(
      center: zoneCenter,
      size: Size(zoneLength, zoneThickness),
      child: Transform.rotate(
        angle: zoneAngle,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (DragStartDetails _) => onDragStart?.call(),
          onPanUpdate: (DragUpdateDetails details) {
            onDragDelta(rotateOffset(details.delta, zoneAngle));
          },
          onPanEnd: (DragEndDetails _) => onDragEnd?.call(),
          onPanCancel: onDragCancel,
          child: MouseRegion(
            cursor: cursor,
            child: SizedBox(width: zoneLength, height: zoneThickness),
          ),
        ),
      ),
    );
  }
}

/// Number of mode buttons (translate, scale, rotate, deform) in the toolbar.
const int _transformModeButtonCount = AppMath.four;

/// Number of commit buttons (apply, cancel) in the toolbar.
const int _transformCommitButtonCount = AppMath.pair;

class _TransformWidgetState extends State<TransformWidget> with EscapeFocusMixin<TransformWidget> {
  @override
  Widget build(BuildContext context) {
    final ui.Image? image = model.sourceImage;
    if (image == null || model.corners.isEmpty) {
      return const SizedBox();
    }

    final AppLocalizations l10n = context.l10n;
    final ShellProvider? shellProvider = ShellProvider.maybeOf(context);
    final InteractionLayoutProfile interactionProfile =
        shellProvider?.interactionLayoutProfile ?? AppInteractionProfiles.mouse;

    // Convert corners to screen space
    final List<Offset> screenCorners = model.corners.map((Offset c) => _toScreen(c)).toList();
    final List<Offset> screenEdgeMidpoints = model.effectiveEdgeMidpoints.map((Offset c) => _toScreen(c)).toList();
    final List<Offset> screenBoundaryPoints = model.boundaryPoints.map((Offset c) => _toScreen(c)).toList();
    final bool areCornerHandlesEnabled = model.areCornerHandlesEnabled;
    final bool areEdgeHandlesEnabled = model.areEdgeHandlesEnabled;
    final bool areEdgeDragZonesEnabled = areCornerHandlesEnabled || areEdgeHandlesEnabled;
    final bool isCenterHandleEnabled = model.isCenterHandleEnabled;

    final Offset screenCenter = _toScreen(model.center);

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
                  interactionProfile: interactionProfile,
                  screenCorners: screenCorners,
                  screenEdgeMidpoints: screenEdgeMidpoints,
                ),

              if (areCornerHandlesEnabled)
                for (int index = 0; index < TransformModel.cornerCount; index++)
                  _buildCornerHandle(index, screenCorners, interactionProfile),

              if (areEdgeHandlesEnabled)
                for (int edgeIndex = 0; edgeIndex < TransformModel.edgeHandleCount; edgeIndex++)
                  _buildEdgeHandle(
                    edgeIndex,
                    _toScreen(
                      model.edgeMidpoint(edgeIndex, (edgeIndex + AppMath.one) % TransformModel.cornerCount),
                    ),
                    interactionProfile,
                  ),

              if (isCenterHandleEnabled) _buildCenterHandle(screenCenter, interactionProfile),
            ],

            _buildModeControls(
              interactionProfile: interactionProfile,
              l10n: l10n,
              screenCenter: screenCenter,
              screenCorners: screenBoundaryPoints,
            ),
          ],
        ),
      ),
    );
  }

  /// The canvas zoom scale factor.

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

  /// The canvas translation offset in screen coordinates.
  ViewportTransform get viewport => widget.viewport;

  /// Builds the centre move handle at [screenCenter].
  Widget _buildCenterHandle(
    Offset screenCenter,
    InteractionLayoutProfile interactionProfile,
  ) {
    return _buildTransformHandle(
      isActive: model.isCenterActive,
      position: screenCenter,
      cursor: SystemMouseCursors.move,
      interactionProfile: interactionProfile,
      onStart: model.setActiveCenter,
      onCanvasDelta: model.moveAll,
    );
  }

  /// Builds a corner perspective-drag handle for [index].
  Widget _buildCornerHandle(
    int index,
    List<Offset> screenCorners,
    InteractionLayoutProfile interactionProfile,
  ) {
    return _buildTransformHandle(
      isActive: model.isCornerActive(index),
      position: screenCorners[index],
      cursor: SystemMouseCursors.grab,
      interactionProfile: interactionProfile,
      onStart: () => model.setActiveCorner(index),
      onCanvasDelta: (Offset canvasDelta) => model.moveCorner(index, canvasDelta),
    );
  }

  /// Builds one invisible drag target for a single edge segment.
  Widget _buildEdgeDragZone({
    required int edgeIndex,
    required InteractionLayoutProfile interactionProfile,
    required Offset segmentStart,
    required Offset segmentEnd,
  }) {
    return TransformEdgeDragZone(
      edgeIndex: edgeIndex,
      cursor: SystemMouseCursors.grab,
      interactionProfile: interactionProfile,
      onDragStart: () {
        model.setActiveEdgeLine(edgeIndex);
        onChanged();
      },
      onDragDelta: (Offset delta) {
        model.moveConnectedEdge(edgeIndex, viewport.deltaToCanvas(delta));
        onChanged();
      },
      onDragEnd: _endHandleDrag,
      onDragCancel: _endHandleDrag,
      segmentStart: segmentStart,
      segmentEnd: segmentEnd,
    );
  }

  /// Builds drag targets along each visible edge segment of the transform mesh.
  ///
  /// Each edge runs corner -> midpoint -> next corner (clockwise from the top
  /// edge), and gets one drag zone per half-segment.
  List<Widget> _buildEdgeDragZones({
    required InteractionLayoutProfile interactionProfile,
    required List<Offset> screenCorners,
    required List<Offset> screenEdgeMidpoints,
  }) {
    return <Widget>[
      for (int edgeIndex = 0; edgeIndex < TransformModel.edgeHandleCount; edgeIndex++) ...<Widget>[
        _buildEdgeDragZone(
          edgeIndex: edgeIndex,
          interactionProfile: interactionProfile,
          segmentStart: screenCorners[edgeIndex],
          segmentEnd: screenEdgeMidpoints[edgeIndex],
        ),
        _buildEdgeDragZone(
          edgeIndex: edgeIndex,
          interactionProfile: interactionProfile,
          segmentStart: screenEdgeMidpoints[edgeIndex],
          segmentEnd: screenCorners[(edgeIndex + AppMath.one) % TransformModel.cornerCount],
        ),
      ],
    ];
  }

  /// Builds an edge midpoint skew-drag handle for [edgeIndex] at [position].
  Widget _buildEdgeHandle(
    int edgeIndex,
    Offset position,
    InteractionLayoutProfile interactionProfile,
  ) {
    return _buildTransformHandle(
      isActive: model.isEdgeActive(edgeIndex),
      position: position,
      cursor: SystemMouseCursors.grab,
      interactionProfile: interactionProfile,
      onStart: () => model.setActiveEdgeHandle(edgeIndex),
      onCanvasDelta: (Offset canvasDelta) => model.moveEdgeHandle(edgeIndex, canvasDelta),
    );
  }

  /// Builds the transform mode controls, confirm/cancel buttons, and feedback bubble.
  /// Groups all controls together at the top of the selection to avoid overlap with handles.
  Widget _buildModeControls({
    required InteractionLayoutProfile interactionProfile,
    required AppLocalizations l10n,
    required Offset screenCenter,
    required List<Offset> screenCorners,
  }) {
    final double buttonSize = interactionProfile.buttonSize;
    final double spacing = interactionProfile.buttonSpacing;
    final double modeButtonsWidth = overlayControlGroupContentWidth(
      buttonSize: buttonSize,
      spacing: spacing,
      buttonCount: _transformModeButtonCount,
    );
    final double confirmCancelWidth = overlayControlGroupContentWidth(
      buttonSize: buttonSize,
      spacing: spacing,
      buttonCount: _transformCommitButtonCount,
    );
    final double totalWidth = modeButtonsWidth + spacing + confirmCancelWidth; // All buttons with inter-group spacing
    final double viewportHeight = MediaQuery.sizeOf(context).height;

    final double idealControlsTop =
        _screenQuadY(screenCorners, min) - buttonSize - AppInteraction.imagePlacementHandleSize;
    final double bottomControlsTop = _screenQuadY(screenCorners, max) + AppInteraction.imagePlacementHandleSize;
    final OverlayPlacement placement = computeOverlayPlacement(
      viewportHeight: viewportHeight,
      idealTop: idealControlsTop,
      bottomTop: bottomControlsTop,
      isFeedbackVisible: model.isFeedbackVisible,
    );
    final double controlsLeft = screenCenter.dx - totalWidth / AppMath.pair;

    Offset handleCenter(int buttonIndex) => overlayModeHandleCenter(
      rowLeft: controlsLeft,
      rowTop: placement.controlsTop,
      buttonSize: buttonSize,
      spacing: spacing,
      buttonIndex: buttonIndex,
    );
    final Offset translateHandleCenter = handleCenter(overlayTranslateButtonIndex);
    final Offset scaleHandleCenter = handleCenter(overlayScaleButtonIndex);
    final Offset rotationHandleCenter = handleCenter(overlayRotateButtonIndex);

    final Widget feedbackBubble = buildOverlayFeedbackBubble(
      label: model.isScaleFeedbackVisible
          ? l10n.percentageValue(model.activeScalePercent.round())
          : l10n.degreesValue(model.activeRotationDegrees.round()),
    );
    final Widget modeButtons = buildOverlayControlSurface(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: spacing,
        children: <Widget>[
          buildOverlayModeButton(
            tooltip: l10n.translate,
            icon: AppIcon.move,
            size: buttonSize,
            iconSize: interactionProfile.iconSize,
            isSelected: model.isTranslateMode,
            cursor: SystemMouseCursors.move,
            onTap: () {
              if (!model.isTranslateMode) {
                model.setTranslateMode();
                onChanged();
              }
            },
            onPanStart: (DragStartDetails _) {
              if (!model.isTranslateMode) {
                model.setTranslateMode();
                onChanged();
              }
            },
            onPanUpdate: (DragUpdateDetails details) {
              if (!model.isTranslateMode) {
                model.setTranslateMode();
              }
              final Offset pointer = translateHandleCenter + details.delta;
              model.moveAll(viewport.deltaToCanvas(pointer - translateHandleCenter));
              onChanged();
            },
          ),
          buildOverlayModeButton(
            tooltip: l10n.scale,
            icon: AppIcon.openInFull,
            size: buttonSize,
            iconSize: interactionProfile.iconSize,
            isSelected: model.isScaleMode,
            cursor: SystemMouseCursors.grab,
            onTap: () {
              if (!model.isScaleMode) {
                model.setScaleMode();
                onChanged();
              }
            },
            onPanStart: (DragStartDetails _) {
              model.beginScaleGesture();
              onChanged();
            },
            onPanUpdate: (DragUpdateDetails details) {
              if (!model.isScaleMode || !model.isScaleFeedbackVisible) {
                model.beginScaleGesture();
              }

              final double? factor = scaleFactorForHandleDrag(
                handleCenter: scaleHandleCenter,
                pivot: screenCenter,
                dragDelta: details.delta,
              );
              if (factor == null) {
                return;
              }

              model.scaleUniform(factor);
              onChanged();
            },
            onPanEnd: (DragEndDetails _) {
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
            size: buttonSize,
            iconSize: interactionProfile.iconSize,
            isSelected: model.isRotateMode,
            cursor: SystemMouseCursors.grab,
            onTap: () {
              if (!model.isRotateMode) {
                model.setRotateMode();
                onChanged();
              }
            },
            onPanStart: (DragStartDetails _) {
              model.beginRotateGesture();
              onChanged();
            },
            onPanUpdate: (DragUpdateDetails details) {
              if (!model.isRotateMode || !model.isRotationFeedbackVisible) {
                model.beginRotateGesture();
              }
              final double angleDelta = angleDeltaForHandleDrag(
                handleCenter: rotationHandleCenter,
                pivot: screenCenter,
                dragDelta: details.delta,
              );
              model.rotate(angleDelta);
              model.updateRotationFeedback(angleDelta);
              onChanged();
            },
            onPanEnd: (DragEndDetails _) {
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
            size: buttonSize,
            iconSize: interactionProfile.iconSize,
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
        ],
      ),
    );
    final Widget commitButtons = buildOverlayControlSurface(
      child: buildOverlayConfirmCancelButtons(
        l10n: l10n,
        buttonSize: buttonSize,
        spacing: spacing,
        iconSize: interactionProfile.iconSize,
        onConfirm: onConfirm,
        onCancel: onCancel,
      ),
    );
    return buildPositionedOverlayControls(
      left: controlsLeft,
      placement: placement,
      spacing: spacing,
      controlGroups: <Widget>[modeButtons, commitButtons],
      isFeedbackVisible: model.isFeedbackVisible,
      feedbackBubble: feedbackBubble,
    );
  }

  /// Builds one transform drag handle.
  ///
  /// [onStart] marks the control active, [onCanvasDelta] receives every drag
  /// delta already converted to canvas space, and end/cancel clear the active
  /// control. Every step notifies [onChanged].
  Widget _buildTransformHandle({
    required bool isActive,
    required Offset position,
    required MouseCursor cursor,
    required InteractionLayoutProfile interactionProfile,
    required VoidCallback onStart,
    required ValueChanged<Offset> onCanvasDelta,
  }) {
    return OverlayDragHandle(
      backgroundColor: isActive ? AppColors.selected : AppColors.overlayDark,
      borderColor: AppColors.overlayLight,
      position: position,
      size: interactionProfile.dragHandleSize,
      cursor: cursor,
      onPanStart: (DragStartDetails _) {
        onStart();
        onChanged();
      },
      onPanUpdate: (DragUpdateDetails details) {
        onCanvasDelta(viewport.deltaToCanvas(details.delta));
        onChanged();
      },
      onPanEnd: _endHandleDrag,
      onPanCancel: _endHandleDrag,
    );
  }

  /// Clears the active handle/edge highlight when a drag ends or is canceled.
  void _endHandleDrag() {
    model.clearActiveControl();
    onChanged();
  }

  /// Returns the on-screen Y values of [screenCorners] reduced by [combine]
  /// ([min] for the quad's top edge, [max] for its bottom edge).
  double _screenQuadY(List<Offset> screenCorners, double Function(double, double) combine) {
    return screenCorners.map((Offset corner) => corner.dy).reduce(combine);
  }

  Offset _toScreen(Offset canvasPoint) => viewport.toScreen(canvasPoint);
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

  /// Boundary points contributed by each edge: its start corner and midpoint.
  static const int _boundaryPointsPerEdge = AppMath.pair;

  /// Total boundary points around the quad (corners interleaved with midpoints).
  static const int _boundaryPointCount = TransformModel.edgeHandleCount * _boundaryPointsPerEdge;

  @override
  void paint(Canvas canvas, Size size) {
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

    _drawTwoToneStroke(canvas, outlinePath, AppColors.overlayDark);

    if (activeEdgeIndex != null) {
      _drawTwoToneStroke(canvas, _edgePath(activeEdgeIndex!), AppColors.selected);
    }
  }

  /// Strokes [path] with a light double-width halo under a [centerColor] line
  /// so it stays readable on any background.
  void _drawTwoToneStroke(Canvas canvas, Path path, Color centerColor) {
    final Paint borderPaint = Paint()
      ..color = AppColors.overlayLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.regular * AppMath.pair;
    final Paint centerPaint = Paint()
      ..color = centerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.regular;
    canvas.drawPath(path, borderPaint);
    canvas.drawPath(path, centerPaint);
  }

  /// Returns the polyline segment for one highlighted boundary edge.
  ///
  /// Each transform edge uses three consecutive boundary points:
  /// corner -> midpoint -> next corner (wrapping back to the first point).
  Path _edgePath(int edgeIndex) {
    final Path edgePath = Path();
    if (edgeIndex < 0 ||
        edgeIndex >= TransformModel.edgeHandleCount ||
        screenBoundaryPoints.length != _boundaryPointCount) {
      return edgePath;
    }
    final int startIndex = edgeIndex * _boundaryPointsPerEdge;
    final Offset start = screenBoundaryPoints[startIndex];
    final Offset middle = screenBoundaryPoints[startIndex + AppMath.one];
    final Offset end = screenBoundaryPoints[(startIndex + _boundaryPointsPerEdge) % _boundaryPointCount];
    return edgePath
      ..moveTo(start.dx, start.dy)
      ..lineTo(middle.dx, middle.dy)
      ..lineTo(end.dx, end.dy);
  }

  @override
  bool shouldRepaint(_TransformPreviewPainter oldDelegate) {
    // Regenerating the perspective mesh is expensive; only repaint when the
    // transform geometry, highlighted edge, or source image actually changes.
    return oldDelegate.activeEdgeIndex != activeEdgeIndex ||
        !identical(oldDelegate.image, image) ||
        !listEquals(oldDelegate.screenCorners, screenCorners) ||
        !listEquals(oldDelegate.screenEdgeMidpoints, screenEdgeMidpoints) ||
        !listEquals(oldDelegate.screenBoundaryPoints, screenBoundaryPoints);
  }
}
