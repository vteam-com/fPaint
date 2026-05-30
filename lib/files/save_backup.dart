import 'dart:io';

import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/macos_bookmark_service.dart';
import 'package:fpaint/providers/app_preferences.dart';

const String _backupFileNameMarker = '_back-';
const String _temporarySaveFileNamePrefix = 'fpaint-save-';
typedef BackupFileAction = Future<File> Function(File targetFile);

/// Resolves sandboxed file access before saving with optional backup rotation.
Future<void> saveWithOptionalBackupAndResolvedFileAccess({
  required final String filePath,
  required final String? bookmarkBase64,
  required final AppPreferences? preferences,
  required final Future<void> Function(String) saveAction,
}) async {
  await MacOsBookmarkService.withResolvedBookmark<void>(
    bookmarkBase64: bookmarkBase64,
    fallbackPath: filePath,
    action: (final String resolvedFilePath) => saveWithOptionalBackup(
      filePath: resolvedFilePath,
      preferences: preferences,
      saveAction: saveAction,
    ),
  );
}

/// Saves [filePath], optionally rotating the existing file into a backup first.
Future<void> saveWithOptionalBackup({
  required final String filePath,
  required final AppPreferences? preferences,
  required final Future<void> Function(String) saveAction,
  final BackupFileAction backupAction = _renameCurrentFileToBackup,
}) async {
  final File targetFile = File(filePath);
  final bool keepSaveBackups = preferences?.keepSaveBackups ?? AppDefaults.keepSaveBackups;
  final bool targetExists = await targetFile.exists();
  File? backupFile;

  if (keepSaveBackups && targetExists) {
    final bool replacedWithBackup = await _trySaveWithSecurityScopedBackupReplacement(
      targetFile: targetFile,
      saveAction: saveAction,
    );
    if (replacedWithBackup) {
      await _pruneOldBackups(targetFile);
      return;
    }

    try {
      backupFile = await backupAction(targetFile);
    } on FileSystemException {
      // Some sandboxed paths allow overwriting the selected file but reject sibling backups.
      backupFile = null;
    }
  }

  try {
    await saveAction(filePath);
  } catch (_) {
    if (backupFile != null) {
      await _restoreBackupFile(
        targetFile: targetFile,
        backupFile: backupFile,
      );
    }
    rethrow;
  }

  if (backupFile != null) {
    await _pruneOldBackups(targetFile);
  }
}

/// Tries the macOS native replace flow that keeps a sibling backup file.
Future<bool> _trySaveWithSecurityScopedBackupReplacement({
  required final File targetFile,
  required final Future<void> Function(String) saveAction,
}) async {
  if (!MacOsBookmarkService.supportsReplaceFileWithBackup) {
    return false;
  }

  final DateTime timestamp = DateTime.now();
  final File temporaryFile = _buildTemporarySaveFile(targetFile, timestamp);
  try {
    await saveAction(temporaryFile.path);
    return MacOsBookmarkService.replaceFileWithBackup(
      targetPath: targetFile.path,
      replacementPath: temporaryFile.path,
      backupFileName: _buildBackupFileName(targetFile, timestamp),
    );
  } finally {
    await _deleteTemporarySaveFileIfPresent(temporaryFile);
  }
}

/// Best-effort cleanup for temporary save files consumed by native replace.
Future<void> _deleteTemporarySaveFileIfPresent(final File temporaryFile) async {
  try {
    if (await temporaryFile.exists()) {
      await temporaryFile.delete();
    }
  } on FileSystemException {
    // Native replacement can move or remove the temp file before Dart cleanup runs.
  }
}

/// Renames the current [targetFile] into a timestamped backup file.
Future<File> _renameCurrentFileToBackup(final File targetFile) {
  final String backupPath = _buildBackupPath(
    targetFile,
    DateTime.now(),
  );
  return targetFile.rename(backupPath);
}

/// Restores [backupFile] back into [targetFile] after a failed save attempt.
Future<void> _restoreBackupFile({
  required final File targetFile,
  required final File backupFile,
}) async {
  if (!await backupFile.exists()) {
    return;
  }

  if (await targetFile.exists()) {
    await targetFile.delete();
  }

  await backupFile.rename(targetFile.path);
}

