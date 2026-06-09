import 'app_interaction.dart';

/// Shared persisted/default app values.
class AppDefaults {
  static const double brushSize = 5.0;
  static const double smudgeIntensity = AppInteraction.pixelBrushDefaultIntensity;
  static const double blurBrushIntensity = AppInteraction.pixelBrushDefaultIntensity;
  static const int tolerance = 50;
  static const bool useApplePencil = false;
  static const bool keepSaveBackups = false;
  static const Duration brushSizePreviewDuration = Duration(milliseconds: 700);
  static const Duration buttonTapAnimationDuration = Duration(milliseconds: 100);
  static const Duration toolPanelRevealAnimationDuration = Duration(milliseconds: 140);
  static const Duration debounceDuration = Duration(seconds: 1);
  static const Duration animationLoopDuration = Duration(seconds: 1);
  static const Duration clipboardAccessTimeout = Duration(seconds: 2);
  static const Duration recoverySaveDebounce = Duration(seconds: 2);
  static const Duration integrationEvidenceCollectionDelay = Duration(seconds: 2);
  static const Duration integrationVisualCheckpointDelay = Duration(milliseconds: 700);
  static const Duration fileImportFeedbackDuration = Duration(seconds: 3);
  static const int integrationEvidenceJpegQuality = 95;
  static const double renderedScreenshotPixelRatio = 1.0;
}
