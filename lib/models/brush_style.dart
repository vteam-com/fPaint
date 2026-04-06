import 'package:flutter/material.dart';

/// Defines the different styles for a brush.
enum BrushStyle {
  /// A solid brush style.
  solid,

  /// A dashed brush style.
  dash,
}

/// Represents a brush with a specific style, color, and size.
class MyBrush {
  MyBrush({
    this.style = BrushStyle.solid,
    this.color = Colors.black,
    this.size = 1,
  });

  /// The style of the brush.
  BrushStyle style;

  /// The color of the brush.
  Color color;

  /// The size of the brush.
  double size;
}
