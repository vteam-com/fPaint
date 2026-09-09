/// Tuning for the **Hatch marks** brush style: individual tapered marks laid
/// along the stroke (pencil / comic-book feathering), as opposed to the
/// canvas-locked line field of `AppHatch`.
///
/// Angles are relative to the stroke direction; lengths are in canvas pixels
/// except where noted. The mark's thick end sits on the stroke path and its
/// tip fans out in the mark direction.
class AppHatchMarks {
  /// Default mark direction relative to the stroke heading, in degrees
  /// (90 = perpendicular, to the left of travel).
  static const int defaultAngleDegrees = 90;

  /// Smallest relative angle in degrees.
  static const int minAngleDegrees = 0;

  /// Largest relative angle in degrees; 360 wraps back to the stroke heading.
  static const int maxAngleDegrees = 360;

  /// Slider steps for the angle control (one step per degree).
  static const int angleDivisions = 360;

  /// Default distance between consecutive marks along the stroke, in pixels.
  static const int defaultSpacing = 6;

  /// Smallest mark spacing in pixels.
  static const int minSpacing = 1;

  /// Largest mark spacing in pixels.
  static const int maxSpacing = 64;

  /// Default mark length in pixels.
  static const int defaultLength = 40;

  /// Shortest mark in pixels.
  static const int minLength = 4;

  /// Longest mark in pixels.
  static const int maxLength = 200;

  /// Default taper: 100% thins the mark to a point and fades it out completely.
  static const int defaultTaperPercent = 100;

  /// Default curve: 0 is a straight mark; ±100% bends the tip sideways by half
  /// the mark length.
  static const int defaultCurvePercent = 0;

  /// Smallest curve percentage (bend to the right of the mark direction).
  static const int minCurvePercent = -100;

  /// Largest curve percentage (bend to the left of the mark direction).
  static const int maxCurvePercent = 100;

  /// Slider steps for the curve control.
  static const int curveDivisions = 200;

  /// Sideways offset of the bezier control point at 100% curve, as a fraction
  /// of the mark length.
  static const double curveControlFactor = 0.5;

  /// Number of spine samples used to build one mark's outline polygon.
  static const int outlineSamples = 12;
}
