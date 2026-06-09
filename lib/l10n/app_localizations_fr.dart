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
  String get addAsNewLayer => 'Ajouter comme nouveau calque';

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
  String get browseFiles => 'Parcourir...';

  @override
  String get brush => 'Pinceau';

  @override
  String get brushColor => 'Couleur du pinceau';

  @override
  String get brushSize => 'Taille du pinceau';

  @override
  String get brushStyle => 'Style de pinceau';

  @override
  String get brushStyleDash => 'Tiret';

  @override
  String get brushStyleDashDot => 'Tiret-point';

  @override
  String get brushStyleDotted => 'Pointille';

  @override
  String get brushStyleSlash => 'Barre oblique';

  @override
  String get brushStyleSolid => 'Continu';

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
  String get colorPickerModeSliders => 'Curseurs';

  @override
  String get colorPickerModeWheel => 'Roue';

  @override
  String get colorTolerance => 'Tolérance de couleur';

  @override
  String colorUsage(Object percentage) {
    return 'Utilisation $percentage';
  }

  @override
  String get contentAlignment => 'Alignement du contenu';

  @override
  String get copied => 'Copie';

  @override
  String get copyToClipboard => 'Copier dans le presse-papiers';

  @override
  String get create => 'Creer';

  @override
  String get cut => 'Couper';

  @override
  String degreesValue(Object value) {
    return 'Rotation : $value°';
  }

  @override
  String get delete => 'Supprimer';

  @override
  String get desktopSoftware => 'Application de bureau.';

  @override
  String deviceScreenResolution(Object resolution) {
    return 'Resolution de l\'ecran: $resolution';
  }

  @override
  String dimensionsValue(Object width, Object height) {
    return '$width × $height';
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
  String get dropFileAddLayer => 'Ajouter comme nouveau calque';

  @override
  String get dropFileOpen => 'Ouvrir le fichier';

  @override
  String get dropFilePrompt => 'Voulez-vous ajouter ceci comme nouveau calque ou ouvrir le fichier ?';

  @override
  String get dropFileTitle => 'Fichier déposé';

  @override
  String get duplicate => 'Dupliquer';

  @override
  String duplicatedOnLayer(Object layerName) {
    return 'Duplique sur $layerName';
  }

  @override
  String get editText => 'Modifier le texte';

  @override
  String get effectBlur => 'Flou';

  @override
  String get effectBrightness => 'Luminosité';

  @override
  String get effectContrast => 'Contraste';

  @override
  String get effectGrayscale => 'Niveaux de gris';

  @override
  String get effectHueSaturation => 'Décalage de teinte';

  @override
  String get effectIntensity => 'Intensité';

  @override
  String get effectNoise => 'Bruit';

  @override
  String get effectPixelate => 'Pixéliser';

  @override
  String get effects => 'Effets';

  @override
  String get effectShadow => 'Ombre';

  @override
  String get effectSharpen => 'Netteté';

  @override
  String get effectSize => 'Taille';

  @override
  String get effectSoften => 'Adoucir les bords';

  @override
  String get effectVignette => 'Vignetage';

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
  String get exportedLabel => 'Exporté';

  @override
  String get exportingLabel => 'Exportation...';

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
  String fileFormatNotSupportedOnPlatform(Object extension) {
    return 'Le format .$extension n\'est pas pris en charge sur cette plateforme';
  }

  @override
  String get fileNotFound => 'Fichier non trouvé';

  @override
  String get fillColor => 'Couleur de remplissage';

  @override
  String get flipHorizontalTooltip => 'Retourner horizontalement';

  @override
  String get flipVerticalTooltip => 'Retourner verticalement';

  @override
  String get fontColor => 'Couleur de police';

  @override
  String get fontSizeLabel => 'Taille de police';

  @override
  String get fpaintLoadImage => 'fPaint Charger une image';

  @override
  String get fromClipboard => 'Depuis le presse-papiers';

  @override
  String get githubRepo => 'Depot GitHub';

  @override
  String get gradientColorAdd => 'Ajouter une étape de couleur';

  @override
  String get gradientColorRemove => 'Supprimer une étape de couleur';

  @override
  String get gradientColors => 'Couleurs du dégradé';

  @override
  String get gradientPointColor => 'Couleur du point de degrade';

  @override
  String get gradientStopPosition => 'Emplacement';

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
  String get keepSaveBackupsSubtitle =>
      'Avant d\'ecraser un fichier enregistre, conservez jusqu\'a 3 sauvegardes horodatees de la version precedente.';

  @override
  String get keepSaveBackupsTitle => 'Conserver des sauvegardes a l\'enregistrement';

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
  String get layerAdd => 'Ajouter un calque';

  @override
  String get layerAddAbove => 'Ajouter un calque au-dessus';

  @override
  String get layerBackgroundColor => 'Couleur d\'arrière-plan';

  @override
  String get layerBlend => 'Fusion : ';

  @override
  String get layerBlendMode => 'Mode de fusion';

  @override
  String get layerChangeBlendMode => 'Changer le mode de fusion';

  @override
  String get layerDelete => 'Supprimer ce calque';

  @override
  String get layerEditsLocked => 'Modification verrouillee';

  @override
  String get layerHidden => 'Masqué';

  @override
  String get layerHide => 'Masquer le calque';

  @override
  String get layerHideAllOthers => 'Masquer tous les autres calques';

  @override
  String layerLockedForEditing(Object layerName) {
    return 'Le calque $layerName est verrouille pour la modification.';
  }

  @override
  String get layerLockEdits => 'Verrouiller la modification du calque';

  @override
  String get layerMergeBelow => 'Fusionner avec le calque inférieur';

  @override
  String get layerModify => 'Modifier';

  @override
  String get layerNameTitle => 'Nom du calque';

  @override
  String get layerOpacity => 'Opacité : ';

  @override
  String get layerRename => 'Renommer le calque';

  @override
  String get layerShow => 'Afficher le calque';

  @override
  String get layerShowAll => 'Afficher tous les calques';

  @override
  String get layerToggleVisibility => 'Masquer/Afficher ce calque';

  @override
  String get layerUnlockEdits => 'Deverrouiller la modification du calque';

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
  String get paste => 'Coller';

  @override
  String get pencilSize => 'Taille du crayon';

  @override
  String percentageValue(Object value) {
    return 'Echelle : $value %';
  }

  @override
  String get platforms => 'Disponible sur...';

  @override
  String get previewUnavailable => 'Aperçu indisponible';

  @override
  String get recentFilesLabel => 'Récents';

  @override
  String get resizeRotate => 'Redimensionner / Pivoter';

  @override
  String get rotateCanvasTooltip => 'Pivoter la toile de 90 degres sens horaire';

  @override
  String get runOnMostBrowsers => 'Fonctionne sur la plupart des navigateurs.';

  @override
  String saveAsFile(Object fileName) {
    return 'Enregistrer sous $fileName';
  }

  @override
  String get savedLabel => 'Enregistre';

  @override
  String get saveLabel => 'Enregistrer';

  @override
  String get savingLabel => 'Enregistrement...';

  @override
  String get scale => 'Mettre a l\'echelle';

  @override
  String get selectionIsHidden => 'La selection est masquee.';

  @override
  String selectValue(Object value) {
    return 'Selectionner $value';
  }

  @override
  String get settings => 'Parametres...';

  @override
  String get sidePanelBrushesSection => 'Pinceaux';

  @override
  String get sidePanelLayersSection => 'Calques';

  @override
  String get sidePanelSelectionSection => 'Outils de selection';

  @override
  String get startOver => 'Nouveau...';

  @override
  String get startOverTooltip => 'Nouveau...';

  @override
  String get textAlignCenter => 'Centre';

  @override
  String get textAlignLeft => 'Gauche';

  @override
  String get textAlignRight => 'Droite';

  @override
  String get textColor => 'Couleur du texte';

  @override
  String get toggleShell => 'Afficher ou masquer l\'interface';

  @override
  String get tolerance => 'Tolérance';

  @override
  String get toolAdd => 'Ajouter';

  @override
  String get toolBlurBrush => 'Pinceau Flou';

  @override
  String get toolBrush => 'Pinceau';

  @override
  String get toolCircle => 'Cercle';

  @override
  String get toolCrop => 'Recadrer';

  @override
  String get toolEraser => 'Gomme';

  @override
  String get toolFill => 'Remplissage';

  @override
  String get toolHalftone => 'Demi-teinte';

  @override
  String get toolInvert => 'Inverser';

  @override
  String get toolLasso => 'Lasso libre';

  @override
  String get toolLine => 'Ligne';

  @override
  String get toolLinearGradient => 'Dégradé linéaire';

  @override
  String get toolMagic => 'Magique';

  @override
  String get toolPaintBucket => 'Pot de peinture';

  @override
  String get toolPencil => 'Crayon';

  @override
  String get toolRadialGradient => 'Dégradé radial';

  @override
  String get toolRectangle => 'Rectangulaire';

  @override
  String get toolRemove => 'Retirer';

  @override
  String get toolReplace => 'Remplacer';

  @override
  String get toolSelector => 'Sélecteur';

  @override
  String get toolSmudge => 'Estomper';

  @override
  String get toolSolid => 'Uni';

  @override
  String get toolText => 'Texte';

  @override
  String topColors(Object count) {
    return 'Top $count couleurs';
  }

  @override
  String get transform => 'Transformer';

  @override
  String get translate => 'Deplacer';

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
