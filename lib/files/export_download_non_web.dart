import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fpaint/files/export_file_name.dart';
import 'package:fpaint/files/export_prepare.dart';
import 'package:fpaint/files/file_tiff.dart';
import 'package:fpaint/files/save_backup.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/macos_bookmark_service.dart';

/// Saves the current painter content as a PNG image file.
Future<void> saveAsPng(
  LayersProvider layers,
  String filePath,
) async {
  await File(filePath).writeAsBytes(await preparePngBytes(layers));
}

/// Saves the current painter content as a JPEG image file.
Future<void> saveAsJpeg(
  LayersProvider layers,
  String? filePath,
) async {
  if (filePath != null) {
    await File(filePath).writeAsBytes(await prepareJpegBytes(layers));
  }
}

/// Saves the current project as an ORA (OpenRaster) file.
Future<void> saveAsOra(
  LayersProvider layers,
  String? filePath,
) async {
  if (filePath != null) {
    await File(filePath).writeAsBytes(await prepareOraBytes(layers));
  }
}

/// Converts a save-dialog [Uri] into a local file path.
///
/// `FilePicker.saveFile` returns a `file://` URI on Linux and Windows, and a
/// bare path (parsed as a scheme-less URI) on macOS and iOS, so both shapes are
/// handled here.
String? filePathFromPickerUri(Uri? uri) {
  if (uri == null) {
    return null;
  }
  final String filePath = uri.scheme == 'file' ? uri.toFilePath() : uri.path;
  return filePath.isEmpty ? null : filePath;
}

/// Prompts for a destination and writes the file there.
///
/// Format-agnostic on purpose: the caller supplies the dialog text, the
/// offered extensions and the writer, so this file never needs to know the
/// set of save formats (and stays below `save.dart` in the dependency graph).
Future<void> exportToDestination({
  required String dialogTitle,
  required String suggestedFileName,
  required List<String> allowedExtensions,
  required Future<void> Function(String) write,
  AppPreferences? preferences,
  String Function(String)? resolveRecentFilePath,
}) async {
  await _exportWithFilePicker(
    dialogTitle: dialogTitle,
    fileName: suggestedFileName,
    allowedExtensions: allowedExtensions,
    onFileSelected: write,
    preferences: preferences,
    resolveRecentFilePath: resolveRecentFilePath,
  );
}

/// Shows a file-save dialog and invokes [onFileSelected] when a valid path is chosen.
Future<void> _exportWithFilePicker({
  required String dialogTitle,
  required String fileName,
  required List<String> allowedExtensions,
  required Future<void> Function(String) onFileSelected,
  AppPreferences? preferences,
  String Function(String)? resolveRecentFilePath,
}) async {
  final Uri? selectedFileUri = await FilePicker.saveFile(
    dialogTitle: dialogTitle,
    initialDirectory: '.',
    fileName: fileName,
    // The dialog only chooses a destination here; the real bytes are written by
    // [onFileSelected], which also handles backup rotation and bookmark access.
    bytes: Uint8List(0),
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    windowsOptions: const WindowsOptions(lockParentWindow: true),
    linuxOptions: const LinuxOptions(lockParentWindow: true),
  );
  final String? filePath = filePathFromPickerUri(selectedFileUri);
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
  LayersProvider layers,
  String? filePath,
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
  LayersProvider layers,
  String? filePath,
) async {
  if (filePath != null) {
    await File(filePath).writeAsBytes(await prepareWebpBytes(layers));
  }
}

/// Saves the current painter content as a HEIC image file.
Future<void> saveAsHeic(
  LayersProvider layers,
  String? filePath,
) async {
  if (filePath != null) {
    await File(filePath).writeAsBytes(await prepareHeicBytes(layers));
  }
}
