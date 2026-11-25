/// Layout and preview constants for the visual brush library (the
/// Procreate-style grid of live stroke previews that picks a [BrushStyle]).
class AppBrushLibrary {
  /// Width of one brush tile in the library grid.
  static const double tileWidth = 132.0;

  /// Height of the stroke-preview area inside a library tile.
  static const double tilePreviewHeight = 44.0;

  /// Height of the compact stroke swatch shown inline in the tools panel.
  static const double swatchHeight = 32.0;

  /// Width of the compact stroke swatch shown inline in the tools panel.
  static const double swatchWidth = 120.0;

  /// Brush size used to draw the sample stroke in a library tile.
  static const double previewBrushSize = 6.0;

  /// Brush size used to draw the sample stroke in the inline swatch.
  static const double swatchBrushSize = 4.0;

  /// Number of straight segments that approximate the sample S-curve.
  static const int previewSegments = 48;

  /// Vertical amplitude of the sample S-curve as a fraction of preview height.
  static const double previewAmplitudeFraction = 0.28;

  /// Number of full sine periods drawn across the preview width.
  static const double previewWavePeriods = 1.0;

  /// Horizontal inset of the sample stroke as a fraction of preview width,
  /// leaving room for round caps and soft/feathered edges.
  static const double previewInsetFraction = 0.1;

  /// Border width drawn around the selected tile.
  static const double selectedBorderWidth = 2.0;

  /// Border width drawn around unselected tiles.
  static const double borderWidth = 1.0;
}
