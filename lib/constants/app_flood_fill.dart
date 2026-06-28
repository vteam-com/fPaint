/// Shared flood-fill tuning values and data-layout constants.
class AppFloodFill {
  static const int visitedMarker = 1;
  static const int runStride = 3;
  static const int rowPixelHeight = 1;

  /// Horizontal step of a single pixel column along a scanline.
  static const int columnPixelWidth = 1;

  /// Offset of the `startX` field within a run triple (`[y, startX, endX]`).
  static const int runFieldStartX = 1;

  /// Offset of the `endX` field within a run triple (`[y, startX, endX]`).
  static const int runFieldEndX = 2;
  static const int toleranceDenominatorPercent = 100;
  static const int initialSpanStackCapacity = 1024;
  static const int initialRunCapacity = 4096;
}
