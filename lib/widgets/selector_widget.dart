import 'package:flutter/material.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/widgets/marching_ants_path.dart';

/// A widget that displays a selection rectangle with handles for resizing and moving.
class SelectionRectWidget extends StatefulWidget {
  /// Creates a [SelectionRectWidget].
  ///
  /// The [path1] parameter specifies the primary path of the selection rectangle.
  /// The [path2] parameter specifies an optional secondary path for the selection rectangle.
  /// The [onDrag] parameter is a callback that is called when the selection rectangle is dragged.
  /// The [onResize] parameter is a callback that is called when the selection rectangle is resized.
  /// The [enableMoveAndResize] parameter specifies whether the selection rectangle can be moved and resized.
  const SelectionRectWidget({
    super.key,
    required this.path1,
    required this.path2,
    required this.onDrag,
    required this.onResize,
    this.enableMoveAndResize = true,
  });

  /// Whether the selection rectangle can be moved and resized.
  final bool enableMoveAndResize;

  /// A callback that is called when the selection rectangle is dragged.
  final void Function(Offset) onDrag;

  /// A callback that is called when the selection rectangle is resized.
  final void Function(NineGridHandle, Offset) onResize;

  /// The primary path of the selection rectangle.
  final Path? path1;

  /// An optional secondary path for the selection rectangle.
  final Path? path2;

  @override
  State<SelectionRectWidget> createState() => _SelectionRectWidgetState();
}

const int defaultHandleSize = 20;

class _SelectionRectWidgetState extends State<SelectionRectWidget> {
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

    if (widget.enableMoveAndResize) {
      stackChildren.addAll(<Widget>[
        // Center handle for moving
        _buildHandle(
          position: bounds.center,
          cursor: SystemMouseCursors.move,
          onPanUpdate: (final DragUpdateDetails details) => widget.onDrag(
            details.delta,
          ),
        ),

        // Top Left
        _buildHandle(
          position: bounds.topLeft,
          cursor: SystemMouseCursors.resizeUpLeft,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
            NineGridHandle.topLeft,
            details.delta,
          ),
        ),

        // Top Right
        _buildHandle(
          position: bounds.topRight,
          cursor: SystemMouseCursors.resizeUpRight,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
            NineGridHandle.topRight,
            details.delta,
          ),
        ),

        // Bottom Left
        _buildHandle(
          position: bounds.bottomLeft,
          cursor: SystemMouseCursors.resizeDownLeft,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
            NineGridHandle.bottomLeft,
            details.delta,
          ),
        ),

        // Bottom right
        _buildHandle(
          position: bounds.bottomRight,
          cursor: SystemMouseCursors.resizeDownRight,
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
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
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
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
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
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
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
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
          onPanUpdate: (final DragUpdateDetails details) => widget.onResize(
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

  /// Builds a handle for resizing or moving the selection rectangle.
  ///
  /// The [position] parameter specifies the position of the handle.
  /// The [cursor] parameter specifies the cursor to display when the mouse is over the handle.
  /// The [onPanUpdate] parameter is a callback that is called when the handle is dragged.
  Widget _buildHandle({
    required final Offset position,
    required final MouseCursor cursor,
    required final void Function(DragUpdateDetails) onPanUpdate,
  }) {
    final int handleSize = (showCoordinate ? (defaultHandleSize * 1.5) : defaultHandleSize).toInt();

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
        onPanEnd: (final DragEndDetails details) => setState(() => showCoordinate = false),
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
