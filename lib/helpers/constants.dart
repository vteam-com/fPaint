// ignore: fcheck_one_class_per_file
// ignore: fcheck_magic_numbers
import 'dart:ui' show Color, FontWeight;

import 'package:flutter/foundation.dart' show Key;
import 'package:flutter/painting.dart' show TextStyle;

/// The application display name.
const String appName = 'fPaint';

/// Default font family used throughout the app.
///
/// Inter is an open-source sans-serif designed for screens, visually close to
/// Apple San Francisco. Licensed under the SIL Open Font License 1.1.
/// Bundle fonts by running `bash tool/download_fonts.sh` once.
const String appFontFamily = 'Inter';

/// Barrier label used by [showGeneralDialog] overlays to dismiss on tap outside.
const String barrierLabelDismiss = 'Dismiss';

/// Raw color palette replacing Material `Colors.*` references.
///
/// These values mirror the Material Design defaults so existing visuals are
/// preserved while eliminating the dependency on `package:flutter/material.dart`.
class AppPalette {
  // Core
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);

  // Primary hues
  static const Color red = Color(0xFFF44336);
  static const Color blue = Color(0xFF2196F3);
  static const Color blueShade100 = Color(0xFFBBDEFB);
  static const Color green = Color(0xFF4CAF50);
  static const Color orange = Color(0xFFFF9800);
  static const Color yellow = Color(0xFFFFEB3B);
  static const Color purple = Color(0xFF9C27B0);

  // Grey scale (matching Material grey swatch)
  static const Color grey = Color(0xFF9E9E9E);
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);

  // Overlay colors
  /// Semi-transparent black for overlay controls (handles, marching ants, etc.).
  static const Color overlayDark = Color(0xC8000000);

  /// Semi-transparent white for overlay controls (handles, marching ants, etc.).
  static const Color overlayLight = Color(0xC8FFFFFF);

  /// Semi-transparent white used for overlay/dialog border strokes.
  static const Color overlayBorder = Color(0x59FFFFFF);

  /// Semi-transparent black scrim used as dialog barrier background.
  static const Color scrim = Color(0x80000000);
}

/// Non-user-facing key prefix for identifying SVG icons in widget tests.
const String appIconKeyPrefix = 'app_icon_';

/// Application color constants for consistent theming
class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF2196F3); // Light blue
  static const Color secondary = Color(0xFF1976D2); // Blue
  static const Color accent = Color(0xFF42A5F5); // Lighter blue

  // Background colors
  static const Color background = Color(0xFF121212); // Dark background
  static const Color surface = Color(0xFF1E1E1E); // Surface color
  static const Color surfaceVariant = Color(0xFF2D2D2D); // Variant surface

  // Panel colors
  static const Color panelBackground = Color(0xFF2D2D2D); // Side panel background
  static const Color divider = Color(0xFF424242); // Divider color

  // Button colors
  static const Color floatingButtonBackground = Color(0xFF424242); // Floating button background
  static const Color floatingButtonForeground = AppPalette.white;

  // ITU-R BT.601 luma coefficients for perceived brightness
  static const double lumaRedWeight = 0.299;
  static const double lumaGreenWeight = 0.587;
  static const double lumaBlueWeight = 0.114;

  // Text colors
  static const Color textPrimary = AppPalette.white;
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textDisabled = Color(0xFF666666);

  // Interactive colors
  static const Color hover = Color(0xFF333333);
  static const Color selected = Color(0xFF2196F3);
  static const Color pressed = Color(0xFF1976D2);
  static const Color layerHiddenWarning = Color.fromARGB(255, 241, 85, 85);

  // Transform handle colors
  static const Color transformCornerHandle = Color(0xFFFF9800);
  static const Color transformEdgeHandle = Color(0xFFFFC107);
}

