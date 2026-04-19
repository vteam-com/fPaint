// ignore: fcheck_one_class_per_file
// ignore: fcheck_magic_numbers
import 'package:flutter/material.dart';

/// The application display name.
const String appName = 'fPaint';

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
  static const double layerTitleFontSize = 13.0;
  static const double platformTitleFontSize = 18.0;
  static const double inputFieldWidth = 150.0;
}

/// SVG asset paths for app icons (non-user-facing).
class AppIconAssets {
  static const String arrowDown = 'assets/icons/arrow_down.svg';
  static const String arrowDownLeft = 'assets/icons/arrow_down_left.svg';
  static const String arrowDownRight = 'assets/icons/arrow_down_right.svg';
  static const String arrowDropDown = 'assets/icons/arrow_drop_down.svg';
  static const String arrowLeft = 'assets/icons/arrow_left.svg';
  static const String arrowRight = 'assets/icons/arrow_right.svg';
  static const String arrowUp = 'assets/icons/arrow_up.svg';
  static const String arrowUpLeft = 'assets/icons/arrow_up_left.svg';
  static const String arrowUpRight = 'assets/icons/arrow_up_right.svg';
  static const String autoFixHigh = 'assets/icons/auto_fix_high.svg';
  static const String blender = 'assets/icons/blender.svg';
  static const String brush = 'assets/icons/brush.svg';
  static const String canvasCrop = 'assets/icons/crop.svg';
  static const String check = 'assets/icons/check.svg';
  static const String checkCircle = 'assets/icons/check_circle.svg';
  static const String circle = 'assets/icons/circle.svg';
  static const String close = 'assets/icons/close.svg';
  static const String colorLens = 'assets/icons/color_lens.svg';
  static const String colorize = 'assets/icons/colorize.svg';
  static const String contentPasteGo = 'assets/icons/content_paste_go.svg';
  static const String copy = 'assets/icons/copy.svg';
  static const String create = 'assets/icons/create.svg';
  static const String cropFree = 'assets/icons/crop_free.svg';
  static const String cropSquare = 'assets/icons/crop_square.svg';
  static const String download = 'assets/icons/download.svg';
  static const String edit = 'assets/icons/edit.svg';
  static const String fileDownload = 'assets/icons/file_download.svg';
  static const String flipHorizontal = 'assets/icons/flip_horizontal.svg';
  static const String flipVertical = 'assets/icons/flip_vertical.svg';
  static const String fontDownload = 'assets/icons/font_download.svg';
  static const String formatBold = 'assets/icons/format_bold.svg';
  static const String formatColorFill = 'assets/icons/format_color_fill.svg';
  static const String formatItalic = 'assets/icons/format_italic.svg';
  static const String formatSize = 'assets/icons/format_size.svg';
  static const String highlightAlt = 'assets/icons/highlight_alt.svg';
  static const String image = 'assets/icons/image.svg';
  static const String info = 'assets/icons/info.svg';
  static const String iosShare = 'assets/icons/ios_share.svg';
  static const String keyboardDoubleArrowLeft = 'assets/icons/keyboard_double_arrow_left.svg';
  static const String keyboardDoubleArrowRight = 'assets/icons/keyboard_double_arrow_right.svg';
  static const String layers = 'assets/icons/layers.svg';
  static const String lineAxis = 'assets/icons/line_axis.svg';
  static const String lineStyle = 'assets/icons/line_style.svg';
  static const String lineWeight = 'assets/icons/line_weight.svg';
  static const String link = 'assets/icons/link.svg';
  static const String linkOff = 'assets/icons/link_off.svg';
  static const String menu = 'assets/icons/menu.svg';
  static const String moreVert = 'assets/icons/more_vert.svg';
  static const String openInFull = 'assets/icons/open_in_full.svg';
  static const String outbound = 'assets/icons/outbound.svg';
  static const String paste = 'assets/icons/paste.svg';
  static const String playlistAdd = 'assets/icons/playlist_add.svg';
  static const String playlistRemove = 'assets/icons/playlist_remove.svg';
  static const String powerSettingsNew = 'assets/icons/power_settings_new.svg';
  static const String redo = 'assets/icons/redo.svg';
  static const String refresh = 'assets/icons/refresh.svg';
  static const String rotate90DegreesCw = 'assets/icons/rotate_90_degrees_cw.svg';
  static const String rotateRight = 'assets/icons/rotate_right.svg';
  static const String settings = 'assets/icons/settings.svg';
  static const String square = 'assets/icons/square.svg';
  static const String support = 'assets/icons/support.svg';
  static const String undo = 'assets/icons/undo.svg';
  static const String visibility = 'assets/icons/visibility.svg';
  static const String visibilityOff = 'assets/icons/visibility_off.svg';
  static const String zoomIn = 'assets/icons/zoom_in.svg';
  static const String zoomOut = 'assets/icons/zoom_out.svg';
}

