/// Shared fill and gesture tuning values.
class AppInteraction {
  static const double minCanvasScale = 0.1;
  static const double maxCanvasScale = 10.0;
  static const double multiTouchScaleThreshold = 50.0;
  static const Duration selectionDoubleTapTimeout = Duration(milliseconds: 300);
  static const double selectionDoubleTapSlop = 24.0;

  /// Horizontal screen pixels dragged per 1 unit of Edge Detection wand
  /// tolerance during the tap-to-sample, drag-to-adjust selection gesture.
  static const double wandToleranceDragPixelsPerUnit = 8.0;
  static const double linearFillHandleOffset = 40.0;
  static const double radialFillHandleOffset = 50.0;

  /// Placement of the on-canvas Apply/Cancel controls for a live gradient fill,
  /// relative to the gradient center: half the control row's width (to center
  /// it horizontally) and its downward offset (to clear the color-stop handles).
  static const double fillControlsHalfWidth = 40.0;
  static const double fillControlsVerticalOffset = 44.0;

  /// Diameter of the fixed marker pinned at the start of a horizontal tolerance
  /// drag (while the cursor is hidden), for the wand and the paint bucket.
  static const double toleranceAnchorMarkerSize = 18.0;
  static const double magnifierScale = 6.0;
  static const double magnifierImageScale = 8.0;
  static const double smudgeMinimumRadius = 1.0;
  static const double smudgeBrushRadiusFactor = 0.5;
  static const double smudgeInputPointSpacing = 1.0;

  /// Dab spacing as a fraction of the brush radius. The smudge/blur effect is
  /// rendered once on pointer-up (the drag only shows a marquee), so we can
  /// afford dense dabs for a smooth trail without per-move lag — 0.15 (~13× disc
  /// overlap) removes the washboard ridges the coarser 0.35 left behind.
  static const double smudgeStepSpacingFactor = 0.15;

  /// Downsampling for the one-shot commit render. The GPU→CPU readback of the
  /// source region is the commit bottleneck (Impeller stalls at ~10 µs/px), so
  /// for a large brush we read back / process / upload at reduced resolution and
  /// GPU-upscale the result — smudge/blur are soft enough that the loss is
  /// invisible. One downsample level per this many pixels of brush radius.
  static const double smudgeCommitDownsampleRadiusPerLevel = 40.0;

  /// Maximum commit downsample factor (a big brush caps here).
  static const int smudgeCommitMaxDownsample = 4;

  /// Level-of-detail for the CPU smudge/blur *computation* (isolate). The per-dab
  /// cost is O(radius²), so a large brush is computed on a downsampled copy of the
  /// region and upsampled back — the effect is low-frequency, so the detail loss
  /// is invisible while cost drops by the factor squared (Krita "Instant Preview"
  /// applied to the CPU path). LOD only kicks in above this brush radius (px).
  static const double smudgeComputeLodMinRadius = 64.0;

  /// Target effective radius (px) at LOD resolution — the downsample factor is
  /// chosen so the brush works at roughly this radius on the low-res buffer.
  static const double smudgeComputeLodTargetRadius = 48.0;

  /// Cap on the LOD downsample factor for the compute pass.
  static const int smudgeComputeLodMaxFactor = 8;

  /// Padding (px) added around a smudge stroke's region when caching the source
  /// backdrop, so nearby subsequent strokes stay cache hits without re-reading.
  /// Only this region is read back (not the whole canvas), bounding both the
  /// readback cost and the resident memory on large canvases.
  static const double smudgeSourceCacheMargin = 384.0;

  static const double smudgeBlendStrength = 0.8;
  static const double smudgeEdgeFalloffExponent = 2.0;
  static const double pixelBrushDefaultIntensity = 0.5;
  static const double pixelBrushIntensityAppliedScale = 2.0;
  static const int smudgeBoundsPadding = 2;
  static const double blurBrushStrength = 0.6;
  static const double blurBrushEdgeFalloffExponent = 2.0;
  static const int blurBrushKernelHalf = 1;
  static const int blurBrushKernelHalfRange = 2;
  static const int pixelBrushMaxUndoGestures = 3;

  /// Max un-baked freehand segments replayed per frame before the in-progress
  /// stroke is folded into the cached baseline. Bounds per-frame preview cost to
  /// O(threshold) instead of O(stroke length); below it the tail is cheap to
  /// replay, so short strokes never pay for a full-canvas re-bake.
  static const int strokePreviewFoldThreshold = 64;

  static const double selectionHandleSize = 20;
  static const double selectionToolbarMargin = 50.0;
  static const double imagePlacementHandleSize = 14.0;
  static const double imagePlacementButtonSpacing = 8.0;
  static const double imagePlacementButtonSize = 36.0;
  static const double imagePlacementMinScale = 0.1;
  static const double imagePlacementMaxScale = 5.0;
  static const double transformEdgeHandleSize = 12.0;
  static const double transformScaleFactorMin = 0.1;
  static const double transformScaleFactorMax = 10.0;
  static const int transformGridSubdivisions = 10;
}