/// Shared spacing tokens used across dialogs, panels, and controls.
class AppSpacing {
  static const double thin = 2.0;
  static const double xs = 4.0;
  static const double sm = 6.0;
  static const double md = 10.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double xxl = 20.0;
  static const double xxxl = 30.0;
  static const double huge = 40.0;
}

/// Shared corner radius tokens.
class AppRadius {
  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 10.0;
}

/// Shared layout and sizing tokens.
class AppLayout {
  static const double minPanelExtent = 100.0;
  static const double sidePanelCollapsed = 100.0;
  static const double sidePanelExpanded = 400.0;
  static const double sidePanelExpandedMin = 350.0;
  static const double sidePanelExpandedMax = 600.0;
  static const double sidePanelTopDefault = 200.0;
  static const double modalSheetMaxHeightFactor = 0.9;
  static const double mobileMenuWidthFactor = 0.85;
  static const int overlayAlpha = 128;
  static const double desktopBreakpoint = 600.0;
  static const double appIconSize = 100.0;
  static const double dialogWidth = 400.0;
  static const double sliderDialogWidth = 600.0;
  static const double effectBottomSheetMaxWidth = 500.0;
  static const double platformPageWidth = 400.0;
  static const double loaderRadius = 40.0;
  static const double loaderStrokeWidth = 4.0;
  static const double layerPreviewSize = 60.0;
  static const double layerPreviewCompactSize = 50.0;
  static const double toolbarButtonSize = 50.0;
  static const double toolbarButtonWidth = 60.0;
  static const double iconSize = 24.0;
  static const double sliderHeight = 30.0;
  static const double gridSelectorSize = 120.0;
  static const double previewRegionSize = 100.0;
  static const double magnifierWidgetWidth = 50.0;
  static const double magnifierTargetSize = 30.0;
  static const double canvasDefaultWidth = 1024.0;
  static const double canvasDefaultHeight = 768.0;
  static const double desktopWindowWidth = 1200.0;
  static const double desktopWindowHeight = 900.0;
  static const double integrationTestTabletLandscapeWidth = 1600.0;
  static const double integrationTestTabletLandscapeHeight = 800.0;
  static const double thumbnailMaxHeight = 64.0;
  static const double shortcutGroupWidth = 250.0;
  static const double separatorHeight = 15.0;
  static const double inputFieldWidth = 150.0;
  static const double gradientStopPositionFieldWidth = 52.0;
  static const int textLengthThreshold = 50;
  static const double textMaxWidthCompact = 800.0;
  static const double textMaxWidthNormal = 1000.0;
}

/// Shared font size tokens for consistent typography across the app.
class AppFontSize {
  /// Small text — tooltips, subtitles, truncated file names, hints.
  static const double small = 10.0;

  /// Medium text — body content, slider labels, descriptions, info readouts.
  static const double medium = 12.0;

  /// Large text — page titles, dialog titles, buttons, list tile titles, inputs.
  static const double large = 15.0;
}

/// Shared text style constants for consistent typography.
///
/// Styles are named by semantic role and follow a 3-tier size system
/// (small / medium / large) combined with normal or bold weight.
class AppTextStyle {
  /// Titles, headings, list tiles, text fields — large bold white.
  static const TextStyle title = TextStyle(
    fontFamily: appFontFamily,
    color: AppPalette.white,
    fontSize: AppFontSize.large,
    fontWeight: FontWeight.bold,
  );

  /// Default body text — white, inherits size from parent.
  static const TextStyle body = TextStyle(
    fontFamily: appFontFamily,
    color: AppPalette.white,
  );

  /// Emphasized body text — medium bold, inherits color from parent.
  static const TextStyle bodyBold = TextStyle(
    fontFamily: appFontFamily,
    fontSize: AppFontSize.medium,
    fontWeight: FontWeight.bold,
  );

  /// Tooltips, overlay coordinates — small white.
  static const TextStyle label = TextStyle(
    fontFamily: appFontFamily,
    color: AppPalette.white,
    fontSize: AppFontSize.small,
  );

