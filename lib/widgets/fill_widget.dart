import 'package:flutter/material.dart';
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

const int defaultHandleSize = AppInteraction.selectionHandleSize;

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

    for (int handleIndex = 0; handleIndex < widget.fillModel.gradientPoints.length; handleIndex++) {
      final GradientPoint gp = widget.fillModel.gradientPoints[handleIndex];
      stackChildren.add(
        _builFillKnob(
          key: Key('${Keys.gradientHandleKeyPrefixText}$handleIndex'),
          context: context,
          point: gp,
        ),
      );
    }

    // For linear gradients, show center dot at midpoint
    if (widget.fillModel.mode == FillMode.linear) {
      final Offset midPoint = widget.fillModel.centerPoint;
      final double centerDot = AppSpacing.sm;
      stackChildren.add(
        Positioned(
          left: midPoint.dx - (centerDot / AppMath.pair),
          top: midPoint.dy - (centerDot / AppMath.pair),
          child: Container(
            width: centerDot,
            height: centerDot,
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.rectangle,
              border: Border.all(color: Colors.white, width: AppStroke.thin),
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
    required final GradientPoint point,
  }) {
    final int handleSize = (showDetails ? (defaultHandleSize * AppVisual.previewTextScale) : defaultHandleSize).toInt();

    return Positioned(
      left: point.offset.dx - (handleSize / AppMath.pair),
      top: point.offset.dy - (handleSize / AppMath.pair),
      child: GestureDetector(
        key: key,
        onPanUpdate: (final DragUpdateDetails details) {
          setState(() {
            showDetails = true;
            point.offset += details.delta;
            widget.onUpdate(point);
          });
        },
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
          final AppLocalizations l10n = AppLocalizations.of(context)!;

          showColorPicker(
            context: context,
            title: l10n.gradientPointColor,
            color: point.color,
            onSelectedColor: (final Color color) {
              setState(() {
                point.color = color;
                widget.onUpdate(point);
              });
            },
          );
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.move,
          child: Container(
            width: handleSize.toDouble(),
            height: handleSize.toDouble(),
            decoration: BoxDecoration(
              color: point.color,
              border: Border.all(color: Colors.white, width: AppStroke.thin),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: AppStroke.thin),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
