import 'package:flutter/material.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/widgets/marching_ants_rect.dart';

class SelectionHandleWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: selectionRect.left + selectionRect.width + 20,
      height: selectionRect.bottom + selectionRect.height + 20,
      child: enableMoveAndResize
          ? Stack(
              children: [
                MarchingAntsSelection(rect: selectionRect),

                // Center handle for moving
                _buildHandle(
                  position: selectionRect.center,
                  cursor: SystemMouseCursors.move,
                  onPanUpdate: (details) => onDrag(
                    details.delta,
                  ),
                ),

                // Top Left
                _buildHandle(
                  position: selectionRect.topLeft,
                  cursor: SystemMouseCursors.resizeUpLeft,
                  onPanUpdate: (details) => onResize(
                    SelectorHandlePosition.topLeft,
                    details.delta,
                  ),
                ),

                // Top Right
                _buildHandle(
                  position: selectionRect.topRight,
                  cursor: SystemMouseCursors.resizeUpRight,
                  onPanUpdate: (details) => onResize(
                    SelectorHandlePosition.topRight,
                    details.delta,
                  ),
                ),

                // Bottom Left
                _buildHandle(
                  position: selectionRect.bottomLeft,
                  cursor: SystemMouseCursors.resizeDownLeft,
                  onPanUpdate: (details) => onResize(
                    SelectorHandlePosition.bottomLeft,
                    details.delta,
                  ),
                ),

                // Bottom right
                _buildHandle(
                  position: selectionRect.bottomRight,
                  cursor: SystemMouseCursors.resizeDownRight,
                  onPanUpdate: (details) => onResize(
                    SelectorHandlePosition.bottomRight,
                    details.delta,
                  ),
                ),

                // Side Left
                _buildHandle(
                  position: Offset(selectionRect.left, selectionRect.center.dy),
                  cursor: SystemMouseCursors.resizeLeft,
                  onPanUpdate: (details) => onResize(
                    SelectorHandlePosition.left,
                    details.delta,
                  ),
                ),

                // Side Right
                _buildHandle(
                  position:
                      Offset(selectionRect.right, selectionRect.center.dy),
                  cursor: SystemMouseCursors.resizeRight,
                  onPanUpdate: (details) => onResize(
                    SelectorHandlePosition.right,
                    details.delta,
                  ),
                ),

                // Center Top
                _buildHandle(
                  position: Offset(selectionRect.center.dx, selectionRect.top),
                  cursor: SystemMouseCursors.resizeUp,
                  onPanUpdate: (details) => onResize(
                    SelectorHandlePosition.top,
                    details.delta,
                  ),
                ),

                // Center Bottom
                _buildHandle(
                  position:
                      Offset(selectionRect.center.dx, selectionRect.bottom),
                  cursor: SystemMouseCursors.resizeDown,
                  onPanUpdate: (details) => onResize(
                    SelectorHandlePosition.bottom,
                    details.delta,
                  ),
                ),
              ],
            )
          : MarchingAntsSelection(rect: selectionRect),
    );
  }

  Widget _buildHandle({
    required Offset position,
    required MouseCursor cursor,
    required Function(DragUpdateDetails) onPanUpdate,
  }) {
    return Positioned(
      left: position.dx - 10,
      top: position.dy - 10,
      child: GestureDetector(
        onPanUpdate: onPanUpdate,
        child: MouseRegion(
          cursor: cursor,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue,
              border: Border.all(color: Colors.white, width: 2),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