  /// Subtitles, list-tile descriptions, blend-mode hints — medium secondary.
  static const TextStyle subtitle = TextStyle(
    fontFamily: appFontFamily,
    color: AppColors.textSecondary,
    fontSize: AppFontSize.small,
  );

  /// Interactive elements — blue accent color, large font.
  static const TextStyle button = TextStyle(
    fontFamily: appFontFamily,
    color: AppPalette.blue,
    fontSize: AppFontSize.large,
  );
}

/// Shared divider and border tokens.
class AppStroke {
  static const double thin = 1.0;
  static const double regular = 2.0;
  static const double emphasis = 3.0;
  static const double divider = 6.0;
  static const double dividerHighlighted = 8.0;

  /// Dash-width multiplier relative to brush size for dashed patterns.
  static const double dashWidthFactor = 3.0;

  /// Gap multiplier relative to brush size for dashed patterns.
  static const double dashGapFactor = 2.0;
}

/// Shared scale tokens.
class AppVisual {
  static const double full = 1.0;
  static const double half = 0.5;
  static const double popupBorderAlpha = 0.35;
  static const double low = 0.3;
  static const double medium = 0.7;
  static const double disabled = 0.8;
  static const double fitToContainerScale = 0.95;
  static const double shrink = 0.9;
  static const double enlarge = 1.1;
  static const double iconScale = 1.2;
  static const double previewTextScale = 1.5;
}

/// Shared numeric bounds and percentage-based tokens.
class AppLimits {
  static const int rgbChannelMax = 255;
  static const int percentMax = 100;
  static const int topColorCount = 20;
  static const int brushSizeMax = 200;
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
  static const int maxRecentFiles = 10;
  static const int recentFilesDisplayCount = 5;
}

/// Shared geometry and math helpers for repeated factors.
class AppMath {
  /// Offset for red channel in RGBA pixel data.
  static const int rgbChannelRed = 0;

  /// Offset for green channel in RGBA pixel data.
  static const int rgbChannelGreen = 1;

  /// Offset for blue channel in RGBA pixel data.
  static const int rgbChannelBlue = 2;

  static const double degrees60 = 60.0;
  static const double degrees120 = 120.0;
  static const double degrees180 = 180.0;
  static const double degrees240 = 240.0;
  static const double degrees300 = 300.0;
  static const int zero = 0;
  static const int two = 2;
  static const int four = 4;
  static const int six = 6;
  static const int pair = 2;
  static const int triple = 3;
  static const int bytesPerPixel = 4;
  static const int baseTen = 10;
  static const int hexRadix = 16;
  static const int hexPad = 2;
  static const double smallPercentage = 0.1;
  static const double degreesPerHalfTurn = 180.0;
  static const double degreesPerFullTurn = 360.0;
  static const double percentScale = 100.0;
  static const double tinyPercentage = 0.01;

  /// Approximation of π used for radian/degree conversions.
  static const double pi = 3.14159;

  /// Angle increment for rotation snap haptic feedback.
  static const double rotationSnapInterval = 45.0;

  /// Scale percentage increment for scale snap haptic feedback.
  static const double scaleSnapInterval = 25.0;
}

/// Shared fill and gesture tuning values.
class AppInteraction {
  static const double minCanvasScale = 0.1;
  static const double maxCanvasScale = 10.0;
  static const double multiTouchScaleThreshold = 50.0;
  static const double linearFillHandleOffset = 40.0;
  static const double radialFillHandleOffset = 50.0;
  static const double magnifierScale = 6.0;
  static const double magnifierImageScale = 8.0;
  static const double selectionHandleSize = 20;
  static const double rotationHandleDistance = 30.0;
  static const double rotationHandleSize = 16.0;
  static const double rotationHandleLineWidth = 1.5;
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

/// Constants for selection region effects.
class AppEffects {
  /// Gaussian blur sigma for the blur effect.
  static const double blurSigma = 6.0;

  /// Gaussian blur sigma for the soften (edge softener) effect.
  static const double softenSigma = 2.0;

