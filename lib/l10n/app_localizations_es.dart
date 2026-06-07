// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get about => 'Acerca de...';

  @override
  String get addAsNewLayer => 'Agregar como nueva capa';

  @override
  String get addText => 'Agregar texto';

  @override
  String get apply => 'Aplicar';

  @override
  String get availablePlatforms => 'Plataformas disponibles';

  @override
  String get blendModeColorBurnDescription =>
      'Oscurece el destino aumentando el contraste basado en el color de origen.';

  @override
  String get blendModeColorDescription =>
      'Usa el tono y saturación del origen, pero mantiene la luminancia del destino.';

  @override
  String get blendModeColorDodgeDescription =>
      'Aclara el destino reduciendo el contraste basado en el color de origen.';

  @override
  String get blendModeDarkenDescription => 'Conserva el color más oscuro de los píxeles de origen y destino.';

  @override
  String get blendModeHardLightDescription =>
      'Aplica multiplicar o pantalla según la intensidad del color de origen, creando un contraste fuerte.';

  @override
  String get blendModeHueDescription => 'Usa el tono del origen y la saturación y luminancia del destino.';

  @override
  String get blendModeLightenDescription => 'Conserva el color más claro de los píxeles de origen y destino.';

  @override
  String get blendModeLinearDodgeDescription => 'Suma los colores de origen y destino, limitando a blanco.';

  @override
  String get blendModeLuminosityDescription => 'Usa la luminancia del origen y el tono y saturación del destino.';

  @override
  String get blendModeMultiplyDescription =>
      'Multiplica los colores de origen y destino, produciendo una salida más oscura.';

  @override
  String get blendModeNormalDescription => 'Coloca la imagen de origen sobre el destino sin mezclar.';

  @override
  String get blendModeNormalLabel => 'Normal';

  @override
  String get blendModeOverlayDescription =>
      'Combina los modos multiplicar y pantalla: oscurece las áreas oscuras y aclara las claras.';

  @override
  String get blendModeSaturationDescription => 'Usa la saturación del origen y el tono y luminancia del destino.';

  @override
  String get blendModeScreenDescription =>
      'Multiplica los inversos del origen y destino, produciendo una salida más clara.';

  @override
  String get blendModeSoftLightDescription =>
      'Suaviza el contraste oscureciendo o aclarando el destino según el origen.';

  @override
  String get browseFiles => 'Explorar archivos...';

  @override
  String get brush => 'Pincel';

  @override
  String get brushColor => 'Color del pincel';

  @override
  String get brushSize => 'Tamaño del pincel';

  @override
  String get brushStyle => 'Estilo de pincel';

  @override
  String get brushStyleDash => 'Guion';

  @override
  String get brushStyleDashDot => 'Guion-punto';

  @override
  String get brushStyleDotted => 'Punteado';

  @override
  String get brushStyleSlash => 'Barra oblicua';

  @override
  String get brushStyleSolid => 'Solido';

  @override
  String get cancel => 'Cancelar';

  @override
  String get canvas => 'Lienzo...';

  @override
  String get canvasDimensionsMustBePositive => 'Las dimensiones del lienzo deben ser positivas.';

  @override
  String get canvasSizeTitle => 'Tamano del lienzo';

  @override
  String get colorLabel => 'Color';

  @override
  String get colorTolerance => 'Tolerancia de color';

  @override
  String colorUsage(Object percentage) {
    return 'Uso $percentage';
  }

  @override
  String get contentAlignment => 'Alineacion del contenido';

  @override
  String get copied => 'Copiado';

  @override
  String get copyToClipboard => 'Copiar al portapapeles';

  @override
  String get create => 'Crear';

  @override
  String degreesValue(Object value) {
    return 'Giro: $value°';
  }

  @override
  String get delete => 'Eliminar';

  @override
  String get desktopSoftware => 'Aplicacion de escritorio.';

  @override
  String deviceScreenResolution(Object resolution) {
    return 'Resolucion de pantalla: $resolution';
  }

  @override
  String dimensionsValue(Object width, Object height) {
    return '$width × $height';
  }

  @override
  String get discard => 'Descartar';

  @override
  String get discardAndOpen => 'Descartar y abrir';

  @override
  String get discardCurrentDocumentQuestion => 'Descartar el documento actual?';

  @override
  String downloadAsFile(Object fileName) {
    return 'Descargar como $fileName';
  }

  @override
  String get dropFileAddLayer => 'Agregar como nueva capa';

  @override
  String get dropFileOpen => 'Abrir archivo';

  @override
  String get dropFilePrompt => '¿Desea agregar esto como una nueva capa o abrir el archivo?';

  @override
  String get dropFileTitle => 'Archivo soltado';

  @override
  String get duplicate => 'Duplicar';

  @override
  String duplicatedOnLayer(Object layerName) {
    return 'Duplicado en $layerName';
  }

  @override
  String get editText => 'Editar texto';

  @override
  String get effectBlur => 'Desenfoque';

  @override
  String get effectBrightness => 'Brillo';

  @override
  String get effectContrast => 'Contraste';

  @override
  String get effectGrayscale => 'Escala de grises';

  @override
  String get effectHueSaturation => 'Cambio de tono';

  @override
  String get effectIntensity => 'Intensidad';

  @override
  String get effectNoise => 'Ruido';

  @override
  String get effectPixelate => 'Pixelar';

  @override
  String get effects => 'Efectos';

  @override
  String get effectShadow => 'Sombra';

  @override
  String get effectSharpen => 'Nitidez';

  @override
  String get effectSize => 'Tamano';

  @override
  String get effectSoften => 'Suavizar bordes';

  @override
  String get effectVignette => 'Viñeta';

  @override
  String get enterYourTextHere => 'Escribe tu texto aqui...';

  @override
  String errorProcessingFile(Object error) {
    return 'Error al procesar archivo: $error';
  }

  @override
  String errorReadingFile(Object error) {
    return 'Error al leer archivo: $error';
  }

  @override
  String get exportedLabel => 'Exportado';

  @override
  String get exportingLabel => 'Exportando...';

  @override
  String get exportLabel => 'Exportar...';

  @override
  String get exportTooltip => 'Exportar...';

  @override
  String failedToLoadImage(Object error) {
    return 'No se pudo cargar la imagen: $error';
  }

  @override
  String fileFormatNotSupported(Object extension) {
    return 'El formato de archivo .$extension no es compatible';
  }

  @override
  String fileFormatNotSupportedOnPlatform(Object extension) {
    return 'El formato .$extension no es compatible en esta plataforma';
  }

  @override
  String get fileNotFound => 'Archivo no encontrado';

  @override
  String get fillColor => 'Color de relleno';

  @override
  String get flipHorizontalTooltip => 'Voltear horizontalmente';

  @override
  String get flipVerticalTooltip => 'Voltear verticalmente';

  @override
  String get fontColor => 'Color de fuente';

  @override
  String get fontSizeLabel => 'Tamano de fuente';

  @override
  String get fpaintLoadImage => 'fPaint Cargar imagen';

  @override
  String get fromClipboard => 'Desde el portapapeles';

  @override
  String get githubRepo => 'Repositorio GitHub';

  @override
  String get gradientColorAdd => 'Agregar punto de color';

  @override
  String get gradientColorRemove => 'Quitar punto de color';

  @override
  String get gradientColors => 'Colores del degradado';

  @override
  String get gradientPointColor => 'Color del punto de degradado';

  @override
  String get gradientStopPosition => 'Posición';

  @override
  String get height => 'Alto';

  @override
  String get hexColor => 'Color Hex';

  @override
  String get hexColorCopiedToClipboard => 'Color Hex copiado al portapapeles';

  @override
  String get importLabel => 'Importar...';

  @override
  String get importTooltip => 'Importar...';

  @override
  String get invalidImageSizeDimensionsMustBeNumbers => 'Tamano de imagen invalido: las dimensiones deben ser numeros.';

  @override
  String get invalidSize => 'Tamano invalido';

  @override
  String get keepSaveBackupsSubtitle =>
      'Antes de sobrescribir un archivo guardado, conserva hasta 3 copias de seguridad con marca de tiempo de la version anterior.';

  @override
  String get keepSaveBackupsTitle => 'Mantener copias de seguridad al guardar';

  @override
  String get keyboardShortcuts => 'Atajos de teclado';

  @override
  String get languageEnglish => 'Ingles';

  @override
  String get languageFrench => 'Frances';

  @override
  String get languageLabel => 'Idioma';

  @override
  String get languageSpanish => 'Espanol';

  @override
  String get languageSubtitle => 'Elige el idioma de la aplicacion o usa el del sistema';

  @override
  String get languageSystem => 'Predeterminado del sistema';

  @override
  String get layerAdd => 'Agregar capa';

  @override
  String get layerAddAbove => 'Agregar una capa encima';

  @override
  String get layerBackgroundColor => 'Color de fondo';

  @override
  String get layerBlend => 'Mezcla: ';

  @override
  String get layerBlendMode => 'Modo de mezcla';

  @override
  String get layerChangeBlendMode => 'Cambiar modo de mezcla';

  @override
  String get layerDelete => 'Eliminar esta capa';

  @override
  String get layerEditsLocked => 'Edicion bloqueada';

  @override
  String get layerHidden => 'Oculta';

  @override
  String get layerHide => 'Ocultar capa';

  @override
  String get layerHideAllOthers => 'Ocultar todas las demás capas';

  @override
  String layerLockedForEditing(Object layerName) {
    return 'La capa $layerName esta bloqueada para editar.';
  }

  @override
  String get layerLockEdits => 'Bloquear edicion de la capa';

  @override
  String get layerMergeBelow => 'Fusionar con la capa inferior';

  @override
  String get layerModify => 'Modificar';

  @override
  String get layerNameTitle => 'Nombre de la capa';

  @override
  String get layerOpacity => 'Opacidad: ';

  @override
  String get layerRename => 'Renombrar capa';

  @override
  String get layerShow => 'Mostrar capa';

  @override
  String get layerShowAll => 'Mostrar todas las capas';

  @override
  String get layerToggleVisibility => 'Ocultar/Mostrar esta capa';

  @override
  String get layerUnlockEdits => 'Desbloquear edicion de la capa';

  @override
  String get menuTooltip => 'Menu principal';

  @override
  String get mobileApp => 'Aplicacion movil.';

  @override
  String get newCanvasSize => 'Tamano del nuevo lienzo';

  @override
  String get newFromClipboard => 'Nuevo desde el portapapeles';

  @override
  String get no => 'No';

  @override
  String get paste => 'Pegar';

  @override
  String get pencilSize => 'Tamaño del lápiz';

  @override
  String percentageValue(Object value) {
    return 'Escala: $value%';
  }

  @override
  String get platforms => 'Disponible en...';

  @override
  String get previewUnavailable => 'Vista previa no disponible';

  @override
  String get recentFilesLabel => 'Recientes';

  @override
  String get resizeRotate => 'Redimensionar / Girar';

  @override
  String get rotateCanvasTooltip => 'Girar lienzo 90 grados en sentido horario';

  @override
  String get runOnMostBrowsers => 'Funciona en la mayoria de navegadores.';

  @override
  String saveAsFile(Object fileName) {
    return 'Guardar como $fileName';
  }

  @override
  String get savedLabel => 'Guardado';

  @override
  String get saveLabel => 'Guardar';

  @override
  String get savingLabel => 'Guardando...';

  @override
  String get scale => 'Escalar';

  @override
  String get selectionIsHidden => 'La seleccion esta oculta.';

  @override
  String selectValue(Object value) {
    return 'Seleccionar $value';
  }

  @override
  String get settings => 'Configuracion...';

  @override
  String get startOver => 'Nuevo...';

  @override
  String get startOverTooltip => 'Nuevo...';

  @override
  String get textAlignCenter => 'Centro';

  @override
  String get textAlignLeft => 'Izquierda';

  @override
  String get textAlignRight => 'Derecha';

  @override
  String get textColor => 'Color de texto';

  @override
  String get toggleShell => 'Alternar interfaz';

  @override
  String get tolerance => 'Tolerancia';

  @override
  String get toolAdd => 'Agregar';

  @override
  String get toolBrush => 'Pincel';

  @override
  String get toolCircle => 'Círculo';

  @override
  String get toolCrop => 'Recortar';

  @override
  String get toolEraser => 'Borrador';

  @override
  String get toolFill => 'Relleno';

  @override
  String get toolHalftone => 'Semitono';

  @override
  String get toolInvert => 'Invertir';

  @override
  String get toolLasso => 'Lazo';

  @override
  String get toolLine => 'Línea';

  @override
  String get toolLinearGradient => 'Degradado lineal';

  @override
  String get toolMagic => 'Mágico';

  @override
  String get toolPaintBucket => 'Bote de pintura';

  @override
  String get toolPencil => 'Lápiz';

  @override
  String get toolRadialGradient => 'Degradado radial';

  @override
  String get toolRectangle => 'Rectángulo';

  @override
  String get toolRemove => 'Quitar';

  @override
  String get toolReplace => 'Reemplazar';

  @override
  String get toolSelector => 'Seleccionador';

  @override
  String get toolSmudge => 'Difuminar';

  @override
  String get toolBlurBrush => 'Pincel Desenfoque';

  @override
  String get toolSolid => 'Sólido';

  @override
  String get toolText => 'Texto';

  @override
  String topColors(Object count) {
    return 'Top $count colores';
  }

  @override
  String get transform => 'Transformar';

  @override
  String get translate => 'Mover';

  @override
  String get unsavedChanges => 'Cambios no guardados';

  @override
  String get unsavedChangesDiscardAndOpenPrompt =>
      'Tienes cambios no guardados. Quieres descartarlos y abrir el nuevo archivo?';

  @override
  String get useApplePencilOnlySubtitle => 'Si esta activado, solo se usara el Apple Pencil para dibujar.';

  @override
  String get useApplePencilOnlyTitle => 'Usar solo Apple Pencil';

  @override
  String get webBrowser => 'Navegador web';

  @override
  String get width => 'Ancho';
}
