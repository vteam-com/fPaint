/// Shared fill and gesture tuning values.
class AppInteraction {
  static const double minCanvasScale = 0.1;
  static const double maxCanvasScale = 10.0;
  static const double multiTouchScaleThreshold = 50.0;
  static const Duration selectionDoubleTapTimeout = Duration(milliseconds: 300);
  static const double selectionDoubleTapSlop = 24.0;
  static const double linearFillHandleOffset = 40.0;
  static const double radialFillHandleOffset = 50.0;
  static const double magnifierScale = 6.0;
  static const double magnifierImageScale = 8.0;
  static const double smudgeMinimumRadius = 1.0;
  static const double smudgeBrushRadiusFactor = 0.5;
  static const double smudgeInputPointSpacing = 1.0;
  static const double smudgeStepSpacingFactor = 0.35;

  /// Dab spacing as a fraction of radius for the GPU pixel brush. Much finer
  /// than [smudgeStepSpacingFactor] (used by the CPU path, where each dab costs
  /// a radius² per-pixel loop): a GPU dab is a cheap texture blit, so dense
  /// dabs are affordable and are what make the smudge trail seamless instead of
  /// a chain of discs.
  static const double smudgeGpuStepSpacingFactor = 0.1;

  /// Upper bound on dabs emitted for a single pointer-move on the GPU path, so a
  /// fast flick cannot stall a frame with hundreds of full-canvas blits.
  static const int smudgeGpuMaxDabsPerMove = 96;
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

  /// Padding (px) added around a GPU dab's bounding rect so the feathered brush
  /// edge is fully covered.
  static const double smudgeGpuDabPadding = 2.0;

  // Fragment-shader uniform float-slot indices for `shaders/pixel_brush.frag`.
  // Slots 0/1 are the resolution vec2, 2/3 the previous dab centre, 4/5 the
  // current dab centre, then radius, blend strength, mode and blur spacing.
  static const int pixelBrushShaderSlotWidth = 0;
  static const int pixelBrushShaderSlotHeight = 1;
  static const int pixelBrushShaderSlotFromX = 2;
  static const int pixelBrushShaderSlotFromY = 3;
  static const int pixelBrushShaderSlotToX = 4;
  static const int pixelBrushShaderSlotToY = 5;
  static const int pixelBrushShaderSlotRadius = 6;
  static const int pixelBrushShaderSlotStrength = 7;
  static const int pixelBrushShaderSlotMode = 8;
  static const int pixelBrushShaderSlotBlurSpacing = 9;

  /// Sampler slot for the working image texture in `pixel_brush.frag`.
  static const int pixelBrushShaderSamplerTexture = 0;
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
