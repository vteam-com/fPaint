import 'package:fpaint/files/export_download_non_web.dart'
    if (dart.library.html) 'package:fpaint/files/export_download_web.dart';
import 'package:fpaint/files/file_operation_exception.dart';
import 'package:fpaint/files/save_backup.dart';
import 'package:fpaint/files/save_file_format.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/macos_bookmark_service.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:logging/logging.dart';

export 'package:fpaint/files/save_file_format.dart';

final Logger _log = Logger(logNameSave);
const String _errorFailedToSaveFilePrefix = 'Failed to save file:';

/// Exports the canvas in [format], prompting for a destination where the
/// platform has one.
///
/// The dialog title, offered extensions, suggested name and file-name
/// normalization all come from [format], so adding a format needs no change
/// here (Open/Closed).
Future<void> exportAs(
  SaveFileFormat format,
  LayersProvider layers, {
  String? fileName,
  AppPreferences? preferences,
}) async {
  await exportToDestination(
    dialogTitle: format.exportDialogTitle,
    suggestedFileName: format.normalizeFileName(fileName ?? format.defaultExportFileName),
    allowedExtensions: format.pickerExtensions,
    write: (String filePath) => format.write(layers, filePath),
    preferences: preferences,
    resolveRecentFilePath: format.normalizeFileName,
  );
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
