import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';

/// Accesses every string property and parameterized method on the given
/// [AppLocalizations] instance so that the corresponding locale file is
/// exercised by code-coverage.
void _exerciseAllStrings(final AppLocalizations l10n) {
  // Simple getters ---------------------------------------------------------
  expect(l10n.about, isNotEmpty);
  expect(l10n.addText, isNotEmpty);
  expect(l10n.addAsNewLayer, isNotEmpty);
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
  expect(l10n.brushStyle, isNotEmpty);
  expect(l10n.brushStyleDash, isNotEmpty);
  expect(l10n.brushStyleDashDot, isNotEmpty);
  expect(l10n.brushStyleDotted, isNotEmpty);
  expect(l10n.brushStyleSlash, isNotEmpty);
  expect(l10n.brushStyleSolid, isNotEmpty);
  expect(l10n.cancel, isNotEmpty);
  expect(l10n.canvas, isNotEmpty);
  expect(l10n.canvasDimensionsMustBePositive, isNotEmpty);
  expect(l10n.canvasSizeTitle, isNotEmpty);
  expect(l10n.colorLabel, isNotEmpty);
  expect(l10n.colorTolerance, isNotEmpty);
  expect(l10n.contentAlignment, isNotEmpty);
  expect(l10n.copyToClipboard, isNotEmpty);
  expect(l10n.duplicate, isNotEmpty);
  expect(l10n.create, isNotEmpty);
  expect(l10n.delete, isNotEmpty);
  expect(l10n.desktopSoftware, isNotEmpty);
  expect(l10n.discard, isNotEmpty);
  expect(l10n.discardAndOpen, isNotEmpty);
  expect(l10n.discardCurrentDocumentQuestion, isNotEmpty);
  expect(l10n.dropFileAddLayer, isNotEmpty);
  expect(l10n.dropFileOpen, isNotEmpty);
  expect(l10n.dropFilePrompt, isNotEmpty);
  expect(l10n.dropFileTitle, isNotEmpty);
  expect(l10n.editText, isNotEmpty);
  expect(l10n.effectBlur, isNotEmpty);
  expect(l10n.effectGrayscale, isNotEmpty);
  expect(l10n.effectNoise, isNotEmpty);
  expect(l10n.effectPixelate, isNotEmpty);
  expect(l10n.effectSharpen, isNotEmpty);
  expect(l10n.effectSoften, isNotEmpty);
  expect(l10n.effectVignette, isNotEmpty);
  expect(l10n.effects, isNotEmpty);
  expect(l10n.enterYourTextHere, isNotEmpty);
  expect(l10n.exportLabel, isNotEmpty);
  expect(l10n.exportTooltip, isNotEmpty);
  expect(l10n.fontColor, isNotEmpty);
  expect(l10n.fontSizeLabel, isNotEmpty);
  expect(l10n.fpaintLoadImage, isNotEmpty);
  expect(l10n.githubRepo, isNotEmpty);
  expect(l10n.gradientPointColor, isNotEmpty);
  expect(l10n.gradientStopPosition, isNotEmpty);
  expect(l10n.height, isNotEmpty);
  expect(l10n.hexColor, isNotEmpty);
  expect(l10n.hexColorCopiedToClipboard, isNotEmpty);
  expect(l10n.importLabel, isNotEmpty);
  expect(l10n.importTooltip, isNotEmpty);
  expect(l10n.invalidImageSizeDimensionsMustBeNumbers, isNotEmpty);
  expect(l10n.invalidSize, isNotEmpty);
  expect(l10n.keyboardShortcuts, isNotEmpty);
  expect(l10n.languageEnglish, isNotEmpty);
  expect(l10n.languageFrench, isNotEmpty);
  expect(l10n.languageLabel, isNotEmpty);
  expect(l10n.languageSpanish, isNotEmpty);
  expect(l10n.languageSubtitle, isNotEmpty);
  expect(l10n.languageSystem, isNotEmpty);
  expect(l10n.menuTooltip, isNotEmpty);
  expect(l10n.mobileApp, isNotEmpty);
  expect(l10n.newCanvasSize, isNotEmpty);
  expect(l10n.newFromClipboard, isNotEmpty);
  expect(l10n.no, isNotEmpty);
  expect(l10n.paste, isNotEmpty);
  expect(l10n.platforms, isNotEmpty);
  expect(l10n.resizeRotate, isNotEmpty);
  expect(l10n.recentFilesLabel, isNotEmpty);
  expect(l10n.flipHorizontalTooltip, isNotEmpty);
  expect(l10n.flipVerticalTooltip, isNotEmpty);
  expect(l10n.rotateCanvasTooltip, isNotEmpty);
  expect(l10n.runOnMostBrowsers, isNotEmpty);
  expect(l10n.saveLabel, isNotEmpty);
  expect(l10n.scale, isNotEmpty);
  expect(l10n.selectionIsHidden, isNotEmpty);
  expect(l10n.settings, isNotEmpty);
  expect(l10n.startOver, isNotEmpty);
  expect(l10n.startOverTooltip, isNotEmpty);
  expect(l10n.textColor, isNotEmpty);
  expect(l10n.tolerance, isNotEmpty);
  expect(l10n.transform, isNotEmpty);
  expect(l10n.unsavedChanges, isNotEmpty);
  expect(l10n.unsavedChangesDiscardAndOpenPrompt, isNotEmpty);
  expect(l10n.useApplePencilOnlySubtitle, isNotEmpty);
  expect(l10n.useApplePencilOnlyTitle, isNotEmpty);
  expect(l10n.webBrowser, isNotEmpty);
  expect(l10n.width, isNotEmpty);
  expect(l10n.toolPencil, isNotEmpty);
  expect(l10n.toolBrush, isNotEmpty);
  expect(l10n.toolLine, isNotEmpty);
  expect(l10n.toolRectangle, isNotEmpty);
  expect(l10n.toolCircle, isNotEmpty);
  expect(l10n.toolPaintBucket, isNotEmpty);
  expect(l10n.toolEraser, isNotEmpty);
  expect(l10n.toolText, isNotEmpty);
  expect(l10n.toolSelector, isNotEmpty);
  expect(l10n.toolFill, isNotEmpty);
  expect(l10n.toolSolid, isNotEmpty);
  expect(l10n.toolLinearGradient, isNotEmpty);
  expect(l10n.toolRadialGradient, isNotEmpty);
  expect(l10n.toolLasso, isNotEmpty);
  expect(l10n.toolMagic, isNotEmpty);
  expect(l10n.toolReplace, isNotEmpty);
  expect(l10n.toolAdd, isNotEmpty);
  expect(l10n.toolRemove, isNotEmpty);
  expect(l10n.toolInvert, isNotEmpty);
  expect(l10n.toolCrop, isNotEmpty);
  expect(l10n.brushColor, isNotEmpty);
  expect(l10n.fillColor, isNotEmpty);
  expect(l10n.pencilSize, isNotEmpty);
  expect(l10n.brushSize, isNotEmpty);
  expect(l10n.layerHidden, isNotEmpty);
  expect(l10n.layerOpacity, isNotEmpty);
  expect(l10n.layerBlend, isNotEmpty);
  expect(l10n.layerNameTitle, isNotEmpty);
  expect(l10n.layerAddAbove, isNotEmpty);
  expect(l10n.layerDelete, isNotEmpty);
  expect(l10n.layerMergeBelow, isNotEmpty);
  expect(l10n.layerModify, isNotEmpty);
  expect(l10n.layerBlendMode, isNotEmpty);
  expect(l10n.layerBackgroundColor, isNotEmpty);
  expect(l10n.layerToggleVisibility, isNotEmpty);
  expect(l10n.layerRename, isNotEmpty);
  expect(l10n.layerChangeBlendMode, isNotEmpty);
  expect(l10n.layerHideAllOthers, isNotEmpty);
  expect(l10n.layerShowAll, isNotEmpty);
  expect(l10n.layerHide, isNotEmpty);
  expect(l10n.layerShow, isNotEmpty);
  expect(l10n.layerAdd, isNotEmpty);

  // Parameterized methods --------------------------------------------------
  expect(l10n.colorUsage('50%'), isNotEmpty);
  expect(l10n.degreesValue('90'), isNotEmpty);
  expect(l10n.deviceScreenResolution('1920x1080'), isNotEmpty);
  expect(l10n.dimensionsValue('800', '600'), isNotEmpty);
  expect(l10n.downloadAsFile('image.PNG'), isNotEmpty);
  expect(l10n.errorProcessingFile('err'), isNotEmpty);
  expect(l10n.errorReadingFile('err'), isNotEmpty);
  expect(l10n.failedToLoadImage('err'), isNotEmpty);
  expect(l10n.fileFormatNotSupported('bmp'), isNotEmpty);
  expect(l10n.fileFormatNotSupportedOnPlatform('bmp'), isNotEmpty);
  expect(l10n.percentageValue('50'), isNotEmpty);
  expect(l10n.saveAsFile('image.PNG'), isNotEmpty);
  expect(l10n.savedMessage('image.png'), isNotEmpty);
  expect(l10n.selectValue('all'), isNotEmpty);
  expect(l10n.topColors('5'), isNotEmpty);
}

