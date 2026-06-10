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
  static const double smudgeMaximumPointSpacing = 2.0;
  static const double smudgeStepSpacingFactor = 0.35;
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
