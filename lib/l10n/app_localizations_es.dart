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
  String get activeTool => 'Herramienta activa';

  @override
  String get addText => 'Agregar texto';

  @override
  String get apply => 'Aplicar';

  @override
  String get availablePlatforms => 'Plataformas disponibles';

  @override
  String get blendModeColorBurnDescription => 'Oscurece el destino aumentando el contraste basado en el color de origen.';

  @override
  String get blendModeColorDescription => 'Usa el tono y saturación del origen, pero mantiene la luminancia del destino.';

  @override
  String get blendModeColorDodgeDescription => 'Aclara el destino reduciendo el contraste basado en el color de origen.';

  @override
  String get blendModeDarkenDescription => 'Conserva el color más oscuro de los píxeles de origen y destino.';

  @override
  String get blendModeHardLightDescription => 'Aplica multiplicar o pantalla según la intensidad del color de origen, creando un contraste fuerte.';

  @override
  String get blendModeHueDescription => 'Usa el tono del origen y la saturación y luminancia del destino.';

  @override
  String get blendModeLightenDescription => 'Conserva el color más claro de los píxeles de origen y destino.';

  @override
  String get blendModeLinearDodgeDescription => 'Suma los colores de origen y destino, limitando a blanco.';

  @override
  String get blendModeLuminosityDescription => 'Usa la luminancia del origen y el tono y saturación del destino.';

  @override
  String get blendModeMultiplyDescription => 'Multiplica los colores de origen y destino, produciendo una salida más oscura.';

  @override
  String get blendModeNormalDescription => 'Coloca la imagen de origen sobre el destino sin mezclar.';

  @override
  String get blendModeNormalLabel => 'Normal';

  @override
  String get blendModeOverlayDescription => 'Combina los modos multiplicar y pantalla: oscurece las áreas oscuras y aclara las claras.';

  @override
  String get blendModeSaturationDescription => 'Usa la saturación del origen y el tono y luminancia del destino.';

  @override
  String get blendModeScreenDescription => 'Multiplica los inversos del origen y destino, produciendo una salida más clara.';

  @override
  String get blendModeSoftLightDescription => 'Suaviza el contraste oscureciendo o aclarando el destino según el origen.';

  @override
  String get brush => 'Pincel';

  @override
  String get brushStyle => 'Estilo de pincel';

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
  String dimensionsValue(Object width, Object height) {
    return '$width × $height';
  }

  @override
  String get desktopSoftware => 'Aplicacion de escritorio.';

  @override
  String deviceScreenResolution(Object resolution) {
    return 'Resolucion de pantalla: $resolution';
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
  String get editText => 'Editar texto';

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
  String get fontColor => 'Color de fuente';

  @override
  String get fontSizeLabel => 'Tamano de fuente';

  @override
  String fontSizeValue(Object value) {
    return 'Tamano de fuente: $value';
  }

  @override
  String get fpaintLoadImage => 'fPaint Cargar imagen';

  @override
  String get githubRepo => 'Repositorio GitHub';

  @override
  String get gradientPointColor => 'Color del punto de degradado';

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
  String percentageValue(Object value) {
    return 'Escala: $value%';
  }

  @override
  String get platforms => 'Disponible en...';

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
  String savedMessage(Object fileName) {
    return 'Guardado $fileName';
  }

  @override
  String saveLoadedFile(Object fileName) {
    return 'Guardar \"$fileName\"';
  }

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
  String get textColor => 'Color de texto';

  @override
  String get tolerance => 'Tolerancia';

  @override
  String topColors(Object count) {
    return 'Top $count colores';
  }

  @override
  String get transform => 'Transformar';

  @override
  String get unsavedChanges => 'Cambios no guardados';

  @override
  String get unsavedChangesDiscardAndOpenPrompt => 'Tienes cambios no guardados. Quieres descartarlos y abrir el nuevo archivo?';

  @override
  String get useApplePencilOnlySubtitle => 'Si esta activado, solo se usara el Apple Pencil para dibujar.';

  @override
  String get useApplePencilOnlyTitle => 'Usar solo Apple Pencil';

  @override
  String get webBrowser => 'Navegador web';

  @override
  String get width => 'Ancho';
}
