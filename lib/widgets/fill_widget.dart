import 'package:flutter/material.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/widgets/marching_ants_path.dart';

class FillWidget extends StatefulWidget {
  const FillWidget({
    super.key,
    required this.fillModel,
    required this.onDrag,
  });
  final FillModel fillModel;

  final void Function(GradientPoint) onDrag;

  @override
  State<FillWidget> createState() => _FillWidgetState();
}

const int defaultHandleSize = 20;

class _FillWidgetState extends State<FillWidget> {
  bool showCoordinate = false;

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
          point: gp,
          onPanUpdate: (final DragUpdateDetails details) {
            setState(() {
              gp.offset += details.delta;
              widget.onDrag(gp);
            });
          },
        ),
      );
    }

    // stackChildren.add(
    //   CustomPaint(
    //     painter: _LinePainter(points),
    //   ),
    // );

    return Stack(
      children: stackChildren,
    );
  }

  Widget _builFillKnob({
    required final GradientPoint point,
    required final void Function(DragUpdateDetails) onPanUpdate,
  }) {
    final int handleSize =
        (showCoordinate ? (defaultHandleSize * 1.5) : defaultHandleSize)
            .toInt();

    return Positioned(
      left: point.offset.dx - (handleSize / 2),
      top: point.offset.dy - (handleSize / 2),
      child: GestureDetector(
        onPanUpdate: (final DragUpdateDetails details) {
          setState(() {
            showCoordinate = true;
          });
          onPanUpdate(details);
        },
        onPanEnd: (final DragEndDetails details) =>
            setState(() => showCoordinate = false),
        child: MouseRegion(
          cursor: SystemMouseCursors.move,
          child: Container(
            width: handleSize.toDouble(),
            height: handleSize.toDouble(),
            decoration: BoxDecoration(
              color: point.color,
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}
