import 'package:flutter/material.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/widgets/color_selector.dart';
import 'package:fpaint/widgets/marching_ants_path.dart';

class FillWidget extends StatefulWidget {
  const FillWidget({
    super.key,
    required this.fillModel,
    required this.onUpdate,
  });
  final FillModel fillModel;

  final void Function(GradientPoint) onUpdate;

  @override
  State<FillWidget> createState() => _FillWidgetState();
}

const int defaultHandleSize = 20;

class _FillWidgetState extends State<FillWidget> {
  bool showDetails = false;

  @override
  Widget build(final BuildContext context) {
    final List<Widget> stackChildren = <Widget>[];

    stackChildren.add(
      AnimatedMarchingAntsPath(
        linePointStart: widget.fillModel.gradientPoints.first.offset,
        linePointEnd: widget.fillModel.gradientPoints.last.offset,
      ),
    );

    for (final GradientPoint gp in widget.fillModel.gradientPoints) {
      stackChildren.add(
        _builFillKnob(
          context: context,
          point: gp,
        ),
      );
    }
    final Offset midPoint = widget.fillModel.centerPoint;
    final double centerDot = 8;
    stackChildren.add(
      Positioned(
        left: midPoint.dx - (centerDot / 2),
        top: midPoint.dy - (centerDot / 2),
        child: Container(
          width: centerDot,
          height: centerDot,
          decoration: BoxDecoration(
            color: Colors.black,
            shape: BoxShape.rectangle,
            border: Border.all(color: Colors.white, width: 1),
            borderRadius: BorderRadius.circular(centerDot),
          ),
        ),
      ),
    );

    return Stack(
      children: stackChildren,
    );
  }

  Widget _builFillKnob({
    required final BuildContext context,
    required final GradientPoint point,
  }) {
    final int handleSize =
        (showDetails ? (defaultHandleSize * 1.5) : defaultHandleSize).toInt();

    return Positioned(
      left: point.offset.dx - (handleSize / 2),
      top: point.offset.dy - (handleSize / 2),
      child: GestureDetector(
        onPanUpdate: (final DragUpdateDetails details) {
          setState(() {
            showDetails = true;
            point.offset += details.delta;
            widget.onUpdate(point);
          });
        },
        onPanEnd: (final DragEndDetails details) =>
            setState(() => showDetails = false),
        onTapDown: (final TapDownDetails details) {
          setState(() {
            showDetails = true;
          });
        },
        onTapUp: (final TapUpDetails details) {
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
          showColorPicker(
            context: context,
            title: 'Gradient Point Color',
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
              border: Border.all(color: Colors.white, width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
