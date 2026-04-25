import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

/// Defines the different styles for a brush.
enum BrushStyle {
  /// A solid brush style.
  solid,

  /// A dashed brush style.
  dash,

  /// A dotted brush style.
  dotted,

  /// An alternating dash-dot brush style.
  dashDot,

  /// A slash brush style that draws forward slashes along the path.
  slash,
}

/// Represents a brush with a specific style, color, and size.
class MyBrush {
  MyBrush({
    this.style = BrushStyle.solid,
    this.color = AppPalette.black,
    this.size = 1,
  });

  /// The style of the brush.
  BrushStyle style;

  /// The color of the brush.
  Color color;

  /// The size of the brush.
  double size;
}
