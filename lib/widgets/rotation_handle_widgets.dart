import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';

/// Builds the thin vertical line that connects a bounding box's top-center edge
/// to the rotation handle above it.
///
/// The stem is positioned centred horizontally on [bounds] and extends upward
/// by [AppInteraction.rotationHandleDistance] pixels.
Widget buildRotationStem(final Rect bounds) {
  final double stemTop = bounds.top - AppInteraction.rotationHandleDistance;
  final double stemX = bounds.center.dx;

  return Positioned(
    left: stemX - (AppInteraction.rotationHandleLineWidth / AppMath.pair),
    top: stemTop,
    child: IgnorePointer(
      child: Container(
        width: AppInteraction.rotationHandleLineWidth,
        height: AppInteraction.rotationHandleDistance,
        color: Colors.blue,
      ),
    ),
  );
}
