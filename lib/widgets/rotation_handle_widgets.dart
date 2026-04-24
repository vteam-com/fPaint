import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

/// Builds the thin vertical line that connects a bounding box's top-center edge
/// to the rotation handle above it.
///
/// The stem is positioned centred horizontally on [bounds] and extends upward
/// by [AppInteraction.rotationHandleDistance] pixels.
///
/// When [handleSize] is provided, the stem ends at the bottom edge of the
/// handle instead of its centre. This keeps larger selector-mode buttons from
/// being visually bisected by the stem line.
Widget buildRotationStem(final Rect bounds, {final double? handleSize}) {
  final double stemTop = handleSize == null
      ? bounds.top - AppInteraction.rotationHandleDistance
      : bounds.top - AppInteraction.rotationHandleDistance + handleSize / AppMath.pair;
  final double stemHeight = handleSize == null
      ? AppInteraction.rotationHandleDistance
      : AppInteraction.rotationHandleDistance - handleSize / AppMath.pair;
  final double stemX = bounds.center.dx;

  if (stemHeight <= 0) {
    return const SizedBox.shrink();
  }

  return Positioned(
    left: stemX - (AppInteraction.rotationHandleLineWidth / AppMath.pair),
    top: stemTop,
    child: IgnorePointer(
      child: Container(
        width: AppInteraction.rotationHandleLineWidth,
        height: stemHeight,
        color: AppPalette.blue,
      ),
    ),
  );
}
