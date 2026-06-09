import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/export_file_name.dart';
import 'package:fpaint/files/export_prepare.dart';
import 'package:fpaint/files/file_tiff.dart';
import 'package:fpaint/files/save_backup.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/macos_bookmark_service.dart';

const String _fpaintSaveImageTitle = 'fPaint Save Image';
const String _fpaintSaveImageAsTiffTitle = 'fPaint Save Image as TIFF';
const String _fpaintSaveImageAsHeicTitle = 'fPaint Save Image as HEIC';

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
  final LayersProvider layers, {
  final String fileName = 'image.png',
  final AppPreferences? preferences,
}) async {
  await _exportWithFilePicker(
    dialogTitle: _fpaintSaveImageTitle,
    fileName: fileName,
    allowedExtensions: <String>[FileExtensions.png],
    onFileSelected: (final String filePath) => saveAsPng(layers, filePath),
    preferences: preferences,
  );
}

/// Saves the current painter content as a PNG image file.
Future<void> saveAsPng(
  final LayersProvider layers,
  final String filePath,
) async {
  await File(filePath).writeAsBytes(await preparePngBytes(layers));
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
  final LayersProvider layers, {
  final String fileName = 'image.jpg',
  final AppPreferences? preferences,
}) async {
  await _exportWithFilePicker(
    dialogTitle: _fpaintSaveImageTitle,
    fileName: fileName,
    allowedExtensions: <String>[FileExtensions.jpg, FileExtensions.jpeg],
    onFileSelected: (final String filePath) => saveAsJpeg(layers, filePath),
    preferences: preferences,
  );
}

/// Saves the current painter content as a JPEG image file.
Future<void> saveAsJpeg(
  final LayersProvider layers,
  final String? filePath,
) async {
  if (filePath != null) {
    await File(filePath).writeAsBytes(await prepareJpegBytes(layers));
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
  final LayersProvider layers, {
  final String fileName = 'image.ora',
  final AppPreferences? preferences,
}) async {
  await _exportWithFilePicker(
    dialogTitle: _fpaintSaveImageTitle,
    fileName: fileName,
    allowedExtensions: <String>[FileExtensions.ora],
    onFileSelected: (final String filePath) => saveAsOra(layers, filePath),
    preferences: preferences,
  );
}

/// Saves the current project as an ORA (OpenRaster) file.
Future<void> saveAsOra(
  final LayersProvider layers,
  final String? filePath,
) async {
  if (filePath != null) {
    await File(filePath).writeAsBytes(await prepareOraBytes(layers));
  }
}

/// Opens a save dialog and exports the current canvas as a WebP image file.
Future<void> onExportAsWebp(
  final LayersProvider layers, {
  final String fileName = 'image.webp',
  final AppPreferences? preferences,
}) async {
  await _exportWithFilePicker(
    dialogTitle: _fpaintSaveImageTitle,
    fileName: fileName,
    allowedExtensions: <String>[FileExtensions.webp],
    onFileSelected: (final String filePath) => saveAsWebp(layers, filePath),
    preferences: preferences,
  );
}

/// Opens a save dialog and exports the current canvas as a TIFF file.
Future<void> onExportAsTiff(
  final LayersProvider layers, {
  final String fileName = defaultTiffExportFileName,
  final AppPreferences? preferences,
}) async {
  await _exportWithFilePicker(
    dialogTitle: _fpaintSaveImageAsTiffTitle,
    fileName: normalizeTiffExportFileName(fileName),
    allowedExtensions: <String>[FileExtensions.tif],
    onFileSelected: (final String filePath) => saveAsTiff(layers, filePath),
    preferences: preferences,
    resolveRecentFilePath: normalizeTiffExportFileName,
  );
}

/// Shows a file-save dialog and invokes [onFileSelected] when a valid path is chosen.
Future<void> _exportWithFilePicker({
  required final String dialogTitle,
  required final String fileName,
  required final List<String> allowedExtensions,
  required final Future<void> Function(String) onFileSelected,
  final AppPreferences? preferences,
  final String Function(String)? resolveRecentFilePath,
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
    final String selectedFilePath = resolveRecentFilePath == null ? filePath : resolveRecentFilePath(filePath);
    final String? bookmark =
        preferences?.getBookmark(selectedFilePath) ?? await MacOsBookmarkService.createBookmark(selectedFilePath);

    await saveWithOptionalBackupAndResolvedFileAccess(
      filePath: selectedFilePath,
      bookmarkBase64: bookmark,
      preferences: preferences,
      saveAction: onFileSelected,
    );
    if (preferences != null) {
      await preferences.addRecentFile(selectedFilePath);
    }
  }
}

/// Saves all layers as a layered TIFF file at [filePath].
///
/// If [filePath] is null, the export is skipped.
Future<void> saveAsTiff(
  final LayersProvider layers,
  final String? filePath,
) async {
  if (filePath != null) {
    final String normalizedFilePath = normalizeTiffExportFileName(filePath);
    final Uint8List tiffBytes = await convertLayersToTiff(layers);
    await File(normalizedFilePath).writeAsBytes(tiffBytes);
    layers.clearHasChanged();
  }
}

/// Saves the current painter content as a WebP image file.
Future<void> saveAsWebp(
  final LayersProvider layers,
  final String? filePath,
) async {
  if (filePath != null) {
    await File(filePath).writeAsBytes(await prepareWebpBytes(layers));
  }
}

/// Opens a save dialog and exports the current canvas as a HEIC image file.
Future<void> onExportAsHeic(
  final LayersProvider layers, {
  final String fileName = 'image.heic',
  final AppPreferences? preferences,
}) async {
  await _exportWithFilePicker(
    dialogTitle: _fpaintSaveImageAsHeicTitle,
    fileName: fileName,
    allowedExtensions: <String>[FileExtensions.heic],
    onFileSelected: (final String filePath) => saveAsHeic(layers, filePath),
    preferences: preferences,
  );
}

/// Saves the current painter content as a HEIC image file.
Future<void> saveAsHeic(
  final LayersProvider layers,
  final String? filePath,
) async {
  if (filePath != null) {
    await File(filePath).writeAsBytes(await prepareHeicBytes(layers));
  }
}
