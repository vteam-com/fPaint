import 'package:flutter/material.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/widgets/marching_ants_path.dart';

class FillWidget extends StatefulWidget {
  const FillWidget({
    super.key,
    required this.path1,
    required this.path2,
    required this.onDrag,
    required this.onResize,
  });
  final Path? path1;
  final Path? path2;

  final void Function(Offset) onDrag;
  final void Function(NineGridHandle, Offset) onResize;

  @override
  State<FillWidget> createState() => _FillWidgetState();
}

const int defaultHandleSize = 20;

class _FillWidgetState extends State<FillWidget> {
  bool showCoordinate = false;

  @override
  Widget build(final BuildContext context) {
    if (widget.path1 == null) {
      return const SizedBox();
    }
    final Rect bounds = widget.path1!.getBounds();
    final double width = bounds.left + bounds.width + defaultHandleSize;

    final double height = bounds.bottom + bounds.height + defaultHandleSize;

    final List<Widget> stackChildren = <Widget>[
      AnimatedMarchingAntsPath(path: widget.path1!),
      if (widget.path2 != null) AnimatedMarchingAntsPath(path: widget.path2!),
    ];

    stackChildren.addAll(<Widget>[
      // Center handle for moving
      _builFillKnob(
        position: bounds.center,
        cursor: SystemMouseCursors.move,
        onPanUpdate: (final DragUpdateDetails details) => widget.onDrag(
          details.delta,
        ),
      ),

      // Top Left
      _builFillKnob(
        position: bounds.topLeft,
        cursor: SystemMouseCursors.resizeUpLeft,
        onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
          NineGridHandle.topLeft,
          details.delta,
        ),
      ),

      // Top Right
      _builFillKnob(
        position: bounds.topRight,
        cursor: SystemMouseCursors.resizeUpRight,
        onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
          NineGridHandle.topRight,
          details.delta,
        ),
      ),

      // Bottom Left
      _builFillKnob(
        position: bounds.bottomLeft,
        cursor: SystemMouseCursors.resizeDownLeft,
        onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
          NineGridHandle.bottomLeft,
          details.delta,
        ),
      ),

      // Bottom right
      _builFillKnob(
        position: bounds.bottomRight,
        cursor: SystemMouseCursors.resizeDownRight,
        onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
          NineGridHandle.bottomRight,
          details.delta,
        ),
      ),

      // Side Left
      _builFillKnob(
        position: Offset(
          bounds.left,
          bounds.center.dy,
        ),
        cursor: SystemMouseCursors.resizeLeft,
        onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
          NineGridHandle.left,
          details.delta,
        ),
      ),

      // Side Right
      _builFillKnob(
        position: Offset(
          bounds.right,
          bounds.center.dy,
        ),
        cursor: SystemMouseCursors.resizeRight,
        onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
          NineGridHandle.right,
          details.delta,
        ),
      ),

      // Center Top
      _builFillKnob(
        position: Offset(
          bounds.center.dx,
          bounds.top,
        ),
        cursor: SystemMouseCursors.resizeUp,
        onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
          NineGridHandle.top,
          details.delta,
        ),
      ),

      // Center Bottom
      _builFillKnob(
        position: Offset(
          bounds.center.dx,
          bounds.bottom,
        ),
        cursor: SystemMouseCursors.resizeDown,
        onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
          NineGridHandle.bottom,
          details.delta,
        ),
      ),
    ]);

    return SizedBox(
      width: width < 0 ? 0 : width,
      height: height < 0 ? 0 : height,
      child: Stack(children: stackChildren),
    );
  }

  Widget _builFillKnob({
    required final Offset position,
    required final MouseCursor cursor,
    required final void Function(DragUpdateDetails) onPanUpdate,
  }) {
    final int handleSize =
        (showCoordinate ? (defaultHandleSize * 1.5) : defaultHandleSize)
            .toInt();

    return Positioned(
      left: position.dx - (handleSize / 2),
      top: position.dy - (handleSize / 2),
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
          cursor: cursor,
          child: Container(
            width: handleSize.toDouble(),
            height: handleSize.toDouble(),
            decoration: BoxDecoration(
              color: Colors.blue,
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}
