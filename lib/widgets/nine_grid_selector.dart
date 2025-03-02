import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/models/canvas_resize.dart';

class NineGridSelector extends StatelessWidget {
  const NineGridSelector({
    super.key,
    required this.selectedPosition,
    required this.onPositionSelected,
  });
  final CanvasResizePosition selectedPosition;
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