/// SVG asset paths for tool icons (non-user-facing).
class AppToolIconAssets {
  static const String eraser = 'assets/icons/eraser.svg';
  static const String fillLinear = 'assets/icons/fill_linear.svg';
  static const String fillRadial = 'assets/icons/fill_radial.svg';
  static const String lasso = 'assets/icons/lasso.svg';
  static const String selectorAdd = 'assets/icons/selector_add.svg';
  static const String selectorInvert = 'assets/icons/selector_invert.svg';
  static const String selectorRemove = 'assets/icons/selector_remove.svg';
  static const String selectorReplace = 'assets/icons/selector_replace.svg';
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

/// TIFF 6.0 specification constants used by the custom encoder.
class TiffConstants {
  // -- Byte-order marks --------------------------------------------------
  /// Little-endian byte-order mark ('II').
  static const int byteOrderLE1 = 0x49; // 'I'
  static const int byteOrderLE2 = 0x49; // 'I'

  /// TIFF magic number (always 42).
  static const int magic = 42;

  // -- IFD value types ----------------------------------------------------
  /// IFD value type: unsigned 8-bit integer.
  static const int typeByte = 1;

  /// IFD value type: unsigned 16-bit integer.
  static const int typeShort = 3;

  /// IFD value type: unsigned 32-bit integer.
  static const int typeLong = 4;

  /// IFD value type: unsigned rational (two LONGs: numerator / denominator).
  static const int typeRational = 5;

  // -- Tag IDs ------------------------------------------------------------
  /// Tag 256 – ImageWidth.
  static const int tagImageWidth = 256;

  /// Tag 257 – ImageHeight.
  static const int tagImageHeight = 257;

  /// Tag 258 – BitsPerSample.
  static const int tagBitsPerSample = 258;

  /// Tag 259 – Compression (1 = none).
  static const int tagCompression = 259;

  /// Tag 262 – PhotometricInterpretation (2 = RGB).
  static const int tagPhotometricInterpretation = 262;

  /// Tag 266 – FillOrder.
  static const int tagFillOrder = 266;

  /// Tag 273 – StripOffsets.
  static const int tagStripOffsets = 273;

  /// Tag 274 – Orientation.
  static const int tagOrientation = 274;

  /// Tag 277 – SamplesPerPixel.
  static const int tagSamplesPerPixel = 277;

  /// Tag 278 – RowsPerStrip.
  static const int tagRowsPerStrip = 278;

  /// Tag 279 – StripByteCounts.
  static const int tagStripByteCounts = 279;

  /// Tag 282 – XResolution (horizontal DPI as RATIONAL).
  static const int tagXResolution = 282;

  /// Tag 283 – YResolution (vertical DPI as RATIONAL).
  static const int tagYResolution = 283;

  /// Tag 284 – PlanarConfiguration (1 = chunky / interleaved).
  static const int tagPlanarConfiguration = 284;

  /// Tag 285 – PageName (layer name in layered TIFF SubIFDs).
  static const int tagPageName = 285;

  /// Tag 286 – XPosition.
  static const int tagXPosition = 286;

