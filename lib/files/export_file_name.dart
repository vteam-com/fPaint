import 'package:fpaint/constants/constants.dart';

const String _unixPathSeparator = '/';
const String _windowsPathSeparator = r'\';
const String _extensionSeparator = '.';
const String _tiffExportExtension = '.${FileExtensions.tif}';

/// Base name used for exported files, before the format extension.
const String exportBaseFileName = 'image';

/// Default filename used when exporting layered TIFF files.
const String defaultTiffExportFileName = '$exportBaseFileName$_tiffExportExtension';

/// Ensures TIFF exports always use the canonical `.tif` suffix.
String normalizeTiffExportFileName(String fileNameOrPath) {
  if (fileNameOrPath.isEmpty) {
    return defaultTiffExportFileName;
  }

  final int lastSeparatorIndex = _lastPathSeparatorIndex(fileNameOrPath);
  final int extensionIndex = fileNameOrPath.lastIndexOf(_extensionSeparator);

  if (extensionIndex <= lastSeparatorIndex + 1) {
    return '$fileNameOrPath$_tiffExportExtension';
  }

  return '${fileNameOrPath.substring(0, extensionIndex)}$_tiffExportExtension';
}

int _lastPathSeparatorIndex(String fileNameOrPath) {
  final int unixSeparatorIndex = fileNameOrPath.lastIndexOf(_unixPathSeparator);
  final int windowsSeparatorIndex = fileNameOrPath.lastIndexOf(_windowsPathSeparator);

  return unixSeparatorIndex > windowsSeparatorIndex ? unixSeparatorIndex : windowsSeparatorIndex;
}

/// Returns the lower-case extension of [fileNameOrPath], without the dot.
///
/// Returns an empty string when the last path segment has no extension (or
/// ends with a dot), so a dot in a parent directory name is never mistaken for
/// one.
String fileExtensionOf(String fileNameOrPath) {
  final int extensionIndex = fileNameOrPath.lastIndexOf(_extensionSeparator);
  if (extensionIndex <= _lastPathSeparatorIndex(fileNameOrPath) ||
      extensionIndex == fileNameOrPath.length - AppMath.one) {
    return '';
  }
  return fileNameOrPath.substring(extensionIndex + AppMath.one).toLowerCase();
}

/// Returns the last segment of [path] (its file name), accepting both `/` and
/// `\` as separators.
String fileNameOf(String path) => path.substring(_lastPathSeparatorIndex(path) + AppMath.one);
