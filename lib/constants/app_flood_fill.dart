/// Shared flood-fill tuning values and data-layout constants.
class AppFloodFill {
  static const int visitedMarker = 1;
  static const int runStride = 3;
  static const int rowPixelHeight = 1;
  static const int toleranceDenominatorPercent = 100;
  static const int initialSpanStackCapacity = 1024;
  static const int initialRunCapacity = 4096;
}