  /// Tag 287 – YPosition.
  static const int tagYPosition = 287;

  /// Tag 296 – ResolutionUnit.
  static const int tagResolutionUnit = 296;

  /// Tag 297 – PageNumber (page index and total count, two SHORTs).
  static const int tagPageNumber = 297;

  /// Tag 305 – Software.
  static const int tagSoftware = 305;

  /// Tag 316 – HostComputer.
  static const int tagHostComputer = 316;

  /// Tag 317 – Predictor.
  static const int tagPredictor = 317;

  /// Tag 330 – SubIFD.
  static const int tagSubIfd = 330;

  /// Tag 338 – ExtraSamples.
  static const int tagExtraSamples = 338;

  /// Tag 339 – SampleFormat.
  static const int tagSampleFormat = 339;

  /// Private SketchBook tag for layer model metadata.
  static const int tagSketchBookLayerModel = 50784;

  /// Private SketchBook tag for layer flags.
  static const int tagSketchBookLayerFlags = 50787;

  /// Private SketchBook tag for layer-name bytes.
  static const int tagSketchBookLayerName = 50788;

  /// Private SketchBook tag for application version.
  static const int tagSketchBookVersion = 50790;

  // -- Fixed tag values ---------------------------------------------------
  /// Compression value: no compression.
  static const int compressionNone = 1;

  /// Compression value: LZW.
  static const int compressionLzw = 5;

  /// PhotometricInterpretation value: RGB.
  static const int photometricRgb = 2;

  /// FillOrder value: most-significant bit to least-significant bit.
  static const int fillOrderMsbToLsb = 1;

  /// PlanarConfiguration value: chunky (RGBARGBA…).
  static const int planarChunky = 1;

  /// Predictor value: horizontal differencing.
  static const int predictorHorizontalDifferencing = 2;

  /// ExtraSamples value: associated alpha.
  static const int extraSamplesAssociatedAlpha = 1;

  /// ExtraSamples value: unassociated (straight) alpha.
  static const int extraSamplesUnassociatedAlpha = 2;

  /// Orientation value: row 0 top, column 0 left.
  static const int orientationTopLeft = 1;

  /// Orientation value: row 0 bottom, column 0 left.
  static const int orientationBottomLeft = 4;

  /// Bits per channel for 8-bit images.
  static const int bitsPerChannel = 8;

  /// ResolutionUnit value: inch.
  static const int resolutionUnitInch = 2;

  /// SampleFormat value: unsigned integer channels.
  static const int sampleFormatUnsignedInteger = 1;

  /// Default DPI numerator for XResolution / YResolution.
  static const int defaultDpi = 72;

  /// Default DPI denominator for XResolution / YResolution.
  static const int dpiDenominator = 1;

  /// RGB channel count (3).
  static const int rgbChannelCount = 3;

  /// RGBA channel count (4).
  static const int rgbaChannelCount = 4;

  // -- Structural sizes ---------------------------------------------------
  /// Size of the TIFF header in bytes.
  static const int headerSize = 8;

  /// Size of a single IFD entry in bytes.
  static const int ifdEntrySize = 12;

  /// Size of the "next IFD offset" field in bytes.
  static const int nextIfdSize = 4;

  /// Size of the IFD entry-count field in bytes.
  static const int ifdCountSize = 2;

  /// Size of a single RATIONAL value in bytes (two uint32).
  static const int rationalSize = 8;

  /// Total size of resolution data: two RATIONAL values (XRes + YRes).
  static const int resolutionDataSize = 16;

  /// Width of a SHORT value in bits, used for packing PageNumber.
  static const int shortBitWidth = 16;

  /// Shared zero/default value used for TIFF offsets and flag payloads.
  static const int noValue = 0;

  /// Number of SHORT values in a PageNumber tag entry (page index + total).
  static const int pageNumberCount = 2;

  /// Number of SketchBook layer flag slots in tag 50787.
  static const int sketchBookLayerFlagsCount = 8;

