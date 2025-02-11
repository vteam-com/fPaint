import 'package:flutter/material.dart';
import 'package:fpaint/widgets/marching_ants_rect.dart';

class SelectorModel {
  bool isVisible = false;
  Path path = Path();
  bool isMoving = false;

  Rect get boundingRect => path.getBounds();

  void translate(final Offset offset) {
    final Rect bounds = path.getBounds();

    if (bounds.width <= 0 || bounds.height <= 0) {
      return; // Prevent invalid transformations
    }

    final Matrix4 matrix = Matrix4.identity()..translate(offset.dx, offset.dy);
    path = path.transform(matrix.storage);
  }

  void inflate(final HandlePosition handle, final Offset offset) {
    final Rect bounds = path.getBounds();
    late Rect newBounds;

    switch (handle) {
      case HandlePosition.topLeft:
        newBounds = Rect.fromLTRB(
          bounds.left + offset.dx,
          bounds.top + offset.dy,
          bounds.right,
          bounds.bottom,
        );
        break;
      case HandlePosition.top:
        newBounds = Rect.fromLTRB(
          bounds.left,
          bounds.top + offset.dy,
          bounds.right,
          bounds.bottom,
        );
        break;
      case HandlePosition.topRight:
        newBounds = Rect.fromLTRB(
          bounds.left,
          bounds.top + offset.dy,
          bounds.right + offset.dx,
          bounds.bottom,
        );
        break;
      case HandlePosition.right:
        newBounds = Rect.fromLTRB(
          bounds.left,
          bounds.top,
          bounds.right + offset.dx,
          bounds.bottom,
        );
        break;
      case HandlePosition.bottomRight:
        newBounds = Rect.fromLTRB(
          bounds.left,
          bounds.top,
          bounds.right + offset.dx,
          bounds.bottom + offset.dy,
        );
        break;
      case HandlePosition.bottom:
        newBounds = Rect.fromLTRB(
          bounds.left,
          bounds.top,
          bounds.right,
          bounds.bottom + offset.dy,
        );
        break;
      case HandlePosition.bottomLeft:
        newBounds = Rect.fromLTRB(
          bounds.left + offset.dx,
          bounds.top,
          bounds.right,
          bounds.bottom + offset.dy,
        );
        break;
      case HandlePosition.left:
        newBounds = Rect.fromLTRB(
          bounds.left + offset.dx,
          bounds.top,
          bounds.right,
          bounds.bottom,
        );
        break;
    }

    // Ensure the width and height remain positive
    if (newBounds.width > 0 && newBounds.height > 0) {
      path = Path()..addRect(newBounds);
    }
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
  final Function(HandlePosition, Offset) onResize;

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
            onPanUpdate: (details) => onDrag(
              details.delta,
            ),
          ),

          // Top Left
          _buildHandle(
            position: selectionRect.topLeft,
            cursor: SystemMouseCursors.resizeUpLeft,
            onPanUpdate: (details) => onResize(
              HandlePosition.topLeft,
              details.delta,
            ),
          ),

          // Top Right
          _buildHandle(
            position: selectionRect.topRight,
            cursor: SystemMouseCursors.resizeUpRight,
            onPanUpdate: (details) => onResize(
              HandlePosition.topRight,
              details.delta,
            ),
          ),

          // Bottom Left
          _buildHandle(
            position: selectionRect.bottomLeft,
            cursor: SystemMouseCursors.resizeDownLeft,
            onPanUpdate: (details) => onResize(
              HandlePosition.bottomLeft,
              details.delta,
            ),
          ),

          // Bottom right
          _buildHandle(
            position: selectionRect.bottomRight,
            cursor: SystemMouseCursors.resizeDownRight,
            onPanUpdate: (details) => onResize(
              HandlePosition.bottomRight,
              details.delta,
            ),
          ),

          // Side Left
          _buildHandle(
            position: Offset(selectionRect.left, selectionRect.center.dy),
            cursor: SystemMouseCursors.resizeLeft,
            onPanUpdate: (details) => onResize(
              HandlePosition.left,
              details.delta,
            ),
          ),

          // Side Right
          _buildHandle(
            position: Offset(selectionRect.right, selectionRect.center.dy),
            cursor: SystemMouseCursors.resizeRight,
            onPanUpdate: (details) => onResize(
              HandlePosition.right,
              details.delta,
            ),
          ),

          // Center Top
          _buildHandle(
            position: Offset(selectionRect.center.dx, selectionRect.top),
            cursor: SystemMouseCursors.resizeUp,
            onPanUpdate: (details) => onResize(
              HandlePosition.top,
              details.delta,
            ),
          ),

          // Center Bottom
          _buildHandle(
            position: Offset(selectionRect.center.dx, selectionRect.bottom),
            cursor: SystemMouseCursors.resizeDown,
            onPanUpdate: (details) => onResize(
              HandlePosition.bottom,
              details.delta,
            ),
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

enum HandlePosition {
  topLeft,
  topRight,
  //
  bottomLeft,
  bottomRight,
  //
  left,
  right,
  //
  top,
  bottom,
}
