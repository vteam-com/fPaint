import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fpaint/l10n/app_localizations_en.dart';
import 'package:fpaint/l10n/app_localizations_es.dart';
import 'package:fpaint/l10n/app_localizations_fr.dart';
import 'package:fpaint/widgets/material_free/app_snackbar.dart';
import 'package:intl/intl.dart' as intl;

// ignore_for_file: type=lint

/// Shared `BuildContext` helpers for localization and transient app messages.
extension AppLocalizationsBuildContextX on BuildContext {
  /// Returns the localized strings for this context.
  AppLocalizations get l10n => AppLocalizations.of(this)!;

  /// Shows a notification overlay message if the context is still mounted.
  void showSnackBarMessage(
    final String message, {
    final Duration? duration,
  }) {
    if (!mounted) {
      return;
    }

    AppNotificationOverlay.show(this, message, duration: duration);
  }
}

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// WidgetsApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('es'), Locale('fr')];

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About...'**
  String get about;

  /// No description provided for @activeTool.
  ///
  /// In en, this message translates to:
  /// **'Active tool'**
  String get activeTool;

  /// No description provided for @addText.
  ///
  /// In en, this message translates to:
  /// **'Add Text'**
  String get addText;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @availablePlatforms.
  ///
  /// In en, this message translates to:
  /// **'Available Platforms'**
  String get availablePlatforms;

  /// No description provided for @blendModeColorBurnDescription.
  ///
  /// In en, this message translates to:
  /// **'Darkens the destination by increasing contrast based on the source color.'**
  String get blendModeColorBurnDescription;

  /// No description provided for @blendModeColorDescription.
  ///
  /// In en, this message translates to:
  /// **'Uses the source\'s hue and saturation, but keeps the destination\'s luminance.'**
  String get blendModeColorDescription;

  /// No description provided for @blendModeColorDodgeDescription.
  ///
  /// In en, this message translates to:
  /// **'Brightens the destination by reducing contrast based on the source color.'**
  String get blendModeColorDodgeDescription;

  /// No description provided for @blendModeDarkenDescription.
  ///
  /// In en, this message translates to:
  /// **'Keeps the darker color of the source and destination pixels.'**
  String get blendModeDarkenDescription;

  /// No description provided for @blendModeHardLightDescription.
  ///
  /// In en, this message translates to:
  /// **'Applies multiply or screen based on the source color\'s intensity, creating a strong contrast.'**
  String get blendModeHardLightDescription;

  /// No description provided for @blendModeHueDescription.
  ///
  /// In en, this message translates to:
  /// **'Uses the source\'s hue and the destination\'s saturation and luminance.'**
  String get blendModeHueDescription;

  /// No description provided for @blendModeLightenDescription.
  ///
  /// In en, this message translates to:
  /// **'Keeps the lighter color of the source and destination pixels.'**
  String get blendModeLightenDescription;

  /// No description provided for @blendModeLinearDodgeDescription.
  ///
  /// In en, this message translates to:
  /// **'Adds the source and destination colors, clamping at white.'**
  String get blendModeLinearDodgeDescription;

  /// No description provided for @blendModeLuminosityDescription.
  ///
  /// In en, this message translates to:
  /// **'Uses the source\'s luminance and the destination\'s hue and saturation.'**
  String get blendModeLuminosityDescription;

  /// No description provided for @blendModeMultiplyDescription.
  ///
  /// In en, this message translates to:
  /// **'Multiplies the source and destination colors, resulting in a darker output.'**
  String get blendModeMultiplyDescription;

  /// No description provided for @blendModeNormalDescription.
  ///
  /// In en, this message translates to:
  /// **'Places the source image over the destination without blending.'**
  String get blendModeNormalDescription;

  /// REVIEWED
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get blendModeNormalLabel;

  /// No description provided for @blendModeOverlayDescription.
  ///
  /// In en, this message translates to:
  /// **'Combines multiply and screen modes: darkens dark areas, and lightens light areas.'**
  String get blendModeOverlayDescription;

  /// No description provided for @blendModeSaturationDescription.
  ///
  /// In en, this message translates to:
  /// **'Uses the source\'s saturation and the destination\'s hue and luminance.'**
  String get blendModeSaturationDescription;

  /// No description provided for @blendModeScreenDescription.
  ///
  /// In en, this message translates to:
  /// **'Multiplies the inverses of the source and destination, resulting in a lighter output.'**
  String get blendModeScreenDescription;

  /// No description provided for @blendModeSoftLightDescription.
  ///
  /// In en, this message translates to:
  /// **'Softens the contrast by darkening or lightening the destination depending on the source.'**
  String get blendModeSoftLightDescription;

  /// No description provided for @brush.
  ///
  /// In en, this message translates to:
  /// **'Brush'**
  String get brush;

  /// No description provided for @brushStyle.
  ///
  /// In en, this message translates to:
  /// **'Brush Style'**
  String get brushStyle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @canvas.
  ///
  /// In en, this message translates to:
  /// **'Canvas...'**
  String get canvas;

  /// No description provided for @canvasDimensionsMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Canvas dimensions must be positive.'**
  String get canvasDimensionsMustBePositive;

  /// No description provided for @canvasSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Canvas Size'**
  String get canvasSizeTitle;

  /// REVIEWED
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get colorLabel;

  /// No description provided for @colorTolerance.
  ///
  /// In en, this message translates to:
  /// **'Color Tolerance'**
  String get colorTolerance;

  /// No description provided for @colorUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage {percentage}'**
  String colorUsage(Object percentage);

  /// No description provided for @contentAlignment.
  ///
  /// In en, this message translates to:
  /// **'Content Alignment'**
  String get contentAlignment;

  /// No description provided for @copyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get copyToClipboard;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @degreesValue.
  ///
  /// In en, this message translates to:
  /// **'{value}°'**
  String degreesValue(Object value);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @desktopSoftware.
  ///
  /// In en, this message translates to:
  /// **'Desktop Software.'**
  String get desktopSoftware;

  /// No description provided for @deviceScreenResolution.
  ///
  /// In en, this message translates to:
  /// **'Device Screen Resolution: {resolution}'**
  String deviceScreenResolution(Object resolution);

  /// REVIEWED
  ///
  /// In en, this message translates to:
  /// **'{width} × {height}'**
  String dimensionsValue(Object width, Object height);

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @discardAndOpen.
  ///
  /// In en, this message translates to:
  /// **'Discard and Open'**
  String get discardAndOpen;

  /// No description provided for @discardCurrentDocumentQuestion.
  ///
  /// In en, this message translates to:
  /// **'Discard current document?'**
  String get discardCurrentDocumentQuestion;

  /// No description provided for @dropFileAddLayer.
  ///
  /// In en, this message translates to:
  /// **'Add as New Layer'**
  String get dropFileAddLayer;

  /// No description provided for @dropFileOpen.
  ///
  /// In en, this message translates to:
  /// **'Open File'**
  String get dropFileOpen;

  /// No description provided for @dropFilePrompt.
  ///
  /// In en, this message translates to:
  /// **'Would you like to add this as a new layer or open the file?'**
  String get dropFilePrompt;

  /// No description provided for @dropFileTitle.
  ///
  /// In en, this message translates to:
  /// **'File Dropped'**
  String get dropFileTitle;

  /// No description provided for @downloadAsFile.
  ///
  /// In en, this message translates to:
  /// **'Download as {fileName}'**
  String downloadAsFile(Object fileName);

  /// No description provided for @editText.
  ///
  /// In en, this message translates to:
  /// **'Edit Text'**
  String get editText;

  /// No description provided for @effectBlur.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get effectBlur;

  /// No description provided for @effectGrayscale.
  ///
  /// In en, this message translates to:
  /// **'Grayscale'**
  String get effectGrayscale;

  /// No description provided for @effectNoise.
  ///
  /// In en, this message translates to:
  /// **'Noise'**
  String get effectNoise;

  /// No description provided for @effectPixelate.
  ///
  /// In en, this message translates to:
  /// **'Pixelate'**
  String get effectPixelate;

  /// No description provided for @effectSharpen.
  ///
  /// In en, this message translates to:
  /// **'Sharpen'**
  String get effectSharpen;

  /// No description provided for @effectSoften.
  ///
  /// In en, this message translates to:
  /// **'Edge Soften'**
  String get effectSoften;

  /// No description provided for @effectIntensity.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get effectIntensity;

  /// No description provided for @effectVignette.
  ///
  /// In en, this message translates to:
  /// **'Vignette'**
  String get effectVignette;

  /// No description provided for @effects.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get effects;

  /// No description provided for @enterYourTextHere.
  ///
  /// In en, this message translates to:
  /// **'Enter your text here...'**
  String get enterYourTextHere;

  /// No description provided for @errorProcessingFile.
  ///
  /// In en, this message translates to:
  /// **'Error processing file: {error}'**
  String errorProcessingFile(Object error);

  /// No description provided for @errorReadingFile.
  ///
  /// In en, this message translates to:
  /// **'Error reading file: {error}'**
  String errorReadingFile(Object error);

  /// No description provided for @exportLabel.
  ///
  /// In en, this message translates to:
  /// **'Export...'**
  String get exportLabel;

  /// No description provided for @exportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export...'**
  String get exportTooltip;

  /// No description provided for @failedToLoadImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image: {error}'**
  String failedToLoadImage(Object error);

  /// No description provided for @fileFormatNotSupported.
  ///
  /// In en, this message translates to:
  /// **'File format .{extension} is not supported'**
  String fileFormatNotSupported(Object extension);

  /// No description provided for @fontColor.
  ///
  /// In en, this message translates to:
  /// **'Font Color'**
  String get fontColor;

  /// No description provided for @fontSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontSizeLabel;

  /// No description provided for @fontSizeValue.
  ///
  /// In en, this message translates to:
  /// **'Font Size: {value}'**
  String fontSizeValue(Object value);

  /// No description provided for @fpaintLoadImage.
  ///
  /// In en, this message translates to:
  /// **'fPaint Load Image'**
  String get fpaintLoadImage;

  /// No description provided for @githubRepo.
  ///
  /// In en, this message translates to:
  /// **'GitHub Repo'**
  String get githubRepo;

  /// No description provided for @gradientPointColor.
  ///
  /// In en, this message translates to:
  /// **'Gradient Point Color'**
  String get gradientPointColor;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @hexColor.
  ///
  /// In en, this message translates to:
  /// **'Hex Color'**
  String get hexColor;

  /// No description provided for @hexColorCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Hex Color copied to clipboard'**
  String get hexColorCopiedToClipboard;

  /// No description provided for @importLabel.
  ///
  /// In en, this message translates to:
  /// **'Import...'**
  String get importLabel;

  /// No description provided for @importTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import...'**
  String get importTooltip;

  /// No description provided for @invalidImageSizeDimensionsMustBeNumbers.
  ///
  /// In en, this message translates to:
  /// **'Invalid image size: Dimensions must be numbers.'**
  String get invalidImageSizeDimensionsMustBeNumbers;

  /// No description provided for @invalidSize.
  ///
  /// In en, this message translates to:
  /// **'Invalid size'**
  String get invalidSize;

  /// No description provided for @keyboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get keyboardShortcuts;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose app language or follow system'**
  String get languageSubtitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @menuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menuTooltip;

  /// No description provided for @mobileApp.
  ///
  /// In en, this message translates to:
  /// **'Mobile app.'**
  String get mobileApp;

  /// No description provided for @newCanvasSize.
  ///
  /// In en, this message translates to:
  /// **'New Canvas Size'**
  String get newCanvasSize;

  /// No description provided for @newFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'New from Clipboard'**
  String get newFromClipboard;

  /// REVIEWED
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @percentageValue.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String percentageValue(Object value);

  /// No description provided for @platforms.
  ///
  /// In en, this message translates to:
  /// **'Available on...'**
  String get platforms;

  /// No description provided for @resizeRotate.
  ///
  /// In en, this message translates to:
  /// **'Resize / Rotate'**
  String get resizeRotate;

  /// No description provided for @flipHorizontalTooltip.
  ///
  /// In en, this message translates to:
  /// **'Flip Horizontal'**
  String get flipHorizontalTooltip;

  /// No description provided for @flipVerticalTooltip.
  ///
  /// In en, this message translates to:
  /// **'Flip Vertical'**
  String get flipVerticalTooltip;

  /// No description provided for @rotateCanvasTooltip.
  ///
  /// In en, this message translates to:
  /// **'Rotate Canvas 90° CW'**
  String get rotateCanvasTooltip;

  /// No description provided for @runOnMostBrowsers.
  ///
  /// In en, this message translates to:
  /// **'Run on any OS with most browsers.'**
  String get runOnMostBrowsers;

  /// No description provided for @saveAsFile.
  ///
  /// In en, this message translates to:
  /// **'Save as {fileName}'**
  String saveAsFile(Object fileName);

  /// No description provided for @savedMessage.
  ///
  /// In en, this message translates to:
  /// **'Saved {fileName}'**
  String savedMessage(Object fileName);

  /// No description provided for @restoreRecoveryDraft.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreRecoveryDraft;

  /// No description provided for @discardRecoveryDraft.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardRecoveryDraft;

  /// No description provided for @restoreRecoveryDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore unsaved work?'**
  String get restoreRecoveryDraftTitle;

  /// No description provided for @restoreRecoveryDraftMessage.
  ///
  /// In en, this message translates to:
  /// **'fPaint found a recovery draft from your last session. Restore it now or discard it.'**
  String get restoreRecoveryDraftMessage;

  /// No description provided for @saveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveLabel;

  /// No description provided for @scale.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get scale;

  /// No description provided for @selectionIsHidden.
  ///
  /// In en, this message translates to:
  /// **'Selection is hidden.'**
  String get selectionIsHidden;

  /// No description provided for @selectValue.
  ///
  /// In en, this message translates to:
  /// **'Select {value}'**
  String selectValue(Object value);

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings...'**
  String get settings;

  /// No description provided for @startOver.
  ///
  /// In en, this message translates to:
  /// **'Start new...'**
  String get startOver;

  /// No description provided for @startOverTooltip.
  ///
  /// In en, this message translates to:
  /// **'Start new...'**
  String get startOverTooltip;

  /// No description provided for @textColor.
  ///
  /// In en, this message translates to:
  /// **'Text Color'**
  String get textColor;

  /// No description provided for @tolerance.
  ///
  /// In en, this message translates to:
  /// **'Tolerance'**
  String get tolerance;

  /// No description provided for @topColors.
  ///
  /// In en, this message translates to:
  /// **'Top {count} colors'**
  String topColors(Object count);

  /// No description provided for @transform.
  ///
  /// In en, this message translates to:
  /// **'Transform'**
  String get transform;

  /// No description provided for @unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Changes'**
  String get unsavedChanges;

  /// No description provided for @unsavedChangesDiscardAndOpenPrompt.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Do you want to discard them and open the new file?'**
  String get unsavedChangesDiscardAndOpenPrompt;

  /// No description provided for @useApplePencilOnlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'If enabled, only the Apple Pencil will be used for drawing.'**
  String get useApplePencilOnlySubtitle;

  /// No description provided for @useApplePencilOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Use Apple Pencil Only'**
  String get useApplePencilOnlyTitle;

  /// No description provided for @webBrowser.
  ///
  /// In en, this message translates to:
  /// **'Web Browser'**
  String get webBrowser;

  /// No description provided for @width.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get width;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
