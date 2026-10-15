import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';

/// Placeholder text passed to every parameterised message; each message must
/// interpolate its first argument, so the output is expected to contain it.
const String _sampleText = 'fPaintSample';

/// Placeholder number passed as the second argument of two-parameter messages.
const int _sampleNumber = 42;

/// Language code that the generated catalogue does not support.
const String _unsupportedLanguageCode = 'xx';

/// Locales shipped by the app, paired with the expected translation of
/// [AppLocalizations.about] (a spot-check that the right catalogue loaded).
const Map<String, String> _expectedAboutByLanguageCode = <String, String>{
  'en': 'About...',
  'es': 'Acerca de...',
  'fr': 'A propos...',
};

/// Accesses every getter and parameterised method declared on
/// [AppLocalizations] so that each locale file is fully exercised by
/// code-coverage.
///
/// The member list is generated from `lib/l10n/app_localizations.dart` and kept
/// in alphabetical order. When a new key is added to the ARB files, add it
/// here too: a missing entry shows up as uncovered lines in the locale files.
void _exerciseAllStrings(AppLocalizations l10n) {
  // Getters (215) ---------------------------------------------------------
  expect(l10n.about, isNotEmpty);
  expect(l10n.addAsNewLayer, isNotEmpty);
  expect(l10n.addText, isNotEmpty);
  expect(l10n.apply, isNotEmpty);
  expect(l10n.availablePlatforms, isNotEmpty);
  expect(l10n.blendModeColorBurnDescription, isNotEmpty);
  expect(l10n.blendModeColorDescription, isNotEmpty);
  expect(l10n.blendModeColorDodgeDescription, isNotEmpty);
  expect(l10n.blendModeDarkenDescription, isNotEmpty);
  expect(l10n.blendModeHardLightDescription, isNotEmpty);
  expect(l10n.blendModeHueDescription, isNotEmpty);
  expect(l10n.blendModeLightenDescription, isNotEmpty);
  expect(l10n.blendModeLinearDodgeDescription, isNotEmpty);
  expect(l10n.blendModeLuminosityDescription, isNotEmpty);
  expect(l10n.blendModeMultiplyDescription, isNotEmpty);
  expect(l10n.blendModeNormalDescription, isNotEmpty);
  expect(l10n.blendModeNormalLabel, isNotEmpty);
  expect(l10n.blendModeOverlayDescription, isNotEmpty);
  expect(l10n.blendModeSaturationDescription, isNotEmpty);
  expect(l10n.blendModeScreenDescription, isNotEmpty);
  expect(l10n.blendModeSoftLightDescription, isNotEmpty);
  expect(l10n.browseFiles, isNotEmpty);
  expect(l10n.brush, isNotEmpty);
  expect(l10n.brushColor, isNotEmpty);
  expect(l10n.brushSize, isNotEmpty);
  expect(l10n.brushStyle, isNotEmpty);
  expect(l10n.brushStyleCrossHatch, isNotEmpty);
  expect(l10n.brushStyleDash, isNotEmpty);
  expect(l10n.brushStyleDashDot, isNotEmpty);
  expect(l10n.brushStyleDotted, isNotEmpty);
  expect(l10n.brushStyleGrain, isNotEmpty);
  expect(l10n.brushStyleHatch, isNotEmpty);
  expect(l10n.brushStyleHatchMarks, isNotEmpty);
  expect(l10n.brushStyleSlash, isNotEmpty);
  expect(l10n.brushStyleSoft, isNotEmpty);
  expect(l10n.brushStyleSolid, isNotEmpty);
  expect(l10n.cancel, isNotEmpty);
  expect(l10n.canvas, isNotEmpty);
  expect(l10n.canvasDimensionsMustBePositive, isNotEmpty);
  expect(l10n.canvasSizeTitle, isNotEmpty);
  expect(l10n.close, isNotEmpty);
  expect(l10n.colorLabel, isNotEmpty);
  expect(l10n.colorPickerModeSliders, isNotEmpty);
  expect(l10n.colorPickerModeWheel, isNotEmpty);
  expect(l10n.colorTolerance, isNotEmpty);
  expect(l10n.contentAlignment, isNotEmpty);
  expect(l10n.copied, isNotEmpty);
  expect(l10n.copyToClipboard, isNotEmpty);
  expect(l10n.create, isNotEmpty);
  expect(l10n.cut, isNotEmpty);
  expect(l10n.delete, isNotEmpty);
  expect(l10n.desktopSoftware, isNotEmpty);
  expect(l10n.discard, isNotEmpty);
  expect(l10n.discardAndOpen, isNotEmpty);
  expect(l10n.discardCurrentDocumentQuestion, isNotEmpty);
  expect(l10n.dropFileAddLayer, isNotEmpty);
  expect(l10n.dropFileOpen, isNotEmpty);
  expect(l10n.dropFilePrompt, isNotEmpty);
  expect(l10n.dropFileTitle, isNotEmpty);
  expect(l10n.duplicate, isNotEmpty);
  expect(l10n.editText, isNotEmpty);
  expect(l10n.effectBlur, isNotEmpty);
  expect(l10n.effectBrightness, isNotEmpty);
  expect(l10n.effectContrast, isNotEmpty);
  expect(l10n.effectGrayscale, isNotEmpty);
  expect(l10n.effectHueRotation, isNotEmpty);
  expect(l10n.effectIntensity, isNotEmpty);
  expect(l10n.effectNoise, isNotEmpty);
  expect(l10n.effectPixelate, isNotEmpty);
  expect(l10n.effectSaturation, isNotEmpty);
  expect(l10n.effectShadow, isNotEmpty);
  expect(l10n.effectSharpness, isNotEmpty);
  expect(l10n.effectSize, isNotEmpty);
  expect(l10n.effectVignette, isNotEmpty);
  expect(l10n.effects, isNotEmpty);
  expect(l10n.enterYourTextHere, isNotEmpty);
  expect(l10n.exportLabel, isNotEmpty);
  expect(l10n.exportTooltip, isNotEmpty);
  expect(l10n.exportedLabel, isNotEmpty);
  expect(l10n.exportingLabel, isNotEmpty);
  expect(l10n.fileNotFound, isNotEmpty);
  expect(l10n.fillColor, isNotEmpty);
  expect(l10n.flipHorizontalTooltip, isNotEmpty);
  expect(l10n.flipVerticalTooltip, isNotEmpty);
  expect(l10n.flutterAttribution, isNotEmpty);
  expect(l10n.fontColor, isNotEmpty);
  expect(l10n.fontSizeLabel, isNotEmpty);
  expect(l10n.fpaintLoadImage, isNotEmpty);
  expect(l10n.fromClipboard, isNotEmpty);
  expect(l10n.githubRepo, isNotEmpty);
  expect(l10n.gradientColorAdd, isNotEmpty);
  expect(l10n.gradientColorRemove, isNotEmpty);
  expect(l10n.gradientColors, isNotEmpty);
  expect(l10n.gradientPointColor, isNotEmpty);
  expect(l10n.gradientStopPosition, isNotEmpty);
  expect(l10n.hatchAngle, isNotEmpty);
  expect(l10n.hatchCrossed, isNotEmpty);
  expect(l10n.hatchCurve, isNotEmpty);
  expect(l10n.hatchLength, isNotEmpty);
  expect(l10n.hatchLineWidth, isNotEmpty);
  expect(l10n.hatchSpacing, isNotEmpty);
  expect(l10n.hatchTaper, isNotEmpty);
  expect(l10n.height, isNotEmpty);
  expect(l10n.hexColor, isNotEmpty);
  expect(l10n.hexColorCopiedToClipboard, isNotEmpty);
  expect(l10n.imageDimensionsMustBePositive, isNotEmpty);
  expect(l10n.imageSize, isNotEmpty);
  expect(l10n.imageSizeHint, isNotEmpty);
  expect(l10n.imageSizeTitle, isNotEmpty);
  expect(l10n.importLabel, isNotEmpty);
  expect(l10n.importTooltip, isNotEmpty);
  expect(l10n.invalidImageSizeDimensionsMustBeNumbers, isNotEmpty);
  expect(l10n.invalidSize, isNotEmpty);
  expect(l10n.keepSaveBackupsSubtitle, isNotEmpty);
  expect(l10n.keepSaveBackupsTitle, isNotEmpty);
  expect(l10n.keyboardShortcuts, isNotEmpty);
  expect(l10n.languageEnglish, isNotEmpty);
  expect(l10n.languageFrench, isNotEmpty);
  expect(l10n.languageLabel, isNotEmpty);
  expect(l10n.languageSpanish, isNotEmpty);
  expect(l10n.languageSubtitle, isNotEmpty);
  expect(l10n.languageSystem, isNotEmpty);
  expect(l10n.layerAdd, isNotEmpty);
  expect(l10n.layerAddAbove, isNotEmpty);
  expect(l10n.layerBackgroundColor, isNotEmpty);
  expect(l10n.layerBlend, isNotEmpty);
  expect(l10n.layerBlendMode, isNotEmpty);
  expect(l10n.layerChangeBlendMode, isNotEmpty);
  expect(l10n.layerDelete, isNotEmpty);
  expect(l10n.layerEditsLocked, isNotEmpty);
  expect(l10n.layerHidden, isNotEmpty);
  expect(l10n.layerHide, isNotEmpty);
  expect(l10n.layerHideAllOthers, isNotEmpty);
  expect(l10n.layerLockEdits, isNotEmpty);
  expect(l10n.layerMergeBelow, isNotEmpty);
  expect(l10n.layerModify, isNotEmpty);
  expect(l10n.layerNameTitle, isNotEmpty);
  expect(l10n.layerOpacity, isNotEmpty);
  expect(l10n.layerPickerNoLayerFound, isNotEmpty);
  expect(l10n.layerPickerTooltip, isNotEmpty);
  expect(l10n.layerRename, isNotEmpty);
  expect(l10n.layerShow, isNotEmpty);
  expect(l10n.layerShowAll, isNotEmpty);
  expect(l10n.layerToggleVisibility, isNotEmpty);
  expect(l10n.layerUnlockEdits, isNotEmpty);
  expect(l10n.menuTooltip, isNotEmpty);
  expect(l10n.mobileApp, isNotEmpty);
  expect(l10n.newCanvasSize, isNotEmpty);
  expect(l10n.newFromClipboard, isNotEmpty);
  expect(l10n.no, isNotEmpty);
  expect(l10n.paste, isNotEmpty);
  expect(l10n.penOnlyDrawingSubtitle, isNotEmpty);
  expect(l10n.penOnlyDrawingTitle, isNotEmpty);
  expect(l10n.pencilSize, isNotEmpty);
  expect(l10n.platforms, isNotEmpty);
  expect(l10n.previewUnavailable, isNotEmpty);
  expect(l10n.quitWithoutSaving, isNotEmpty);
  expect(l10n.recentFilesLabel, isNotEmpty);
  expect(l10n.resetViewRotation, isNotEmpty);
  expect(l10n.resizeRotate, isNotEmpty);
  expect(l10n.rotateCanvasTooltip, isNotEmpty);
  expect(l10n.runOnMostBrowsers, isNotEmpty);
  expect(l10n.saveLabel, isNotEmpty);
  expect(l10n.savedLabel, isNotEmpty);
  expect(l10n.savingLabel, isNotEmpty);
  expect(l10n.scale, isNotEmpty);
  expect(l10n.selectionAllLayers, isNotEmpty);
  expect(l10n.selectionIsHidden, isNotEmpty);
  expect(l10n.settings, isNotEmpty);
  expect(l10n.sidePanelLayersSection, isNotEmpty);
  expect(l10n.startOver, isNotEmpty);
  expect(l10n.startOverTooltip, isNotEmpty);
  expect(l10n.textAlignCenter, isNotEmpty);
  expect(l10n.textAlignLeft, isNotEmpty);
  expect(l10n.textAlignRight, isNotEmpty);
  expect(l10n.textColor, isNotEmpty);
  expect(l10n.toggleShell, isNotEmpty);
  expect(l10n.tolerance, isNotEmpty);
  expect(l10n.toolAdd, isNotEmpty);
  expect(l10n.toolBlurBrush, isNotEmpty);
  expect(l10n.toolBrush, isNotEmpty);
  expect(l10n.toolCircle, isNotEmpty);
  expect(l10n.toolCrop, isNotEmpty);
  expect(l10n.toolEraser, isNotEmpty);
  expect(l10n.toolFill, isNotEmpty);
  expect(l10n.toolHalftone, isNotEmpty);
  expect(l10n.toolHatchMarks, isNotEmpty);
  expect(l10n.toolHatching, isNotEmpty);
  expect(l10n.toolInvert, isNotEmpty);
  expect(l10n.toolLasso, isNotEmpty);
  expect(l10n.toolLine, isNotEmpty);
  expect(l10n.toolLinearGradient, isNotEmpty);
  expect(l10n.toolMagic, isNotEmpty);
  expect(l10n.toolPaintBucket, isNotEmpty);
  expect(l10n.toolPencil, isNotEmpty);
  expect(l10n.toolRadialGradient, isNotEmpty);
  expect(l10n.toolRectangle, isNotEmpty);
  expect(l10n.toolRemove, isNotEmpty);
  expect(l10n.toolSectionBrush, isNotEmpty);
  expect(l10n.toolSectionElements, isNotEmpty);
  expect(l10n.toolSelectionBrush, isNotEmpty);
  expect(l10n.toolSelector, isNotEmpty);
  expect(l10n.toolSmudge, isNotEmpty);
  expect(l10n.toolSolid, isNotEmpty);
  expect(l10n.toolText, isNotEmpty);
  expect(l10n.trackpadPressureSubtitle, isNotEmpty);
  expect(l10n.trackpadPressureTitle, isNotEmpty);
  expect(l10n.transform, isNotEmpty);
  expect(l10n.translate, isNotEmpty);
  expect(l10n.unsavedChanges, isNotEmpty);
  expect(l10n.unsavedChangesDiscardAndOpenPrompt, isNotEmpty);
  expect(l10n.unsavedChangesIndicatorTooltip, isNotEmpty);
  expect(l10n.unsavedChangesQuitPrompt, isNotEmpty);
  expect(l10n.webBrowser, isNotEmpty);
  expect(l10n.width, isNotEmpty);

  // Parameterised methods (18) -------------------------------------------
  expect(l10n.colorUsage(_sampleText), contains(_sampleText));
  expect(l10n.degreesValue(_sampleText), contains(_sampleText));
  expect(l10n.deviceScreenResolution(_sampleText), contains(_sampleText));
  expect(l10n.dimensionsValue(_sampleText, _sampleNumber), contains(_sampleText));
  expect(l10n.downloadAsFile(_sampleText), contains(_sampleText));
  expect(l10n.duplicatedOnLayer(_sampleText), contains(_sampleText));
  expect(l10n.errorProcessingFile(_sampleText), contains(_sampleText));
  expect(l10n.errorReadingFile(_sampleText), contains(_sampleText));
  expect(l10n.failedToLoadImage(_sampleText), contains(_sampleText));
  expect(l10n.fileFormatNotSupported(_sampleText), contains(_sampleText));
  expect(l10n.fileFormatNotSupportedOnPlatform(_sampleText), contains(_sampleText));
  expect(l10n.layerLockedForEditing(_sampleText), contains(_sampleText));
  expect(l10n.layerPickerSelected(_sampleText), contains(_sampleText));
  expect(l10n.percentageValue(_sampleText), contains(_sampleText));
  expect(l10n.pixelsValue(_sampleText), contains(_sampleText));
  expect(l10n.saveAsFile(_sampleText), contains(_sampleText));
  expect(l10n.selectValue(_sampleText), contains(_sampleText));
  expect(l10n.topColors(_sampleText), contains(_sampleText));
}