  /// Gaussian blur sigma used as the base for the sharpen (unsharp-mask) effect.
  static const double sharpenBlurSigma = 1.5;

  /// Strength multiplier for the unsharp-mask sharpen effect.
  static const double sharpenAmount = 1.5;

  /// Downscale factor for the pixelation effect (pixels are grouped into blocks).
  static const int pixelateBlockSize = 8;

  /// Total range of random noise values added to each channel.
  static const int noiseRange = 51;

  /// Offset subtracted from the random noise to center it around zero.
  static const int noiseOffset = 25;

  /// Number of color channels processed (R, G, B — alpha is preserved).
  static const int rgbChannelCount = 3;

  /// Byte index of the alpha channel within an RGBA pixel.
  static const int alphaChannelIndex = 3;

  /// Strength of the vignette darkening at the edges (0 = none, 1 = full black).
  static const double vignetteStrength = 0.75;

  /// Maximum brightness offset added per channel (0–255 scale).
  static const int brightnessOffset = 100;

  /// Maximum contrast multiplier applied to each channel.
  static const double contrastMax = 2.0;

  /// Maximum hue rotation in degrees.
  static const double hueRotationMax = 180.0;

  /// Degrees in a full hue rotation.
  static const double hueFullCircle = 360.0;

  /// Maximum shadow darkening strength.
  static const double shadowDarkening = 0.6;

  /// Shadow midtone threshold (0–255), below which darkening is applied.
  static const int shadowMidtone = 128;

  /// ITU-R BT.601 luma coefficient for the red channel.
  static const double lumaRed = 0.2126;

  /// ITU-R BT.601 luma coefficient for the green channel.
  static const double lumaGreen = 0.7152;

  /// ITU-R BT.601 luma coefficient for the blue channel.
  static const double lumaBlue = 0.0722;

  /// Default effect intensity shown to the user when the slider first opens (full effect).
  static const double defaultIntensity = 1.0;

  /// Minimum effect intensity (no visible change).
  static const double minIntensity = 0.0;

  /// Maximum effect intensity (full effect as authored).
  static const double maxIntensity = 1.0;
}

/// Shared persisted/default app values.
class AppDefaults {
  static const double brushSize = 5.0;
  static const int tolerance = 50;
  static const bool useApplePencil = false;
  static const Duration buttonTapAnimationDuration = Duration(milliseconds: 100);
  static const Duration toolPanelRevealAnimationDuration = Duration(milliseconds: 140);
  static const Duration debounceDuration = Duration(seconds: 1);
  static const Duration animationLoopDuration = Duration(seconds: 1);
  static const Duration clipboardAccessTimeout = Duration(seconds: 2);
  static const Duration recoverySaveDebounce = Duration(seconds: 2);
  static const Duration integrationEvidenceCollectionDelay = Duration(seconds: 2);
  static const Duration integrationVisualCheckpointDelay = Duration(milliseconds: 700);
  static const Duration fileImportFeedbackDuration = Duration(seconds: AppMath.triple);
  static const int integrationEvidenceJpegQuality = 95;
  static const double renderedScreenshotPixelRatio = 1.0;
}

/// File extension identifiers used across import/export/save operations.
class FileExtensions {
  static const String png = 'png';
  static const String jpg = 'jpg';
  static const String jpeg = 'jpeg';
  static const String webp = 'webp';
  static const String ora = 'ora';
  static const String tif = 'tif';
  static const String tiff = 'tiff';
  static const String heic = 'heic';
}

/// Shared widget keys used by tests and UI lookups across the app.
class Keys {
  static const Key floatActionSelector = Key('floating_action_selector');
  static const Key floatActionUndo = Key('floating_action_undo');
  static const Key floatActionRedo = Key('floating_action_redo');
  static const Key floatActionMenuToggle = Key('floating_action_menu_toggle');
  static const Key floatActionZoomIn = Key('floating_action_zoom_in');
  static const Key floatActionZoomOut = Key('floating_action_zoom_out');
  static const Key floatActionCenter = Key('floating_action_center');
  static const Key floatActionToggle = Key('floating_action_toggle');
  static const Key mainMenuButton = Key('main-menu-button');
  static const Key mainMenuCanvasSize = Key('main-menu-canvas-size');
  static const Key sidePanelExportButton = Key('side-panel-export-button');
  static const Key appScreenshotBoundary = Key('app-screenshot-boundary');
  static const Key mainViewScreenshotBoundary = Key('main-view-screenshot-boundary');
  static const String gradientHandleKeyPrefixText = 'gradient_handle_';
  static const Key layerAddAboveButton = Key('layer-add-above-button');
  static const Key layerRenameTextField = Key('layer-rename-text-field');
  static const Key layerRenameApplyButton = Key('layer-rename-apply-button');
  static const Key canvasSettingsWidthField = Key('canvas-settings-width-field');
  static const Key canvasSettingsHeightField = Key('canvas-settings-height-field');
  static const Key canvasSettingsAspectRatioToggleButton = Key('canvas-settings-aspect-ratio-toggle-button');
  static const Key canvasSettingsApplyButton = Key('canvas-settings-apply-button');
  static const Key textEditorBoldButton = Key('text-editor-bold-button');
  static const Key textEditorItalicButton = Key('text-editor-italic-button');
  static const Key textEditorAlignmentDropdown = Key('text-editor-alignment-dropdown');
  static const Key magnifyingEyeDropperCloseButton = Key('magnifying-eye-dropper-close-button');
  static const Key magnifyingEyeDropperConfirmButton = Key('magnifying-eye-dropper-confirm-button');

