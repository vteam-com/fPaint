import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';

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

  /// A soft-edged "airbrush" style: the stroke is drawn with a Gaussian
  /// [MaskFilter.blur] so its edges feather out instead of being hard. Kept last
  /// so existing persisted [BrushStyle] indices stay stable.
  soft,

  /// A grainy "pencil" style: the stroke is modulated by a repeating paper-grain
  /// texture (see `BrushGrain`) so it reads as graphite rather than a flat fill.
  /// Appended last to keep persisted [BrushStyle] indices stable.
  grain,
}

/// Represents a brush with a specific style, color, and size.
class MyBrush {
  MyBrush({
    this.style = BrushStyle.solid,
    this.color = AppColors.black,
    this.size = 1,
  });

  /// The style of the brush.
  BrushStyle style;

  /// The color of the brush.
  Color color;

  /// The size of the brush.
  double size;
}
