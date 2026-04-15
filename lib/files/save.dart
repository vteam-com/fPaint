import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fpaint/files/export_download_non_web.dart'
    if (dart.library.html) 'package:fpaint/files/export_download_web.dart';
import 'package:fpaint/files/export_file_name.dart';
import 'package:fpaint/files/file_tiff.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger(logNameSave);

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
  } catch (e) {
    _log.severe('Error saving as TIFF to $fileName', e);
    throw Exception('Failed to save as TIFF to $fileName: $e');
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
  final String extension = fileName.split('.').last.toLowerCase();

  switch (extension) {
    case FileExtensions.png:
      await saveAsPng(layers, fileName);
      break;
    case FileExtensions.jpg:
    case FileExtensions.jpeg:
      await saveAsJpeg(layers, fileName);
      break;
    case FileExtensions.ora:
      await saveAsOra(layers, fileName);
      break;
    case FileExtensions.tif:
    case FileExtensions.tiff:
      final String normalizedFileName = normalizeTiffExportFileName(fileName);
      await saveAsTiff(layers, normalizedFileName);
      if (shellProvider.loadedFileName != normalizedFileName) {
        shellProvider.loadedFileName = normalizedFileName;
        shellProvider.update();
      }
      break;
    default:
      // Handle unsupported extension or throw error
      _log.severe('Unsupported file extension for saving: $extension');
      throw Exception('Unsupported file extension for saving: $extension');
  }
}
