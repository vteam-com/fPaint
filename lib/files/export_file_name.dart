import 'package:fpaint/helpers/constants.dart';

const String _unixPathSeparator = '/';
const String _windowsPathSeparator = r'\';
const String _extensionSeparator = '.';
const String _tiffExportExtension = '.${FileExtensions.tif}';

/// Default filename used when exporting layered TIFF files.
const String defaultTiffExportFileName = 'image.${FileExtensions.tif}';

/// Ensures TIFF exports always use the canonical `.tif` suffix.
String normalizeTiffExportFileName(final String fileNameOrPath) {
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

int _lastPathSeparatorIndex(final String fileNameOrPath) {
  final int unixSeparatorIndex = fileNameOrPath.lastIndexOf(_unixPathSeparator);
  final int windowsSeparatorIndex = fileNameOrPath.lastIndexOf(_windowsPathSeparator);

  return unixSeparatorIndex > windowsSeparatorIndex ? unixSeparatorIndex : windowsSeparatorIndex;
}
