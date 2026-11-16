import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';

/// Creates an [AnimationController] driven by [vsync] that repeats forever.
///
/// Shared by the looping indicators (spinner, marching ants, processing
/// shimmer) so they all start the same way. [duration] is one loop period and
/// defaults to [AppDefaults.animationLoopDuration]. The caller owns the
/// controller and must dispose it.
AnimationController createLoopingAnimationController(
  TickerProvider vsync, {
  Duration duration = AppDefaults.animationLoopDuration,
}) {
  return AnimationController(vsync: vsync, duration: duration)..repeat();
}
