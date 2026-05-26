import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

/// Describes the two-color payload for a halftone region fill.
class HalftoneFill {
  const HalftoneFill({
    required this.backgroundColor,
    required this.dotColor,
    this._maxDotSizeFactor,
  });

  /// The solid background color drawn under the halftone dots.
  final Color backgroundColor;

  /// The color used for the halftone dots.
  final Color dotColor;

  /// Relative scale applied to the maximum halftone dot radius.
  final double? _maxDotSizeFactor;

  /// Relative scale applied to the maximum halftone dot radius.
  double get maxDotSizeFactor => _maxDotSizeFactor ?? AppVisual.full;
}
