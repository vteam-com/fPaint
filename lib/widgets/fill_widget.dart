import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';
import 'package:fpaint/widgets/marching_ants_path.dart';

/// A widget that displays the fill controls for a gradient or solid color fill.
class FillWidget extends StatefulWidget {
  /// Creates a [FillWidget].
  ///
  /// The [fillModel] parameter specifies the fill model to use.
  /// The [onUpdate] parameter is a callback that is called when a gradient point is updated.
  const FillWidget({
    super.key,
    required this.fillModel,
    required this.onUpdate,
  });

  /// The fill model to use.
  final FillModel fillModel;

  /// A callback that is called when a gradient point is updated.
  final void Function(GradientPoint) onUpdate;

  @override
  State<FillWidget> createState() => _FillWidgetState();
}

const double defaultHandleSize = AppInteraction.selectionHandleSize;

class _FillWidgetState extends State<FillWidget> {
  bool showDetails = false;

  @override
  Widget build(final BuildContext context) {
    final List<Widget> stackChildren = <Widget>[];

    // For radial gradients, show a circular marching ants path
    if (widget.fillModel.mode == FillMode.radial && widget.fillModel.gradientPoints.length >= AppMath.pair) {
      final Offset center = widget.fillModel.gradientPoints.first.offset;
      final Offset outerPoint = widget.fillModel.gradientPoints.last.offset;
      final double radius = (outerPoint - center).distance;

      final Path circlePath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));

