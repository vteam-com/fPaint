import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/export_download_non_web.dart'
    if (dart.library.html) 'package:fpaint/files/export_download_web.dart';
import 'package:fpaint/files/export_file_name.dart';
import 'package:fpaint/files/file_operation_exception.dart';
import 'package:fpaint/files/save_backup.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/macos_bookmark_service.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger(logNameSave);
const String _errorFailedToSaveFilePrefix = 'Failed to save file:';

/// Writes [layers] to [fileName] in one concrete format.
typedef SaveFormatWriter = Future<void> Function(LayersProvider layers, String fileName);

/// Normalizes the target file name before saving (e.g. collapsing `.tiff` to
/// `.tif`). Returns the name unchanged by default.
typedef SaveFormatFileNameNormalizer = String Function(String fileName);

String _unchangedFileName(String fileName) => fileName;

/// Static metadata and writer for a save format.
///
/// Holding the extensions, the writer and the layer capability together keeps
/// adding a format to a single enum entry: no dispatch `switch` elsewhere has
/// to be edited (Open/Closed).
class _SaveFormatConfig {
  const _SaveFormatConfig({
    required this.extensions,
    required this.write,
    this.supportsLayers = false,
    this.normalizeFileName = _unchangedFileName,
  });

  /// Every file extension that maps to this format; the first is canonical.
  final List<String> extensions;

  /// Writes the document in this format.
  final SaveFormatWriter write;

  /// Whether the format embeds individual layers (and can therefore store the
  /// selected layer inside the file). Flat formats rely on a preference keyed
  /// by file path instead.
  final bool supportsLayers;

  /// Adjusts the target file name before saving.
  final SaveFormatFileNameNormalizer normalizeFileName;
}

/// Supported save file formats.
enum SaveFileFormat {
  png(
    _SaveFormatConfig(
      extensions: <String>[FileExtensions.png],
      write: saveAsPng,
    ),
  ),
  jpeg(
    _SaveFormatConfig(
      extensions: <String>[FileExtensions.jpg, FileExtensions.jpeg],
      write: saveAsJpeg,
    ),
  ),
  ora(
    _SaveFormatConfig(
      extensions: <String>[FileExtensions.ora],
      write: saveAsOra,
      supportsLayers: true,
    ),
  ),
  tiff(
    _SaveFormatConfig(
      extensions: <String>[FileExtensions.tif, FileExtensions.tiff],
      write: saveAsTiff,
      supportsLayers: true,
      normalizeFileName: normalizeTiffExportFileName,
    ),
  ),
  webp(
    _SaveFormatConfig(
      extensions: <String>[FileExtensions.webp],
      write: saveAsWebp,
    ),
  ),
  heic(
    _SaveFormatConfig(
      extensions: <String>[FileExtensions.heic],
      write: saveAsHeic,
    ),
  );

  const SaveFileFormat(this._config);

  final _SaveFormatConfig _config;

  /// Every file extension that maps to this format; the first is canonical.
  List<String> get extensions => _config.extensions;

  /// Whether the format embeds individual layers (and can therefore store the
  /// selected layer inside the file). Flat formats rely on a preference keyed
  /// by file path instead.
  bool get supportsLayers => _config.supportsLayers;

  /// Adjusts [fileName] to the canonical name this format writes.
  String normalizeFileName(String fileName) => _config.normalizeFileName(fileName);

  /// Writes [layers] to [fileName] in this format.
  Future<void> write(LayersProvider layers, String fileName) => _config.write(layers, fileName);

  /// Resolves a save format from a file extension, or null when unsupported.
  static SaveFileFormat? fromExtension(String extension) {
    final String normalized = extension.toLowerCase();
    for (final SaveFileFormat format in SaveFileFormat.values) {
      if (format._config.extensions.contains(normalized)) {
        return format;
      }
    }
    return null;
  }

  /// Resolves a save format from a file name.
  static SaveFileFormat? fromFileName(String fileName) => fromExtension(fileName.split('.').last);
}

/// Saves a file asynchronously.
///
/// This function handles the process of saving a file to the desired location.
/// It performs the necessary operations to ensure the file is saved correctly.
///
/// Returns a [Future] that completes when the file has been successfully saved.
Future<void> saveFile(
  ShellProvider shellProvider,
  LayersProvider layers,
  AppPreferences preferences,
) async {
  final String fileName = shellProvider.loadedFileName;
  final SaveFileFormat? format = SaveFileFormat.fromFileName(fileName);
  if (format == null) {
    final String extension = fileName.split('.').last.toLowerCase();
    _log.severe('Unsupported file extension for saving: $extension');
    throw UnsupportedSaveFormatException(extension);
  }

  try {
    final String targetFileName = format.normalizeFileName(fileName);
    await _saveWithResolvedFileAccess(
      preferences: preferences,
      fileName: targetFileName,
      saveAction: (String resolvedFileName) => format.write(layers, resolvedFileName),
    );

    // A normalizing format (TIFF) may have retargeted the document.
    if (shellProvider.loadedFileName != targetFileName) {
      shellProvider.loadedFileName = targetFileName;
      shellProvider.update();
    }

    // Layered formats embed the selection; flat formats remember it per path.
    if (!format.supportsLayers) {
      await preferences.recordLastSelectedLayer(fileName, layers.selectedLayerIndex);
    }

    layers.clearHasChanged();
  } on FileOperationException {
    rethrow;
  } catch (error, stackTrace) {
    _log.severe('Error saving file to $fileName', error, stackTrace);
    Error.throwWithStackTrace(
      FileSaveException('$_errorFailedToSaveFilePrefix "$fileName"', cause: error),
      stackTrace,
    );
  }
}
/// Saves a file through the macOS security-scoped bookmark when one exists.
Future<void> _saveWithResolvedFileAccess({
  required AppPreferences preferences,
  required String fileName,
  required Future<void> Function(String) saveAction,
}) async {
  final String? existingBookmark = preferences.getBookmark(fileName);
  final String? bookmark = existingBookmark ?? await MacOsBookmarkService.createBookmark(fileName);

  await saveWithOptionalBackupAndResolvedFileAccess(
    filePath: fileName,
    bookmarkBase64: bookmark,
    preferences: preferences,
    saveAction: saveAction,
  );

  if (existingBookmark == null && bookmark != null) {
    await preferences.addRecentFile(fileName);
  }
}
