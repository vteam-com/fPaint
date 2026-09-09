/// Tuning for the hatch / cross-hatch brush style and paint-bucket pattern.
///
/// Hatching is a **canvas-locked** pattern: parallel lines at a fixed angle and
/// spacing, sampled in canvas space so every stroke and fill reveals the same
/// stationary line field (like shading through a stencil). All lengths are in
/// canvas pixels.
class AppHatch {
  /// Default line angle in degrees (0 = horizontal, counter-clockwise positive).
  static const int defaultAngleDegrees = 45;

  /// Smallest selectable angle in degrees.
  static const int minAngleDegrees = 0;

  /// Largest selectable angle in degrees; 180 wraps back to horizontal.
  static const int maxAngleDegrees = 180;

  /// Slider steps for the angle control (one step per degree).
  static const int angleDivisions = 180;

  /// Angle added to the first line set to produce the cross-hatch set.
  static const int crossAngleOffsetDegrees = 90;

  /// Default centre-to-centre distance between lines, in pixels.
  static const int defaultSpacing = 8;

  /// Smallest line spacing in pixels (one line, one gap).
  static const int minSpacing = 2;

  /// Largest line spacing in pixels.
  static const int maxSpacing = 64;

  /// Default line thickness in pixels.
  static const int defaultLineWidth = 1;

  /// Thinnest line in pixels.
  static const int minLineWidth = 1;

  /// Thickest line in pixels; also clamped below the spacing at render time so
  /// a hatch never degenerates into a solid fill.
  static const int maxLineWidth = 16;
}
