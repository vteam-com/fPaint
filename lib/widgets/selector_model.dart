import 'package:flutter/material.dart';
import 'package:fpaint/widgets/marching_ants_rect.dart';

class SelectorModel {
  bool isVisible = false;
  Path path = Path();
  bool isMoving = false;

  Rect get boundingRect => path.getBounds();

  void translate(final Offset offset) {
    final Matrix4 matrix = Matrix4.identity()..translate(offset.dx, offset.dy);
    path = path.transform(matrix.storage);
  }

  void addPosition(final Offset position) {
    isVisible = true;
    if (isMoving) {
      // debugPrint('Selector isMoving - addPosition ${path.getBounds().topLeft}');
      final r = Rect.fromPoints(path.getBounds().topLeft, position);
      path = Path();
      path.addRect(r);
    } else {
      // debugPrint('Selector start from $position');
      path = Path();
      path.addRect(Rect.fromPoints(position, position));
      isMoving = true;
    }
  }
}

class SelectionHandleWidget extends StatelessWidget {
  const SelectionHandleWidget({
    super.key,
    required this.selectionRect,
    required this.onDrag,
    required this.onResize,
  });
  final Rect selectionRect;
  final Function(Offset) onDrag;
  final Function(Offset, HandlePosition) onResize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: selectionRect.left + selectionRect.width + 20,
      height: selectionRect.bottom + selectionRect.height + 20,
      child: Stack(
        children: [
          MarchingAntsSelection(rect: selectionRect),

          // Center handle for moving
          _buildHandle(
            position: selectionRect.center,
            cursor: SystemMouseCursors.move,
            onPanUpdate: (details) => onDrag(details.delta),
          ),
          // Corner top left
          _buildHandle(
            position: selectionRect.topLeft,
            cursor: SystemMouseCursors.resizeUpLeft,
            onPanUpdate: (details) =>
                onResize(details.delta, HandlePosition.topLeft),
          ),
          // Center top
          _buildHandle(
            position: selectionRect.topRight,
            cursor: SystemMouseCursors.resizeUpRight,
            onPanUpdate: (details) =>
                onResize(details.delta, HandlePosition.topRight),
          ),
          // bottom left
          _buildHandle(
            position: selectionRect.bottomLeft,
            cursor: SystemMouseCursors.resizeDownLeft,
            onPanUpdate: (details) =>
                onResize(details.delta, HandlePosition.bottomLeft),
          ),
          // bottom right
          _buildHandle(
            position: selectionRect.bottomRight,
            cursor: SystemMouseCursors.resizeDownRight,
            onPanUpdate: (details) =>
                onResize(details.delta, HandlePosition.bottomRight),
          ),
          // Side handles
          _buildHandle(
            position: Offset(selectionRect.left, selectionRect.center.dy),
            cursor: SystemMouseCursors.resizeLeft,
            onPanUpdate: (details) =>
                onResize(details.delta, HandlePosition.left),
          ),
          _buildHandle(
            position: Offset(selectionRect.right, selectionRect.center.dy),
            cursor: SystemMouseCursors.resizeRight,
            onPanUpdate: (details) =>
                onResize(details.delta, HandlePosition.right),
          ),
          _buildHandle(
            position: Offset(selectionRect.center.dx, selectionRect.top),
            cursor: SystemMouseCursors.resizeUp,
            onPanUpdate: (details) =>
                onResize(details.delta, HandlePosition.top),
          ),

          _buildHandle(
            position: Offset(selectionRect.center.dx, selectionRect.bottom),
            cursor: SystemMouseCursors.resizeDown,
            onPanUpdate: (details) =>
                onResize(details.delta, HandlePosition.bottom),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle({
    required Offset position,
    required MouseCursor cursor,
    required Function(DragUpdateDetails) onPanUpdate,
  }) {
    return Positioned(
      left: position.dx - 5,
      top: position.dy - 5,
      child: GestureDetector(
        onPanUpdate: onPanUpdate,
        child: MouseRegion(
          cursor: cursor,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.blue, width: 2),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

enum HandlePosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  left,
  right,
  top,
  bottom,
}