void main() {
  group('AppLocalizations – English', () {
    late AppLocalizations l10n;

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('all string properties are non-empty', () {
      _exerciseAllStrings(l10n);
    });

    test('locale name is en', () {
      expect(l10n.localeName, 'en');
    });
  });

  group('AppLocalizations – Spanish', () {
    late AppLocalizations l10n;

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('es'));
    });

    test('all string properties are non-empty', () {
      _exerciseAllStrings(l10n);
    });

    test('locale name is es', () {
      expect(l10n.localeName, 'es');
    });

    test('about returns Spanish translation', () {
      expect(l10n.about, 'Acerca de...');
    });
  });

  group('AppLocalizations – French', () {
    late AppLocalizations l10n;

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    });

    test('all string properties are non-empty', () {
      _exerciseAllStrings(l10n);
    });

    test('locale name is fr', () {
      expect(l10n.localeName, 'fr');
    });

    test('about returns French translation', () {
      expect(l10n.about, 'A propos...');
    });
  });

  group('AppLocalizations delegate', () {
    test('supports en, es, fr', () {
      expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
      expect(AppLocalizations.supportedLocales, contains(const Locale('es')));
      expect(AppLocalizations.supportedLocales, contains(const Locale('fr')));
    });

    test('isSupported returns true for supported locales', () {
      expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
      expect(AppLocalizations.delegate.isSupported(const Locale('es')), isTrue);
      expect(AppLocalizations.delegate.isSupported(const Locale('fr')), isTrue);
    });

    test('localizationsDelegates contains delegate', () {
      expect(AppLocalizations.localizationsDelegates, contains(AppLocalizations.delegate));
    });
  });
}
