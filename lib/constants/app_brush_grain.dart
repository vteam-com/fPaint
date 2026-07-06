/// Tuning for the grain ("pencil") brush style's procedural noise tile.
class AppBrushGrain {
  /// Edge length of the square noise tile in pixels; tiled/repeated across strokes.
  static const int tileSize = 128;

  /// Fixed RNG seed so the tile is deterministic — identical every render and run,
  /// which keeps grain strokes stable across redraws.
  static const int seed = 0x6C6E;

  /// Minimum per-texel alpha; the speckle varies in [minAlpha, 255].
  static const int minAlpha = 64;
}
