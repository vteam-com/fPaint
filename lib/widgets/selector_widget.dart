import 'package:flutter/material.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/widgets/marching_ants_rect.dart';

class SelectionHandleWidget extends StatefulWidget {
  const SelectionHandleWidget({
    super.key,
    required this.selectionRect,
    required this.onDrag,
    required this.onResize,
    this.enableMoveAndResize = true,
  });
  final Rect selectionRect;
  final bool enableMoveAndResize;
  final Function(Offset) onDrag;
  final Function(SelectorHandlePosition, Offset) onResize;

  @override
  State<SelectionHandleWidget> createState() => _SelectionHandleWidgetState();
}

const defaultHandleSize = 20;

class _SelectionHandleWidgetState extends State<SelectionHandleWidget> {
  bool showCoordinate = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.selectionRect.left +
          widget.selectionRect.width +
          defaultHandleSize,
      height: widget.selectionRect.bottom +
          widget.selectionRect.height +
          defaultHandleSize,
      child: widget.enableMoveAndResize
          ? Stack(
              children: [
                MarchingAntsSelection(rect: widget.selectionRect),

                // Center handle for moving
                _buildHandle(
                  position: widget.selectionRect.center,
                  cursor: SystemMouseCursors.move,
                  onPanUpdate: (details) => widget.onDrag(
                    details.delta,
                  ),
                ),

                // Top Left
                _buildHandle(
                  position: widget.selectionRect.topLeft,
                  cursor: SystemMouseCursors.resizeUpLeft,
                  onPanUpdate: (details) => widget.onResize(
                    SelectorHandlePosition.topLeft,
                    details.delta,
                  ),
                ),

                // Top Right
                _buildHandle(
                  position: widget.selectionRect.topRight,
                  cursor: SystemMouseCursors.resizeUpRight,
                  onPanUpdate: (details) => widget.onResize(
                    SelectorHandlePosition.topRight,
                    details.delta,
                  ),
                ),

                // Bottom Left
                _buildHandle(
                  position: widget.selectionRect.bottomLeft,
                  cursor: SystemMouseCursors.resizeDownLeft,
                  onPanUpdate: (details) => widget.onResize(
                    SelectorHandlePosition.bottomLeft,
                    details.delta,
                  ),
                ),

                // Bottom right
                _buildHandle(
                  position: widget.selectionRect.bottomRight,
                  cursor: SystemMouseCursors.resizeDownRight,
                  onPanUpdate: (details) => widget.onResize(
                    SelectorHandlePosition.bottomRight,
                    details.delta,
                  ),
                ),

                // Side Left
                _buildHandle(
                  position: Offset(
                    widget.selectionRect.left,
                    widget.selectionRect.center.dy,
                  ),
                  cursor: SystemMouseCursors.resizeLeft,
                  onPanUpdate: (details) => widget.onResize(
                    SelectorHandlePosition.left,
                    details.delta,
                  ),
                ),

                // Side Right
                _buildHandle(
                  position: Offset(
                    widget.selectionRect.right,
                    widget.selectionRect.center.dy,
                  ),
                  cursor: SystemMouseCursors.resizeRight,
                  onPanUpdate: (details) => widget.onResize(
                    SelectorHandlePosition.right,
                    details.delta,
                  ),
                ),

                // Center Top
                _buildHandle(
                  position: Offset(
                    widget.selectionRect.center.dx,
                    widget.selectionRect.top,
                  ),
                  cursor: SystemMouseCursors.resizeUp,
                  onPanUpdate: (details) => widget.onResize(
                    SelectorHandlePosition.top,
                    details.delta,
                  ),
                ),

                // Center Bottom
                _buildHandle(
                  position: Offset(
                    widget.selectionRect.center.dx,
                    widget.selectionRect.bottom,
                  ),
                  cursor: SystemMouseCursors.resizeDown,
                  onPanUpdate: (details) => widget.onResize(
                    SelectorHandlePosition.bottom,
                    details.delta,
                  ),
                ),
              ],
            )
          : MarchingAntsSelection(rect: widget.selectionRect),
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