  static const Key toolLine = Key('tool-line');
  static const Key toolRectangle = Key('tool-rectangle');
  static const Key toolCircle = Key('tool-circle');
  static const Key toolText = Key('tool-text');

  static const Key toolFill = Key('tool-fill');
  static const Key toolFillModeSolid = Key('tool-fill-mode-solid');
  static const Key toolFillModeLinear = Key('tool-fill-mode-linear');
  static const Key toolFillModeRadial = Key('tool-fill-mode-radial');

  static const Key toolSelector = Key('tool-selector');
  static const Key toolSelectorModeRectangle = Key('tool-selector-mode-rectangle');
  static const Key toolSelectorModeCircle = Key('tool-selector-mode-circle');
  static const Key toolSelectorModeLasso = Key('tool-selector-mode-lasso');
  static const Key toolSelectorModeWand = Key('tool-selector-mode-wand');
  static const Key toolSelectorCancel = Key('tool-selector-cancel');

  static const Key toolPanelFillColor = Key('toolPanelFillColor');
  static const Key toolPanelBrushColor1 = Key('toolPanelBrushColor1');
  static const Key toolPanelFontColor = Key('toolPanelFontColor');
  static const String gradientStopColorKeyPrefixText = 'gradient_stop_color_';
  static const Key gradientStopAddButton = Key('gradient_stop_add');
  static const String gradientStopPositionKeyPrefixText = 'gradient_stop_pos_';
  static const Key toolTransform = Key('tool-transform');

  static const Key effectsButton = Key('effects-button');
  static const Key effectIntensityPanelApplyButton = Key('effect-intensity-panel-apply-button');
  static const Key effectIntensityApplyButton = Key('effect-intensity-apply-button');
  static const Key effectIntensityCancelButton = Key('effect-intensity-cancel-button');
  static const Key effectIntensitySlider = Key('effect-intensity-slider');
  static const Key effectIntensityDialogSlider = Key('effect-intensity-dialog-slider');

  static const Key toolBrushSizeTool = Key('tool-brush-size-tool');
  static const Key toolBrushSizeButton = Key('tool-brush-size-button');
  static const Key toolBrushSizeSlider = Key('tool-brush-size-slider');
}
