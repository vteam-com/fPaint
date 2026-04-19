import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fpaint/files/export_download_non_web.dart'
    if (dart.library.html) 'package:fpaint/files/export_download_web.dart';
import 'package:fpaint/files/export_file_name.dart';
import 'package:fpaint/files/file_exceptions.dart';
import 'package:fpaint/files/file_tiff.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger(logNameSave);
const String _errorFailedToSaveTiffPrefix = 'Failed to save TIFF file:';

/// Supported save file formats.
enum SaveFileFormat {
  png,
  jpeg,
  ora,
  tiff,
  webp
  ;

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
) async {
  final String fileName = shellProvider.loadedFileName;
  final SaveFileFormat? format = SaveFileFormat.fromFileName(fileName);
  if (format == null) {
    final String extension = fileName.split('.').last.toLowerCase();
    _log.severe('Unsupported file extension for saving: $extension');
    throw UnsupportedSaveFormatException(extension);
  }

  switch (format) {
    case SaveFileFormat.png:
      await saveAsPng(layers, fileName);
      break;
    case SaveFileFormat.jpeg:
      await saveAsJpeg(layers, fileName);
      break;
    case SaveFileFormat.ora:
      await saveAsOra(layers, fileName);
      break;
    case SaveFileFormat.tiff:
      final String normalizedFileName = normalizeTiffExportFileName(fileName);
      await saveAsTiff(layers, normalizedFileName);
      if (shellProvider.loadedFileName != normalizedFileName) {
        shellProvider.loadedFileName = normalizedFileName;
        shellProvider.update();
      }
      break;
    case SaveFileFormat.webp:
      await saveAsWebp(layers, fileName);
      break;
  }
}
