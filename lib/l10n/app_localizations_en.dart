// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get about => 'About...';

  @override
  String get activeTool => 'Active tool';

  @override
  String get addText => 'Add Text';

  @override
  String get apply => 'Apply';

  @override
  String get availablePlatforms => 'Available Platforms';

  @override
  String get blendModeColorBurnDescription =>
      'Darkens the destination by increasing contrast based on the source color.';

  @override
  String get blendModeColorDescription =>
      'Uses the source\'s hue and saturation, but keeps the destination\'s luminance.';

  @override
  String get blendModeColorDodgeDescription =>
      'Brightens the destination by reducing contrast based on the source color.';

  @override
  String get blendModeDarkenDescription => 'Keeps the darker color of the source and destination pixels.';

  @override
  String get blendModeHardLightDescription =>
      'Applies multiply or screen based on the source color\'s intensity, creating a strong contrast.';

  @override
  String get blendModeHueDescription => 'Uses the source\'s hue and the destination\'s saturation and luminance.';

  @override
  String get blendModeLightenDescription => 'Keeps the lighter color of the source and destination pixels.';

  @override
  String get blendModeLinearDodgeDescription => 'Adds the source and destination colors, clamping at white.';

  @override
  String get blendModeLuminosityDescription =>
      'Uses the source\'s luminance and the destination\'s hue and saturation.';

  @override
  String get blendModeMultiplyDescription =>
      'Multiplies the source and destination colors, resulting in a darker output.';

  @override
  String get blendModeNormalDescription => 'Places the source image over the destination without blending.';

  @override
  String get blendModeNormalLabel => 'Normal';

  @override
  String get blendModeOverlayDescription =>
      'Combines multiply and screen modes: darkens dark areas, and lightens light areas.';

  @override
  String get blendModeSaturationDescription =>
      'Uses the source\'s saturation and the destination\'s hue and luminance.';

  @override
  String get blendModeScreenDescription =>
      'Multiplies the inverses of the source and destination, resulting in a lighter output.';

  @override
  String get blendModeSoftLightDescription =>
      'Softens the contrast by darkening or lightening the destination depending on the source.';

  @override
  String get brush => 'Brush';

  @override
  String get brushStyle => 'Brush Style';

  @override
  String get cancel => 'Cancel';

  @override
  String get canvas => 'Canvas...';

  @override
  String get canvasDimensionsMustBePositive => 'Canvas dimensions must be positive.';

  @override
  String get canvasSizeTitle => 'Canvas Size';

  @override
  String get colorLabel => 'Color';

  @override
  String get colorTolerance => 'Color Tolerance';

  @override
  String colorUsage(Object percentage) {
    return 'Usage $percentage';
  }

  @override
  String get contentAlignment => 'Content Alignment';

  @override
  String get copyToClipboard => 'Copy to clipboard';

  @override
  String get create => 'Create';

  @override
  String degreesValue(Object value) {
    return '$value°';
  }

  @override
  String get delete => 'Delete';

  @override
  String get desktopSoftware => 'Desktop Software.';

  @override
  String deviceScreenResolution(Object resolution) {
    return 'Device Screen Resolution: $resolution';
  }

  @override
  String dimensionsValue(Object width, Object height) {
    return '$width × $height';
  }

  @override
  String get discard => 'Discard';

  @override
  String get discardAndOpen => 'Discard and Open';

  @override
  String get discardCurrentDocumentQuestion => 'Discard current document?';

  @override
  String get dropFileAddLayer => 'Add as New Layer';

  @override
  String get dropFileOpen => 'Open File';

  @override
  String get dropFilePrompt => 'Would you like to add this as a new layer or open the file?';

  @override
  String get dropFileTitle => 'File Dropped';

  @override
  String downloadAsFile(Object fileName) {
    return 'Download as $fileName';
  }

  @override
  String get editText => 'Edit Text';

  @override
  String get enterYourTextHere => 'Enter your text here...';

  @override
  String errorProcessingFile(Object error) {
    return 'Error processing file: $error';
  }

  @override
  String errorReadingFile(Object error) {
    return 'Error reading file: $error';
  }

  @override
  String get exportLabel => 'Export...';

  @override
  String get exportTooltip => 'Export...';

  @override
  String failedToLoadImage(Object error) {
    return 'Failed to load image: $error';
  }

  @override
  String fileFormatNotSupported(Object extension) {
    return 'File format .$extension is not supported';
  }

  @override
  String get fontColor => 'Font Color';

  @override
  String get fontSizeLabel => 'Font Size';

  @override
  String fontSizeValue(Object value) {
    return 'Font Size: $value';
  }

  @override
  String get fpaintLoadImage => 'fPaint Load Image';

  @override
  String get githubRepo => 'GitHub Repo';

  @override
  String get gradientPointColor => 'Gradient Point Color';

  @override
  String get height => 'Height';

  @override
  String get hexColor => 'Hex Color';

  @override
  String get hexColorCopiedToClipboard => 'Hex Color copied to clipboard';

  @override
  String get importLabel => 'Import...';

  @override
  String get importTooltip => 'Import...';

  @override
  String get invalidImageSizeDimensionsMustBeNumbers => 'Invalid image size: Dimensions must be numbers.';

  @override
  String get invalidSize => 'Invalid size';

  @override
  String get keyboardShortcuts => 'Keyboard Shortcuts';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'French';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get languageSubtitle => 'Choose app language or follow system';

  @override
  String get languageSystem => 'System default';

  @override
  String get menuTooltip => 'Menu';

  @override
  String get mobileApp => 'Mobile app.';

  @override
  String get newCanvasSize => 'New Canvas Size';

  @override
  String get newFromClipboard => 'New from Clipboard';

  @override
  String get no => 'No';

  @override
  String get paste => 'Paste';

  @override
  String percentageValue(Object value) {
    return '$value%';
  }

  @override
  String get platforms => 'Available on...';

  @override
  String get resizeRotate => 'Resize / Rotate';

  @override
  String get flipHorizontalTooltip => 'Flip Horizontal';

  @override
  String get flipVerticalTooltip => 'Flip Vertical';

  @override
  String get rotateCanvasTooltip => 'Rotate Canvas 90° CW';

  @override
  String get runOnMostBrowsers => 'Run on any OS with most browsers.';

  @override
  String saveAsFile(Object fileName) {
    return 'Save as $fileName';
  }

  @override
  String savedMessage(Object fileName) {
    return 'Saved $fileName';
  }

  @override
  String get saveLabel => 'Save';

  @override
  String get scale => 'Scale';

  @override
  String get selectionIsHidden => 'Selection is hidden.';

  @override
  String selectValue(Object value) {
    return 'Select $value';
  }

  @override
  String get settings => 'Settings...';

  @override
  String get startOver => 'Start new...';

  @override
  String get startOverTooltip => 'Start new...';

  @override
  String get textColor => 'Text Color';

  @override
  String get tolerance => 'Tolerance';

  @override
  String topColors(Object count) {
    return 'Top $count colors';
  }

  @override
  String get transform => 'Transform';

  @override
  String get unsavedChanges => 'Unsaved Changes';

  @override
  String get unsavedChangesDiscardAndOpenPrompt =>
      'You have unsaved changes. Do you want to discard them and open the new file?';

  @override
  String get useApplePencilOnlySubtitle => 'If enabled, only the Apple Pencil will be used for drawing.';

  @override
  String get useApplePencilOnlyTitle => 'Use Apple Pencil Only';

  @override
  String get webBrowser => 'Web Browser';

  @override
  String get width => 'Width';
}
