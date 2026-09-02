/// Shared numeric bounds and percentage-based tokens.
class AppLimits {
  static const int rgbChannelMax = 255;
  static const int percentMax = 100;
  static const int topColorCount = 20;
  static const int brushSizeMax = 200;

  /// Maximum number of undoable actions kept in global history. Older records
  /// are evicted (their content stays on the canvas, it just can no longer be
  /// undone), which bounds record memory and lets the disposal coordinator free
  /// any GPU textures an evicted record was the last to retain. Tune for the
  /// depth-vs-memory trade-off.
  static const int maxUndoHistory = 50;

  /// Maximum brush size for the smudge/blur pixel brushes, which benefit from
  /// much larger radii than paint tools.
  static const int pixelBrushSizeMax = 500;
  static const int transparentPatternSize = 10;
  static const int hexRgbLength = 6;
  static const int hexArgbLength = 8;
  static const int textSizeMin = 8;
  static const int textSizeMax = 72;
  static const int textSizeDivisions = 32;
  static const int truncatedTextLength = 6;
  static const int opacityPrecision = 5;
  static const int sliderDivisions = 100;
  static const int hueDivisions = 360;
  static const int hueGroupingStepDegrees = 15;
  static const int maxRecentFiles = 10;
  static const int recentFilesDisplayCount = 5;
  static const int maxSaveFileBackups = 3;

  /// Conservative upper bound for a single render-target dimension. ANGLE on
  /// D3D11 caps textures at 16384; staying well under it avoids allocation
  /// failures that surface as an EGL "context lost" device reset.
  static const int maxRenderTargetDimension = 8192;

  /// Longest side of the downscaled image used for live effect previews.
  static const int effectPreviewMaxDimension = 2048;

  /// Longest side of the raster sampled by flood fill. Larger canvases are
  /// sampled at this bounded resolution to avoid a full-size GPU readback.
  static const int floodFillSourceMaxDimension = 2048;

  /// Whole-layer image generations kept in a layer's action stack. Each one
  /// costs a full-canvas texture, so only the current and previous are kept;
  /// older generations are already invisible behind the full-layer erase.
  static const int fullLayerImageGenerations = 2;

  /// Whole-layer effect records kept in undo history, matching the one
  /// restorable generation left by [fullLayerImageGenerations].
  static const int fullLayerEffectUndoHistory = 1;

  /// Largest canvas (in pixels) that still gets a retained full-resolution
  /// layer cache. Above this the render target alone is hundreds of MB, which
  /// Impeller cannot allocate reliably, so the display projection is used.
  static const int fullResolutionCacheMaxPixels = 16000000;
}