      stackChildren.add(
        AnimatedMarchingAntsPath(
          path: circlePath,
        ),
      );
    } else {
      // For linear gradients, show linear marching ants
      stackChildren.add(
        AnimatedMarchingAntsPath(
          linePointStart: widget.fillModel.gradientPoints.first.offset,
          linePointEnd: widget.fillModel.gradientPoints.last.offset,
        ),
      );
    }

    final int stopCount = widget.fillModel.gradientStopColors.length;
    for (int stopIndex = 0; stopIndex < stopCount; stopIndex++) {
      final bool isStartHandle = stopIndex == 0;
      final bool isEndHandle = stopIndex == stopCount - 1;
      final bool isEndpointHandle = isStartHandle || isEndHandle;
      final GradientPoint? draggablePoint = isStartHandle
          ? widget.fillModel.gradientPoints.first
          : (isEndHandle ? widget.fillModel.gradientPoints.last : null);

      stackChildren.add(
        _builFillKnob(
          key: Key('${Keys.gradientHandleKeyPrefixText}$stopIndex'),
          context: context,
          handleIndex: stopIndex,
          handleCount: stopCount,
          color: widget.fillModel.gradientStopColors[stopIndex],
          point: draggablePoint,
          canDragEndpoint: isEndpointHandle,
        ),
      );
    }

    // For linear gradients, show center dot at midpoint
    if (widget.fillModel.mode == FillMode.linear) {
      final Offset midPoint = widget.fillModel.centerPoint;
      const double centerDot = AppSpacing.small;
      stackChildren.add(
        Positioned(
          left: midPoint.dx - (centerDot / AppMath.pair),
          top: midPoint.dy - (centerDot / AppMath.pair),
          child: Container(
            width: centerDot,
            height: centerDot,
            decoration: BoxDecoration(
              color: AppColors.black,
              shape: BoxShape.rectangle,
              border: Border.all(color: AppColors.white, width: AppStroke.thin),
              borderRadius: BorderRadius.circular(centerDot),
            ),
          ),
        ),
      );
    }
    // For radial gradients, the center is already clearly indicated by the first handle

    return Stack(
      children: stackChildren,
    );
  }

  /// Builds a fill knob for the given gradient point.
  Widget _builFillKnob({
    required final Key key,
    required final BuildContext context,
    required final Color color,
    required final int handleIndex,
    required final int handleCount,
    required final GradientPoint? point,
    required final bool canDragEndpoint,
  }) {
    final int handleSize = (showDetails ? (defaultHandleSize * AppVisual.previewTextScale) : defaultHandleSize).toInt();
    final Offset handleOffset = _handleOffsetForStop(
      stopIndex: handleIndex,
      stopCount: handleCount,
    );
    final bool isInnerHandle = handleIndex > 0 && handleIndex < handleCount - 1;

    return Positioned(
      left: handleOffset.dx - (handleSize / AppMath.pair),
      top: handleOffset.dy - (handleSize / AppMath.pair),
      child: GestureDetector(
        key: key,
        onPanUpdate: canDragEndpoint
            ? (final DragUpdateDetails details) {
                setState(() {
                  showDetails = true;
                  point!.offset += details.delta;
                  widget.onUpdate(point);
                });
              }
            : isInnerHandle
            ? (final DragUpdateDetails details) {
                _moveInnerHandleByDelta(
                  stopIndex: handleIndex,
                  delta: details.delta,
                );
              }
            : null,
        onPanEnd: (final DragEndDetails _) => setState(() => showDetails = false),
        onTapDown: (final TapDownDetails _) {
          setState(() {
            showDetails = true;
          });
        },
        onTapUp: (final TapUpDetails _) {
          setState(() {
            showDetails = false;
          });
        },
        onTapCancel: () {
          setState(() {
            showDetails = false;
          });
        },
        onLongPress: () {
          final AppLocalizations l10n = context.l10n;

          showColorPicker(
            context: context,
            title: l10n.gradientPointColor,
            color: color,
            onSelectedColor: (final Color selectedColor) {
              setState(() {
                // Sync the changed color back into gradientStopColors so the
                // side-panel editor reflects the pick made on the canvas handle.
                final List<Color> stops = widget.fillModel.gradientStopColors;
                if (stops.isNotEmpty) {
                  stops[handleIndex] = selectedColor;
                }

                // Keep endpoint handle colors in sync with the first/last stop
                // so dragging handles still displays the selected colors.
                if (canDragEndpoint && point != null) {
                  point.color = selectedColor;
                  widget.onUpdate(point);
                } else if (widget.fillModel.gradientPoints.isNotEmpty) {
                  widget.onUpdate(widget.fillModel.gradientPoints.first);
                }
              });
            },
          );
        },
        child: MouseRegion(
          cursor: canDragEndpoint || isInnerHandle ? SystemMouseCursors.move : SystemMouseCursors.click,
          child: Container(
            width: handleSize.toDouble(),
            height: handleSize.toDouble(),
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: AppColors.white, width: AppStroke.thin),
              borderRadius: BorderRadius.circular(AppRadius.large),
            ),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.black, width: AppStroke.thin),
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Computes the on-canvas position for a color-stop handle.
  ///
  /// For both linear and radial gradients, inner handles are placed according
  /// to [FillModel.gradientStopPositions].
  Offset _handleOffsetForStop({
    required final int stopIndex,
    required final int stopCount,
  }) {
    if (widget.fillModel.gradientPoints.length < AppMath.pair) {
      return Offset.zero;
    }

    final Offset startOffset = widget.fillModel.gradientPoints.first.offset;
    final Offset endOffset = widget.fillModel.gradientPoints.last.offset;

    if (stopIndex == 0) {
      return startOffset;
    }

    if (stopIndex == stopCount - 1) {
      return endOffset;
    }

    final List<double> positions = widget.fillModel.gradientStopPositions;
    final double ratio = stopIndex < positions.length
        ? positions[stopIndex].clamp(AppMath.zero.toDouble(), AppVisual.full)
        : stopIndex / (stopCount - 1);
    return Offset.lerp(startOffset, endOffset, ratio) ?? startOffset;
  }

  /// Moves an inner stop by projecting [delta] onto the gradient axis.
  void _moveInnerHandleByDelta({
    required final int stopIndex,
    required final Offset delta,
  }) {
    if (widget.fillModel.gradientPoints.length < AppMath.pair) {
      return;
    }
    final List<double> positions = widget.fillModel.gradientStopPositions;
    if (stopIndex <= 0 || stopIndex >= positions.length - 1) {
      return;
    }

    final Offset startOffset = widget.fillModel.gradientPoints.first.offset;
    final Offset endOffset = widget.fillModel.gradientPoints.last.offset;
    final Offset axis = endOffset - startOffset;
    final double axisLenSquared = (axis.dx * axis.dx) + (axis.dy * axis.dy);
    if (axisLenSquared <= 0) {
      return;
    }

    final double deltaProjected = ((delta.dx * axis.dx) + (delta.dy * axis.dy)) / axisLenSquared;
    final double lowerBound = positions[stopIndex - 1];
    final double upperBound = positions[stopIndex + 1];

    setState(() {
      showDetails = true;
      final double next = positions[stopIndex] + deltaProjected;
      positions[stopIndex] = next.clamp(lowerBound, upperBound);
      positions[0] = AppMath.zero.toDouble();
      positions[positions.length - 1] = AppVisual.full;
    });

    widget.onUpdate(widget.fillModel.gradientPoints.first);
  }
}