  /// Number of IFD entries for a base RGB image (includes resolution tags).
  static const int ifdEntryCountRgb = 13;

  /// Number of IFD entries for a base RGBA image (includes ExtraSamples).
  static const int ifdEntryCountRgba = 14;

  /// Number of IFD entries for an RGB layer page
  /// (adds ImageDescription + NewSubfileType + PageName + PageNumber).
  static const int ifdEntryCountRgbLayer = 18;

  /// Number of IFD entries for an RGBA layer page.
  static const int ifdEntryCountRgbaLayer = 19;

  /// IFD value type: ASCII string.
  static const int typeAscii = 2;

  /// Tag 254 – NewSubfileType.
  static const int tagNewSubfileType = 254;

  /// Tag 270 – ImageDescription (stores the layer name).
  static const int tagImageDescription = 270;

  /// Tag 272 – Model.
  static const int tagModel = 272;

  /// NewSubfileType value: page of a multi-page image.
  static const int subfileTypePage = 2;

  /// NewSubfileType value: reduced-resolution image.
  static const int subfileTypeReducedResolution = 1;

  /// SketchBook preview name used for the root thumbnail SubIFD.
  static const String pageNameThumbnail = 'Thumbnail';

  /// SketchBook software marker written on the root layered TIFF image.
  static const String sketchBookSoftware = 'Alias MultiLayer TIFF V1.1';

  /// SketchBook application version marker written on the root layered TIFF.
  static const String sketchBookVersion = 'V1_Mac_SketchBook_8.7.1';

  /// SketchBook-style root model payload written on the root TIFF image.
  static const String sketchBookRootModelPayload =
      '003, 003, ffffffff, 001, 1, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000';

  /// SketchBook-style layer model payload written on each layer SubIFD.
  static const String sketchBookLayerModelPayload = '1.000, 00000000, 1, 0, 1, 0, 161, 0, 0, 0, 00000';

  /// SketchBook-style layer flags payload written on each layer SubIFD.
  static const String sketchBookLayerFlagsPayload = '0, 0, 0, 0, 0, 0, 0, 0';

  /// Fixed-point denominator used by SketchBook for layer positions.
  static const int sketchBookPositionDenominator = 262144;

  /// Fallback prefix for imported TIFF layers without embedded names.
  static const String fallbackLayerNamePrefix = 'Layer';

  /// Separator between the fallback layer prefix and numeric suffix.
  static const String fallbackLayerNameSeparator = ' ';

  // -- Layer metadata JSON keys -------------------------------------------
  /// JSON key for the layer name in the ImageDescription payload.
  static const String metaKeyName = 'name';

  /// JSON key for the layer opacity (0.0–1.0) in the ImageDescription payload.
  static const String metaKeyOpacity = 'opacity';

  /// JSON key for the layer blend mode in the ImageDescription payload.
  static const String metaKeyBlendMode = 'blendMode';

  /// JSON key for layer visibility in the ImageDescription payload.
  static const String metaKeyVisible = 'visible';

  /// Public `package:image` type string for ASCII TIFF values.
  static const String ifdValueTypeAscii = 'ascii';
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
  static Key mainMenuButton = const Key('main-menu-button');
  static Key mainMenuCanvasSize = const Key('main-menu-canvas-size');
  static Key appScreenshotBoundary = const Key('app-screenshot-boundary');
  static Key mainViewScreenshotBoundary = const Key('main-view-screenshot-boundary');
  static String gradientHandleKeyPrefixText = 'gradient_handle_';
  static Key layerAddAboveButton = const Key('layer-add-above-button');
  static Key layerRenameTextField = const Key('layer-rename-text-field');
  static Key layerRenameApplyButton = const Key('layer-rename-apply-button');
  static Key canvasSettingsWidthField = const Key('canvas-settings-width-field');
  static Key canvasSettingsHeightField = const Key('canvas-settings-height-field');
  static Key canvasSettingsApplyButton = const Key('canvas-settings-apply-button');

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
