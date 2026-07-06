/// Shared divider and border tokens.
class AppStroke {
  static const double thin = 1.0;
  static const double regular = 2.0;
  static const double emphasis = 3.0;
  static const double divider = 5.0;
  static const double dividerHighlighted = 8.0;

  /// Dash-width multiplier relative to brush size for dashed patterns.
  static const double dashWidthFactor = 3.0;

  /// Gap multiplier relative to brush size for dashed patterns.
  static const double dashGapFactor = 2.0;

  /// Gaussian blur sigma for the soft ("airbrush") brush style, as a fraction of
  /// brush size. ~0.5 feathers most of the stroke into a soft falloff.
  static const double softBlurSigmaFactor = 0.5;

  /// How far (in sigmas) a Gaussian blur visibly extends — used to outset the
  /// export/cache bounds of a soft stroke so its feather is not clipped.
  static const double softBlurExtentSigmas = 3.0;
}
