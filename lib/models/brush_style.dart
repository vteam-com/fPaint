import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/hatch_marks.dart';
import 'package:fpaint/models/hatch_pattern.dart';

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

  /// Hatching: the stroke reveals a canvas-locked field of parallel lines (see
  /// `HatchPattern` / `BrushHatch`), the classic pen-and-ink shading mark.
  /// Appended last to keep persisted [BrushStyle] indices stable.
  hatch,

  /// Cross-hatching: like [hatch] with a second, perpendicular set of lines.
  /// Appended last to keep persisted [BrushStyle] indices stable.
  crossHatch,

  /// Hatch marks: individual tapered, optionally curved marks laid along the
  /// stroke (pencil / comic-book feathering; see `HatchMarks`). Unlike [hatch]
  /// they follow the gesture rather than a canvas-locked pattern.
  /// Appended last to keep persisted [BrushStyle] indices stable.
  hatchMarks;

  /// Whether this style paints the canvas-locked hatch pattern and therefore
  /// uses `MyBrush.hatch` / the hatch pattern settings.
  bool get isHatch => this == BrushStyle.hatch || this == BrushStyle.crossHatch;
}

/// Represents a brush with a specific style, color, and size.
class MyBrush {
  MyBrush({
    this.style = BrushStyle.solid,
    this.color = AppColors.black,
    this.size = 1,
    this.hatch = const HatchPattern(),
    this.marks = const HatchMarks(),
  });

  /// The style of the brush.
  BrushStyle style;

  /// The color of the brush.
  Color color;

  /// The size of the brush.
  double size;

  /// The hatch geometry used when [style] is a hatch style; ignored otherwise.
  /// Captured per stroke so later settings edits leave existing strokes alone.
  HatchPattern hatch;

  /// The mark geometry used when [style] is [BrushStyle.hatchMarks]; ignored
  /// otherwise. Captured per stroke like [hatch].
  HatchMarks marks;
}
