import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/models/canvas_resize.dart';

/// A widget that displays a 3x3 grid of icons, allowing the user to select a [CanvasResizePosition].
class NineGridSelector extends StatelessWidget {
  /// Creates a [NineGridSelector].
  ///
  /// The [selectedPosition] parameter specifies the currently selected position.
  /// The [onPositionSelected] parameter is a callback that is called when a position is selected.
  const NineGridSelector({
    super.key,
    required this.selectedPosition,
    required this.onPositionSelected,
  });

  /// The currently selected position.
  final CanvasResizePosition selectedPosition;

  /// A callback that is called when a position is selected.
  final void Function(CanvasResizePosition) onPositionSelected;

  @override
  Widget build(final BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: 9,
        itemBuilder: (final BuildContext context, final int index) {
          return GestureDetector(
            onTap: () => onPositionSelected(CanvasResizePosition.values[index]),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selectedPosition == CanvasResizePosition.values[index]
                    ? Colors.blue
                    : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                selectedPosition == CanvasResizePosition.values[index]
                    ? Icons.image
                    : getDirectionIcon(index),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Returns the appropriate [IconData] for the given direction.
  IconData getDirectionIcon(final int direction) {
    switch (direction) {
      case 0:
        return CupertinoIcons.arrow_up_left;
      case 1:
        return CupertinoIcons.arrow_up;
      case 2:
        return CupertinoIcons.arrow_up_right;
      case 3:
        return CupertinoIcons.arrow_left;
      case 4:
        return Icons.crop_square_outlined; // Center Center
      case 5:
        return CupertinoIcons.arrow_right;
      case 6:
        return CupertinoIcons.arrow_down_left;
      case 7:
        return CupertinoIcons.arrow_down;
      case 8:
        return CupertinoIcons.arrow_down_right;
    }
    return Icons.crop_square_outlined;
  }
}
