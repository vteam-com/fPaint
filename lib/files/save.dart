import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:fpaint/files/export_download_non_web.dart'
    if (dart.library.html) 'package:fpaint/files/export_download_web.dart';
import 'package:fpaint/files/file_tiff.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';

/// Saves the current image as a TIFF file.
Future<void> saveAsTiff(
  final LayersProvider layers,
  final String fileName,
) async {
  try {
    // 1. Get the full image from LayersProvider.
    final Uint8List pngBytes = await layers.capturePainterToImageBytes();
    if (pngBytes.isEmpty) {
      throw Exception('Failed to capture image for saving as TIFF.');
    }

    // 2. Convert these PNG bytes to TIFF format.
    final Uint8List tiffBytes = await convertToTiff(pngBytes);

    // 3. Use File(fileName).writeAsBytes to save the TIFF bytes.
    await File(fileName).writeAsBytes(tiffBytes);
    layers.clearHasChanged(); // Mark changes as saved
  } catch (e) {
    // Handle or log the error appropriately
    debugPrint('Error saving as TIFF to $fileName: $e');
    // Optionally, rethrow or show a user-facing error
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
    case 'png':
      await saveAsPng(layers, fileName);
      break;
    case 'jpg':
    case 'jpeg':
      await saveAsJpeg(layers, fileName);
      break;
    case 'ora':
      await saveAsOra(layers, fileName);
      break;
    case 'tif':
    case 'tiff':
      await saveAsTiff(layers, fileName);
      break;
    default:
      // Handle unsupported extension or throw error
      debugPrint('Unsupported file extension for saving: $extension');
      throw Exception('Unsupported file extension for saving: $extension');
  }
}
