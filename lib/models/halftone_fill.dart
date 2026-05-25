import 'package:flutter/widgets.dart';

/// Describes the two-color payload for a halftone region fill.
class HalftoneFill {
  const HalftoneFill({
    required this.backgroundColor,
    required this.dotColor,
  });

  /// The solid background color drawn under the halftone dots.
  final Color backgroundColor;

  /// The color used for the halftone dots.
  final Color dotColor;
}
