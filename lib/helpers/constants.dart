// ignore: fcheck_one_class_per_file
// ignore: fcheck_magic_numbers
import 'package:flutter/material.dart';

/// The application display name.
const String appName = 'fPaint';

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
  static const Color floatingButtonForeground = Colors.white;

  // ITU-R BT.601 luma coefficients for perceived brightness
  static const double lumaRedWeight = 0.299;
  static const double lumaGreenWeight = 0.587;
  static const double lumaBlueWeight = 0.114;

  // Text colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textDisabled = Color(0xFF666666);

  // Interactive colors
  static const Color hover = Color(0xFF333333);
  static const Color selected = Color(0xFF2196F3);
  static const Color pressed = Color(0xFF1976D2);
  static const Color layerHiddenWarning = Color.fromARGB(255, 135, 9, 9);

  // Transform handle colors
  static const Color transformCornerHandle = Color(0xFFFF9800);
  static const Color transformEdgeHandle = Color(0xFFFFC107);
}

/// Shared spacing tokens used across dialogs, panels, and controls.
class AppSpacing {
  static const double xxxs = 2.0;
  static const double xxs = 4.0;
  static const double xs = 6.0;
  static const double sm = 8.0;
  static const double md = 10.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double xxl = 20.0;
  static const double xxxl = 30.0;
  static const double huge = 40.0;
  static const double panelMargin = 50.0;
  static const double previewSize = 60.0;
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
  static const double mobileMenuWidthFactor = 0.85;
  static const int overlayAlpha = 128;
  static const double desktopBreakpoint = 600.0;
  static const double appIconSize = 100.0;
  static const double dialogWidth = 400.0;
  static const double sliderDialogWidth = 600.0;
  static const double platformPageWidth = 400.0;
  static const double loaderRadius = 40.0;
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
  static const double layerTitleFontSize = 13.0;
  static const double platformTitleFontSize = 18.0;
  static const double inputFieldWidth = 150.0;
}

/// Shared divider and border tokens.
class AppStroke {
  static const double thin = 1.0;
  static const double regular = 2.0;
  static const double emphasis = 3.0;
  static const double divider = 6.0;
  static const double dividerHighlighted = 8.0;
}

/// Shared scale and opacity tokens.
class AppVisual {
  static const double full = 1.0;
  static const double half = 0.5;
  static const double popupBorderAlpha = 0.35;
  static const double low = 0.3;
  static const double medium = 0.7;
  static const double disabled = 0.8;
  static const double shrink = 0.9;
  static const double enlarge = 1.1;
  static const double iconScale = 1.2;
  static const double titleScale = 1.3;
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
}

/// Shared geometry and math helpers for repeated factors.
class AppMath {
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
  static const int selectionHandleSize = 20;
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

/// Shared persisted/default app values.
class AppDefaults {
  static const double brushSize = 5.0;
  static const int tolerance = 50;
  static const bool useApplePencil = false;
  static const Duration debounceDuration = Duration(seconds: 1);
  static const Duration clipboardAccessTimeout = Duration(seconds: 2);
  static const Duration integrationEvidenceCollectionDelay = Duration(seconds: 2);
  static const Duration integrationVisualCheckpointDelay = Duration(milliseconds: 700);
  static const int integrationEvidenceJpegQuality = 95;
  static const double renderedScreenshotPixelRatio = 1.0;
}

/// File extension identifiers used across import/export/save operations.
class FileExtensions {
  static const String png = 'png';
  static const String jpg = 'jpg';
  static const String jpeg = 'jpeg';
  static const String ora = 'ora';
  static const String tif = 'tif';
  static const String tiff = 'tiff';
}

/// Shared asset paths used across the application.
class AppAssets {
  static const String transformIcon = 'assets/icons/transform.svg';
}

/// Shared widget keys used by tests and UI lookups across the app.
class Keys {
  static Key floatActionZoomIn = const Key('floating_action_zoom_in');
  static Key floatActionZoomOut = const Key('floating_action_zoom_out');
  static Key floatActionCenter = const Key('floating_action_center');
  static Key floatActionToggle = const Key('floating_action_toggle');
  static Key appScreenshotBoundary = const Key('app-screenshot-boundary');
  static Key mainViewScreenshotBoundary = const Key('main-view-screenshot-boundary');
  static String gradientHandleKeyPrefixText = 'gradient_handle_';

  static Key toolFill = const Key('tool-fill');
  static Key toolFillModeSolid = const Key('tool-fill-mode-solid');
  static Key toolFillModeLinear = const Key('tool-fill-mode-linear');
  static Key toolFillModeRadial = const Key('tool-fill-mode-radial');

  static Key toolSelector = const Key('tool-selector');
  static Key toolSelectorModeRectangle = const Key('tool-selector-mode-rectangle');
  static Key toolSelectorModeCircle = const Key('tool-selector-mode-circle');
  static Key toolSelectorModeLasso = const Key('tool-selector-mode-lasso');
  static Key toolSelectorModeWand = const Key('tool-selector-mode-wand');
  static Key toolSelectorCancel = const Key('tool-selector-cancel');

  static Key toolPanelFillColor = const Key('toolPanelFillColor');
  static Key toolPanelBrushColor1 = const Key('toolPanelBrushColor1');
  static Key toolPanelFontColor = const Key('toolPanelFontColor');
  static Key toolTransform = const Key('tool-transform');
}