/// Removes older backups once the backup count exceeds the configured limit.
Future<void> _pruneOldBackups(final File targetFile) async {
  final List<File> backupFiles = await _listBackupFiles(targetFile);
  if (backupFiles.length <= AppLimits.maxSaveFileBackups) {
    return;
  }

  final List<({File file, DateTime modified})> orderedBackups = <({File file, DateTime modified})>[];
  for (final File file in backupFiles) {
    orderedBackups.add((file: file, modified: await file.lastModified()));
  }

  orderedBackups.sort(
    (final ({File file, DateTime modified}) a, final ({File file, DateTime modified}) b) =>
        a.modified.compareTo(b.modified),
  );

  final int backupsToDelete = orderedBackups.length - AppLimits.maxSaveFileBackups;
  for (final ({File file, DateTime modified}) entry in orderedBackups.take(backupsToDelete)) {
    await entry.file.delete();
  }
}

/// Returns all backup files that belong to [targetFile].
Future<List<File>> _listBackupFiles(final File targetFile) async {
  final ({String extension, String stem}) nameParts = _splitFileName(targetFile);
  final String extension = nameParts.extension;
  final String stem = nameParts.stem;
  final String backupPrefix = '$stem$_backupFileNameMarker';
  final List<File> backupFiles = <File>[];

  await for (final FileSystemEntity entity in targetFile.parent.list()) {
    if (entity is! File) {
      continue;
    }

    final String candidateName = _fileNameFor(entity);
    if (candidateName.startsWith(backupPrefix) && candidateName.endsWith(extension)) {
      backupFiles.add(entity);
    }
  }

  return backupFiles;
}

/// Builds the backup file path for [targetFile] using [timestamp].
String _buildBackupPath(
  final File targetFile,
  final DateTime timestamp,
) {
  final String backupFileName = _buildBackupFileName(targetFile, timestamp);
  return '${targetFile.parent.path}${Platform.pathSeparator}$backupFileName';
}

/// Builds the sibling backup file name for [targetFile] using [timestamp].
String _buildBackupFileName(
  final File targetFile,
  final DateTime timestamp,
) {
  final ({String extension, String stem}) nameParts = _splitFileName(targetFile);
  return '${nameParts.stem}$_backupFileNameMarker${_formatBackupTimestamp(timestamp)}${nameParts.extension}';
}

/// Builds a temporary output file that preserves [targetFile]'s extension.
File _buildTemporarySaveFile(
  final File targetFile,
  final DateTime timestamp,
) {
  final ({String extension, String stem}) nameParts = _splitFileName(targetFile);
  final String temporaryFileName =
      '$_temporarySaveFileNamePrefix${nameParts.stem}-${_formatBackupTimestamp(timestamp)}${nameParts.extension}';
  return File('${Directory.systemTemp.path}${Platform.pathSeparator}$temporaryFileName');
}

/// Formats [timestamp] for deterministic, sortable backup file names.
String _formatBackupTimestamp(final DateTime timestamp) {
  final String year = timestamp.year.toString().padLeft(AppMath.four, '0');
  final String month = timestamp.month.toString().padLeft(AppMath.two, '0');
  final String day = timestamp.day.toString().padLeft(AppMath.two, '0');
  final String hour = timestamp.hour.toString().padLeft(AppMath.two, '0');
  final String minute = timestamp.minute.toString().padLeft(AppMath.two, '0');
  final String second = timestamp.second.toString().padLeft(AppMath.two, '0');
  final String millisecond = timestamp.millisecond.toString().padLeft(AppMath.triple, '0');
  final String microsecond = timestamp.microsecond.toString().padLeft(AppMath.triple, '0');
  return '$year$month$day-$hour$minute$second-$millisecond$microsecond';
}

/// Returns the file name portion of [entity].
String _fileNameFor(final FileSystemEntity entity) {
  final List<String> pathSegments = entity.uri.pathSegments;
  if (pathSegments.isEmpty) {
    return entity.path;
  }
  return pathSegments.last;
}

/// Splits [entity]'s file name into a stem and extension.
({String extension, String stem}) _splitFileName(final FileSystemEntity entity) {
  final String fileName = _fileNameFor(entity);
  final int extensionSeparator = fileName.lastIndexOf('.');
  final String extension = extensionSeparator >= AppMath.zero ? fileName.substring(extensionSeparator) : '';
  final String stem = extensionSeparator >= AppMath.zero
      ? fileName.substring(AppMath.zero, extensionSeparator)
      : fileName;
  return (extension: extension, stem: stem);
}
