import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:fpaint/widgets/app_icon.dart';

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
          crossAxisSpacing: AppSpacing.xs,
          mainAxisSpacing: AppSpacing.xs,
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
              child: AppSvgIcon(
                icon: selectedPosition == CanvasResizePosition.values[index] ? AppIcon.image : getDirectionIcon(index),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Returns the appropriate [AppIcon] for the given direction.
  AppIcon getDirectionIcon(final int direction) {
    const List<AppIcon> directionIcons = <AppIcon>[
      AppIcon.arrowUpLeft,
      AppIcon.arrowUp,
      AppIcon.arrowUpRight,
      AppIcon.arrowLeft,
      AppIcon.cropSquare,
      AppIcon.arrowRight,
      AppIcon.arrowDownLeft,
      AppIcon.arrowDown,
      AppIcon.arrowDownRight,
    ];
    return directionIcons[direction];
  }
}
