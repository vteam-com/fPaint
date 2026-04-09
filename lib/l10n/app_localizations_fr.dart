// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get about => 'A propos...';

  @override
  String get activeTool => 'Outil actif';

  @override
  String get addText => 'Ajouter du texte';

  @override
  String get apply => 'Appliquer';

  @override
  String get availablePlatforms => 'Plateformes disponibles';

  @override
  String get blendModeColorBurnDescription =>
      'Assombrit la destination en augmentant le contraste basé sur la couleur source.';

  @override
  String get blendModeColorDescription =>
      'Utilise la teinte et la saturation de la source, mais conserve la luminance de la destination.';

  @override
  String get blendModeColorDodgeDescription =>
      'Éclaircit la destination en réduisant le contraste basé sur la couleur source.';

  @override
  String get blendModeDarkenDescription => 'Conserve la couleur la plus sombre des pixels source et destination.';

  @override
  String get blendModeHardLightDescription =>
      'Applique multiplication ou écran selon l\'intensité de la couleur source, créant un contraste fort.';

  @override
  String get blendModeHueDescription =>
      'Utilise la teinte de la source et la saturation et luminance de la destination.';

  @override
  String get blendModeLightenDescription => 'Conserve la couleur la plus claire des pixels source et destination.';

  @override
  String get blendModeLinearDodgeDescription => 'Additionne les couleurs source et destination, plafonné au blanc.';

  @override
  String get blendModeLuminosityDescription =>
      'Utilise la luminance de la source et la teinte et saturation de la destination.';

  @override
  String get blendModeMultiplyDescription =>
      'Multiplie les couleurs source et destination, produisant une sortie plus sombre.';

  @override
  String get blendModeNormalDescription => 'Place l\'image source sur la destination sans mélange.';

  @override
  String get blendModeNormalLabel => 'Normal';

  @override
  String get blendModeOverlayDescription =>
      'Combine les modes multiplication et écran : assombrit les zones sombres et éclaircit les zones claires.';

  @override
  String get blendModeSaturationDescription =>
      'Utilise la saturation de la source et la teinte et luminance de la destination.';

  @override
  String get blendModeScreenDescription =>
      'Multiplie les inverses de la source et de la destination, produisant une sortie plus claire.';

  @override
  String get blendModeSoftLightDescription =>
      'Adoucit le contraste en assombrissant ou éclaircissant la destination selon la source.';

  @override
  String get brush => 'Pinceau';

  @override
  String get brushStyle => 'Style de pinceau';

  @override
  String get cancel => 'Annuler';

  @override
  String get canvas => 'Toile...';

  @override
  String get canvasDimensionsMustBePositive => 'Les dimensions de la toile doivent etre positives.';

  @override
  String get canvasSizeTitle => 'Taille de la toile';

  @override
  String get colorLabel => 'Couleur';

  @override
  String get colorTolerance => 'Tolérance de couleur';

  @override
  String colorUsage(Object percentage) {
    return 'Utilisation $percentage';
  }

  @override
  String get contentAlignment => 'Alignement du contenu';

  @override
  String get copyToClipboard => 'Copier dans le presse-papiers';

  @override
  String get create => 'Creer';

  @override
  String get delete => 'Supprimer';

  @override
  String get desktopSoftware => 'Application de bureau.';

  @override
  String deviceScreenResolution(Object resolution) {
    return 'Resolution de l\'ecran: $resolution';
  }

  @override
  String get discard => 'Ignorer';

  @override
  String get discardAndOpen => 'Ignorer et ouvrir';

  @override
  String get discardCurrentDocumentQuestion => 'Ignorer le document actuel ?';

  @override
  String downloadAsFile(Object fileName) {
    return 'Telecharger en tant que $fileName';
  }

  @override
  String get editText => 'Modifier le texte';

  @override
  String get enterYourTextHere => 'Saisissez votre texte ici...';

  @override
  String errorProcessingFile(Object error) {
    return 'Erreur de traitement du fichier : $error';
  }

  @override
  String errorReadingFile(Object error) {
    return 'Erreur de lecture du fichier : $error';
  }

  @override
  String get exportLabel => 'Exporter...';

  @override
  String get exportTooltip => 'Exporter...';

  @override
  String failedToLoadImage(Object error) {
    return 'Echec du chargement de l\'image : $error';
  }

  @override
  String fileFormatNotSupported(Object extension) {
    return 'Le format de fichier .$extension n\'est pas pris en charge';
  }

  @override
  String get fontColor => 'Couleur de police';

  @override
  String get fontSizeLabel => 'Taille de police';

  @override
  String fontSizeValue(Object value) {
    return 'Taille de police : $value';
  }

  @override
  String get fpaintLoadImage => 'fPaint Charger une image';

  @override
  String get githubRepo => 'Depot GitHub';

  @override
  String get gradientPointColor => 'Couleur du point de degrade';

  @override
  String get height => 'Hauteur';

  @override
  String get hexColor => 'Couleur Hex';

  @override
  String get hexColorCopiedToClipboard => 'Couleur Hex copiee dans le presse-papiers';

  @override
  String get importLabel => 'Importer...';

  @override
  String get importTooltip => 'Importer...';

  @override
  String get invalidImageSizeDimensionsMustBeNumbers =>
      'Taille d\'image invalide: les dimensions doivent etre des nombres.';

  @override
  String get invalidSize => 'Taille invalide';

  @override
  String get keyboardShortcuts => 'Raccourcis clavier';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageFrench => 'Francais';

  @override
  String get languageLabel => 'Langue';

  @override
  String get languageSpanish => 'Espagnol';

  @override
  String get languageSubtitle => 'Choisissez la langue de l\'application ou suivez le systeme';

  @override
  String get languageSystem => 'Systeme';

  @override
  String get menuTooltip => 'Menu principal';

  @override
  String get mobileApp => 'Application mobile.';

  @override
  String get newCanvasSize => 'Nouvelle taille de toile';

  @override
  String get newFromClipboard => 'Importé du Presse-papiers';

  @override
  String get no => 'Non';

  @override
  String get platforms => 'Disponible sur...';

  @override
  String get rotateCanvasTooltip => 'Pivoter la toile de 90 degres sens horaire';

  @override
  String get runOnMostBrowsers => 'Fonctionne sur la plupart des navigateurs.';

  @override
  String saveAsFile(Object fileName) {
    return 'Enregistrer sous $fileName';
  }

  @override
  String savedMessage(Object fileName) {
    return 'Enregistre $fileName';
  }

  @override
  String saveLoadedFile(Object fileName) {
    return 'Enregistrer \"$fileName\"';
  }

  @override
  String get selectionIsHidden => 'La selection est masquee.';

  @override
  String selectValue(Object value) {
    return 'Selectionner $value';
  }

  @override
  String get settings => 'Parametres...';

  @override
  String get startOver => 'Nouveau...';

  @override
  String get startOverTooltip => 'Nouveau...';

  @override
  String get textColor => 'Couleur du texte';

  @override
  String get tolerance => 'Tolérance';

  @override
  String topColors(Object count) {
    return 'Top $count couleurs';
  }

  @override
  String get unsavedChanges => 'Modifications non enregistrees';

  @override
  String get unsavedChangesDiscardAndOpenPrompt =>
      'Vous avez des modifications non enregistrees. Voulez-vous les ignorer et ouvrir le nouveau fichier ?';

  @override
  String get useApplePencilOnlySubtitle => 'Si active, seul l\'Apple Pencil sera utilise pour dessiner.';

  @override
  String get useApplePencilOnlyTitle => 'Utiliser uniquement l\'Apple Pencil';

  @override
  String get webBrowser => 'Navigateur Web';

  @override
  String get width => 'Largeur';
}
