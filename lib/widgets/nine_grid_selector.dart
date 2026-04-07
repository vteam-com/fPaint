import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
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

  /// A callback that is called when a position is selected.
  final void Function(CanvasResizePosition) onPositionSelected;

  /// The currently selected position.
  final CanvasResizePosition selectedPosition;

  @override
  Widget build(final BuildContext context) {
    return Container(
      width: AppLayout.gridSelectorSize,
      height: AppLayout.gridSelectorSize,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.sm),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: AppMath.triple,
          crossAxisSpacing: AppSpacing.xxs,
          mainAxisSpacing: AppSpacing.xxs,
        ),
        itemCount: AppMath.triple * AppMath.triple,
        itemBuilder: (final BuildContext _, final int index) {
          return GestureDetector(
            onTap: () => onPositionSelected(CanvasResizePosition.values[index]),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selectedPosition == CanvasResizePosition.values[index] ? Colors.blue : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                selectedPosition == CanvasResizePosition.values[index] ? Icons.image : getDirectionIcon(index),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Returns the appropriate [IconData] for the given direction.
  IconData getDirectionIcon(final int direction) {
    const List<IconData> directionIcons = <IconData>[
      CupertinoIcons.arrow_up_left,
      CupertinoIcons.arrow_up,
      CupertinoIcons.arrow_up_right,
      CupertinoIcons.arrow_left,
      Icons.crop_square_outlined,
      CupertinoIcons.arrow_right,
      CupertinoIcons.arrow_down_left,
      CupertinoIcons.arrow_down,
      CupertinoIcons.arrow_down_right,
    ];
    return directionIcons[direction];
  }
}
