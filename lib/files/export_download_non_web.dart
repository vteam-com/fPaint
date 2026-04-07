import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fpaint/files/file_jpeg.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/files/file_tiff.dart';
import 'package:fpaint/providers/layers_provider.dart';

/// Exports the current painter content as a PNG image file.
///
/// This function captures the current state of the painter as image bytes
/// and prompts the user to save the image as a PNG file. The user is presented
/// with a file save dialog to choose the location and name of the file.
///
/// The function performs the following steps:
/// 1. Retrieves the current `AppProvider` from the provided `BuildContext`.
/// 2. Opens a file save dialog for the user to specify the file path and name.
/// 3. Captures the painter content as image bytes.
/// 4. Writes the image bytes to the specified file path.
///
/// Parameters:
/// - `context`: The `BuildContext` used to retrieve the `AppProvider`.
///
/// Returns:
/// - A `Future<void>` that completes when the image has been successfully saved.
Future<void> onExportAsPng(
  final LayersProvider layers, [
  final String fileName = 'image.png',
]) async {
  await _exportWithFilePicker(
    dialogTitle: 'fPaint Save Image',
    fileName: fileName,
    allowedExtensions: <String>['png'],
    onFileSelected: (final String filePath) => saveAsPng(layers, filePath),
  );
}

/// Saves the current painter content as a PNG image file.
///
/// Captures the painter's current state as image bytes and writes them
/// to the specified file path.
///
/// Parameters:
/// - `layers`: The `LayersProvider` containing the current painter state.
/// - `filePath`: The destination file path where the PNG image will be saved.
///
/// Returns:
/// - A `Future<void>` that completes when the image has been written to disk.
Future<void> saveAsPng(
  final LayersProvider layers,
  final String filePath,
) async {
  // Capture the image bytes
  final Uint8List bytes = await layers.capturePainterToImageBytes();
  await File(filePath).writeAsBytes(bytes);
}

/// Exports the current painter content as a JPG image file.
///
/// This function captures the current state of the painter as image bytes
/// and prompts the user to save the image as a JPG file. The user is presented
/// with a file save dialog to choose the location and name of the file.
///
/// The function performs the following steps:
/// 1. Retrieves the current `AppProvider` from the provided `BuildContext`.
/// 2. Opens a file save dialog for the user to specify the file path and name.
/// 3. Captures the painter content as image bytes.
/// 4. Writes the image bytes to the specified file path.
///
/// Parameters:
/// - `context`: The `BuildContext` used to retrieve the `AppProvider`.
///
/// Returns:
/// - A `Future<void>` that completes when the image has been successfully saved.
Future<void> onExportAsJpeg(
  final LayersProvider layers, [
  final String fileName = 'image.jpg',
]) async {
  final String? filePath = await FilePicker.saveFile(
    dialogTitle: 'Save image',
    fileName: fileName,
    allowedExtensions: <String>['jpg', 'jpeg'],
    type: FileType.custom,
  );
  await saveAsJpeg(layers, filePath);
}

/// Saves the current painter content as a JPEG image file.
///
/// Captures the painter's current state as image bytes, converts them to JPEG format,
/// and writes the resulting bytes to the specified file path.
///
/// Parameters:
/// - `layers`: The `LayersProvider` containing the current painter state.
/// - `filePath`: The destination file path where the JPEG image will be saved.
///
/// Returns:
/// - A `Future<void>` that completes when the image has been written to disk.
/// Only saves the file if a valid file path is provided.
Future<void> saveAsJpeg(
  final LayersProvider layers,
  final String? filePath,
) async {
  if (filePath != null) {
    // Capture the image bytes
    final Uint8List imageBytes = await layers.capturePainterToImageBytes();

    // Convert the image bytes to JPG format
    final Uint8List outputBytes = await convertToJpg(imageBytes);
    await File(filePath).writeAsBytes(outputBytes);
  }
}

/// Exports the current project as an ORA (OpenRaster) file.
///
/// This function handles the export process, converting the current project
/// into an ORA file format, which is a standard format for layered images.
///
/// The function is asynchronous and returns a [Future] that completes when
/// the export process is finished.
///
/// Throws an [Exception] if the export process fails.
Future<void> onExportAsOra(
  final LayersProvider layers, [
  final String fileName = 'image.jpg',
]) async {
  final String? filePath = await FilePicker.saveFile(
    dialogTitle: 'Save image',
    fileName: fileName,
    allowedExtensions: <String>['ora'],
    type: FileType.custom,
  );
  await saveAsOra(layers, filePath);
}

/// Saves the current project as an ORA (OpenRaster) file.
///
/// Converts the current project layers into an ORA file format and writes
/// the encoded data to the specified file path.
///
/// Parameters:
/// - `layers`: The `LayersProvider` containing the current project layers.
/// - `filePath`: The destination file path where the ORA file will be saved.
///
/// Returns:
/// - A `Future<void>` that completes when the ORA file has been written to disk.
/// Only saves the file if a valid file path is provided.
Future<void> saveAsOra(
  final LayersProvider layers,
  final String? filePath,
) async {
  if (filePath != null) {
    final List<int> encodedData = await createOraAchive(layers);
    await File(filePath).writeAsBytes(encodedData);
  }
}

/// Opens a save dialog and exports the current canvas as a TIFF file.
Future<void> onExportAsTiff(
  final LayersProvider layers, [
  final String fileName = 'image.tiff',
]) async {
  await _exportWithFilePicker(
    dialogTitle: 'fPaint Save Image as TIFF',
    fileName: fileName,
    allowedExtensions: <String>['tif', 'tiff'],
    onFileSelected: (final String filePath) => saveAsTiff(layers, filePath),
  );
}

/// Shows a file-save dialog and invokes [onFileSelected] when a valid path is chosen.
Future<void> _exportWithFilePicker({
  required final String dialogTitle,
  required final String fileName,
  required final List<String> allowedExtensions,
  required final Future<void> Function(String) onFileSelected,
}) async {
  final String? filePath = await FilePicker.saveFile(
    dialogTitle: dialogTitle,
    initialDirectory: '.',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    lockParentWindow: true,
  );
  if (filePath != null && filePath.isNotEmpty) {
    await onFileSelected(filePath);
  }
}

/// Saves the current canvas as a TIFF file at [filePath].
///
/// If [filePath] is null, the export is skipped.
Future<void> saveAsTiff(
  final LayersProvider layers,
  final String? filePath,
) async {
  if (filePath != null) {
    final Uint8List pngBytes = await layers.capturePainterToImageBytes();
    if (pngBytes.isEmpty) {
      throw Exception('Failed to capture image bytes for TIFF export.');
    }
    final Uint8List tiffBytes = await convertToTiff(pngBytes);
    await File(filePath).writeAsBytes(tiffBytes);
    layers.clearHasChanged();
  }
}
