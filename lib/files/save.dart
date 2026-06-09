import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/export_download_non_web.dart'
    if (dart.library.html) 'package:fpaint/files/export_download_web.dart';
import 'package:fpaint/files/export_file_name.dart';
import 'package:fpaint/files/file_operation_exception.dart';
import 'package:fpaint/files/file_tiff.dart';
import 'package:fpaint/files/save_backup.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/macos_bookmark_service.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger(logNameSave);
const String _errorFailedToSaveFilePrefix = 'Failed to save file:';
const String _errorFailedToSaveTiffPrefix = 'Failed to save TIFF file:';

/// Supported save file formats.
enum SaveFileFormat {
  png,
  jpeg,
  ora,
  tiff,
  webp,
  heic;

  /// Resolves a save format from a file name.
  static SaveFileFormat? fromFileName(final String fileName) {
    final String extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case FileExtensions.png:
        return SaveFileFormat.png;
      case FileExtensions.jpg:
      case FileExtensions.jpeg:
        return SaveFileFormat.jpeg;
      case FileExtensions.ora:
        return SaveFileFormat.ora;
      case FileExtensions.tif:
      case FileExtensions.tiff:
        return SaveFileFormat.tiff;
      case FileExtensions.webp:
        return SaveFileFormat.webp;
      case FileExtensions.heic:
        return SaveFileFormat.heic;
      default:
        return null;
    }
  }
}

/// Saves all layers as a layered TIFF file.
Future<void> saveAsTiff(
  final LayersProvider layers,
  final String fileName,
) async {
  try {
    final String normalizedFileName = normalizeTiffExportFileName(fileName);
    final Uint8List tiffBytes = await convertLayersToTiff(layers);
    await File(normalizedFileName).writeAsBytes(tiffBytes);
    layers.clearHasChanged();
  } on FileOperationException {
    rethrow;
  } catch (error, stackTrace) {
    _log.severe('Error saving as TIFF to $fileName', error, stackTrace);
    Error.throwWithStackTrace(
      FileSaveException('$_errorFailedToSaveTiffPrefix "$fileName"', cause: error),
      stackTrace,
    );
  }
}

/// Saves a file asynchronously.
///
/// This function handles the process of saving a file to the desired location.
/// It performs the necessary operations to ensure the file is saved correctly.
///
/// Returns a [Future] that completes when the file has been successfully saved.
Future<void> saveFile(
  final ShellProvider shellProvider,
  final LayersProvider layers,
  final AppPreferences preferences,
) async {
  final String fileName = shellProvider.loadedFileName;
  final SaveFileFormat? format = SaveFileFormat.fromFileName(fileName);
  if (format == null) {
    final String extension = fileName.split('.').last.toLowerCase();
    _log.severe('Unsupported file extension for saving: $extension');
    throw UnsupportedSaveFormatException(extension);
  }

  try {
    switch (format) {
      case SaveFileFormat.png:
        await _saveWithResolvedFileAccess(
          preferences: preferences,
          fileName: fileName,
          saveAction: (final String resolvedFileName) => saveAsPng(layers, resolvedFileName),
        );
        break;
      case SaveFileFormat.jpeg:
        await _saveWithResolvedFileAccess(
          preferences: preferences,
          fileName: fileName,
          saveAction: (final String resolvedFileName) => saveAsJpeg(layers, resolvedFileName),
        );
        break;
      case SaveFileFormat.ora:
        await _saveWithResolvedFileAccess(
          preferences: preferences,
          fileName: fileName,
          saveAction: (final String resolvedFileName) => saveAsOra(layers, resolvedFileName),
        );
        break;
      case SaveFileFormat.tiff:
        final String normalizedFileName = normalizeTiffExportFileName(fileName);
        await _saveWithResolvedFileAccess(
          preferences: preferences,
          fileName: normalizedFileName,
          saveAction: (final String resolvedFileName) => saveAsTiff(layers, resolvedFileName),
        );
        if (shellProvider.loadedFileName != normalizedFileName) {
          shellProvider.loadedFileName = normalizedFileName;
          shellProvider.update();
        }
        break;
      case SaveFileFormat.webp:
        await _saveWithResolvedFileAccess(
          preferences: preferences,
          fileName: fileName,
          saveAction: (final String resolvedFileName) => saveAsWebp(layers, resolvedFileName),
        );
        break;
      case SaveFileFormat.heic:
        await _saveWithResolvedFileAccess(
          preferences: preferences,
          fileName: fileName,
          saveAction: (final String resolvedFileName) => saveAsHeic(layers, resolvedFileName),
        );
        break;
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
  required final AppPreferences preferences,
  required final String fileName,
  required final Future<void> Function(String) saveAction,
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
