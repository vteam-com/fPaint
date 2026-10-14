import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fpaint/files/save_backup.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/security_scoped_file_service.dart';

/// Writes already-encoded export [bytes] to [filePath].
Future<void> writeExportBytes(
  String filePath,
  Uint8List bytes,
) async {
  await File(filePath).writeAsBytes(bytes);
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
        preferences?.getBookmark(selectedFilePath) ?? await SecurityScopedFileService.createBookmark(selectedFilePath);

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