void main() {
  for (final MapEntry<String, String> entry in _expectedAboutByLanguageCode.entries) {
    final String languageCode = entry.key;

    group('AppLocalizations – $languageCode', () {
      late AppLocalizations l10n;

      setUp(() async {
        l10n = await AppLocalizations.delegate.load(Locale(languageCode));
      });

      test('all strings are non-empty and messages interpolate their arguments', () {
        _exerciseAllStrings(l10n);
      });

      test('locale name is $languageCode', () {
        expect(l10n.localeName, languageCode);
      });

      test('about returns the $languageCode translation', () {
        expect(l10n.about, entry.value);
      });
    });
  }

  group('AppLocalizations delegate', () {
    test('supports every shipped locale', () {
      for (final String languageCode in _expectedAboutByLanguageCode.keys) {
        final Locale locale = Locale(languageCode);
        expect(AppLocalizations.supportedLocales, contains(locale));
        expect(AppLocalizations.delegate.isSupported(locale), isTrue);
      }
    });

    test('rejects an unsupported locale', () {
      const Locale unsupported = Locale(_unsupportedLanguageCode);
      expect(AppLocalizations.delegate.isSupported(unsupported), isFalse);
      expect(() => lookupAppLocalizations(unsupported), throwsA(isA<FlutterError>()));
    });

    test('never asks to reload', () {
      expect(AppLocalizations.delegate.shouldReload(AppLocalizations.delegate), isFalse);
    });

    testWidgets('of(context) resolves the delegate-loaded instance', (WidgetTester tester) async {
      AppLocalizations? resolved;
      await tester.pumpWidget(
        Localizations(
          locale: Locale(_expectedAboutByLanguageCode.keys.first),
          delegates: AppLocalizations.localizationsDelegates,
          child: Builder(
            builder: (BuildContext context) {
              resolved = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved?.about, _expectedAboutByLanguageCode.values.first);
    });

    test('localizationsDelegates contains delegate', () {
      expect(AppLocalizations.localizationsDelegates, contains(AppLocalizations.delegate));
    });
  });
}
