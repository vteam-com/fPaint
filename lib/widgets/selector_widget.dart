import 'package:flutter/material.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/widgets/marching_ants_rect.dart';

class SelectionHandleWidget extends StatefulWidget {
  const SelectionHandleWidget({
    super.key,
    required this.path,
    required this.onDrag,
    required this.onResize,
    this.enableMoveAndResize = true,
  });
  final Path path;
  final bool enableMoveAndResize;
  final Function(Offset) onDrag;
  final Function(NineGridHandle, Offset) onResize;

  @override
  State<SelectionHandleWidget> createState() => _SelectionHandleWidgetState();
}

const defaultHandleSize = 20;

class _SelectionHandleWidgetState extends State<SelectionHandleWidget> {
  bool showCoordinate = false;

  @override
  Widget build(BuildContext context) {
    final bounds = widget.path.getBounds();
    final width = bounds.left + bounds.width + defaultHandleSize;

    final height = bounds.bottom + bounds.height + defaultHandleSize;

    List<Widget> stackChildren = [
      MarchingAntsSelection(path: widget.path),
    ];

    if (widget.enableMoveAndResize) {
      stackChildren.addAll([
        // Center handle for moving
        _buildHandle(
          position: bounds.center,
          cursor: SystemMouseCursors.move,
          onPanUpdate: (details) => widget.onDrag(
            details.delta,
          ),
        ),

        // Top Left
        _buildHandle(
          position: bounds.topLeft,
          cursor: SystemMouseCursors.resizeUpLeft,
          onPanUpdate: (details) => widget.onResize(
            NineGridHandle.topLeft,
            details.delta,
          ),
        ),

        // Top Right
        _buildHandle(
          position: bounds.topRight,
          cursor: SystemMouseCursors.resizeUpRight,
          onPanUpdate: (details) => widget.onResize(
            NineGridHandle.topRight,
            details.delta,
          ),
        ),

        // Bottom Left
        _buildHandle(
          position: bounds.bottomLeft,
          cursor: SystemMouseCursors.resizeDownLeft,
          onPanUpdate: (details) => widget.onResize(
            NineGridHandle.bottomLeft,
            details.delta,
          ),
        ),

        // Bottom right
        _buildHandle(
          position: bounds.bottomRight,
          cursor: SystemMouseCursors.resizeDownRight,
          onPanUpdate: (details) => widget.onResize(
            NineGridHandle.bottomRight,
            details.delta,
          ),
        ),

        // Side Left
        _buildHandle(
          position: Offset(
            bounds.left,
            bounds.center.dy,
          ),
          cursor: SystemMouseCursors.resizeLeft,
          onPanUpdate: (details) => widget.onResize(
            NineGridHandle.left,
            details.delta,
          ),
        ),

        // Side Right
        _buildHandle(
          position: Offset(
            bounds.right,
            bounds.center.dy,
          ),
          cursor: SystemMouseCursors.resizeRight,
          onPanUpdate: (details) => widget.onResize(
            NineGridHandle.right,
            details.delta,
          ),
        ),

        // Center Top
        _buildHandle(
          position: Offset(
            bounds.center.dx,
            bounds.top,
          ),
          cursor: SystemMouseCursors.resizeUp,
          onPanUpdate: (details) => widget.onResize(
            NineGridHandle.top,
            details.delta,
          ),
        ),

        // Center Bottom
        _buildHandle(
          position: Offset(
            bounds.center.dx,
            bounds.bottom,
          ),
          cursor: SystemMouseCursors.resizeDown,
          onPanUpdate: (details) => widget.onResize(
            NineGridHandle.bottom,
            details.delta,
          ),
        ),
      ]);
    }

    return SizedBox(
      width: width < 0 ? 0 : width,
      height: height < 0 ? 0 : height,
      child: Stack(children: stackChildren),
    );
  }

  Widget _buildHandle({
    required Offset position,
    required MouseCursor cursor,
    required Function(DragUpdateDetails) onPanUpdate,
  }) {
    final int handleSize =
        (showCoordinate ? (defaultHandleSize * 1.5) : defaultHandleSize)
            .toInt();

    return Positioned(
      left: position.dx - (handleSize / 2),
      top: position.dy - (handleSize / 2),
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            showCoordinate = true;
          });
          onPanUpdate(details);
        },
        onPanEnd: (details) => setState(() => showCoordinate = false),
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
            child: showCoordinate
                ? Center(
                    child: Text(
                      '${position.dx.toInt()}\n${position.dy.toInt()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 8, color: Colors.white),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
