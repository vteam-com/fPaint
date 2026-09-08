import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/export_download_non_web.dart'
    if (dart.library.html) 'package:fpaint/files/export_download_web.dart';
import 'package:fpaint/files/export_file_name.dart';
import 'package:fpaint/providers/layers_provider.dart';

const String _saveImageTitle = 'fPaint Save Image';
const String _saveImageAsTiffTitle = 'fPaint Save Image as TIFF';
const String _saveImageAsHeicTitle = 'fPaint Save Image as HEIC';

/// Writes [layers] to [fileName] in one concrete format.
typedef SaveFormatWriter = Future<void> Function(LayersProvider layers, String fileName);

/// Normalizes the target file name before saving (e.g. collapsing `.tiff` to
/// `.tif`). Returns the name unchanged by default.
typedef SaveFormatFileNameNormalizer = String Function(String fileName);

String _unchangedFileName(String fileName) => fileName;

/// Static metadata and writer for a save format.
///
/// Holding the extensions, the writer and the layer capability together keeps
/// adding a format to a single enum entry: no dispatch `switch` elsewhere has
/// to be edited (Open/Closed).
class _SaveFormatConfig {
  const _SaveFormatConfig({
    required this.extensions,
    required this.write,
    required this.defaultExportFileName,
    this.supportsLayers = false,
    this.normalizeFileName = _unchangedFileName,
    this.pickerExtensions,
    this.exportDialogTitle = _saveImageTitle,
  });

  /// Every file extension that maps to this format; the first is canonical.
  final List<String> extensions;

  /// Writes the document in this format.
  final SaveFormatWriter write;

  /// Suggested file name when exporting with no name in hand.
  final String defaultExportFileName;

  /// Whether the format embeds individual layers (and can therefore store the
  /// selected layer inside the file). Flat formats rely on a preference keyed
  /// by file path instead.
  final bool supportsLayers;

  /// Adjusts the target file name before saving.
  final SaveFormatFileNameNormalizer normalizeFileName;

  /// Extensions offered in the save dialog, when narrower than [extensions].
  /// TIFF accepts `.tiff` on open but only ever writes the canonical `.tif`.
  final List<String>? pickerExtensions;

  /// Title shown on the export save dialog.
  final String exportDialogTitle;
}

/// Supported save file formats.
enum SaveFileFormat {
  png(
    _SaveFormatConfig(
      extensions: <String>[FileExtensions.png],
      write: saveAsPng,
      defaultExportFileName: '$exportBaseFileName.${FileExtensions.png}',
    ),
  ),
  jpeg(
    _SaveFormatConfig(
      extensions: <String>[FileExtensions.jpg, FileExtensions.jpeg],
      write: saveAsJpeg,
      defaultExportFileName: '$exportBaseFileName.${FileExtensions.jpg}',
    ),
  ),
  ora(
    _SaveFormatConfig(
      extensions: <String>[FileExtensions.ora],
      write: saveAsOra,
      defaultExportFileName: '$exportBaseFileName.${FileExtensions.ora}',
      supportsLayers: true,
    ),
  ),
  tiff(
    _SaveFormatConfig(
      extensions: <String>[FileExtensions.tif, FileExtensions.tiff],
      write: saveAsTiff,
      defaultExportFileName: defaultTiffExportFileName,
      supportsLayers: true,
      normalizeFileName: normalizeTiffExportFileName,
      pickerExtensions: <String>[FileExtensions.tif],
      exportDialogTitle: _saveImageAsTiffTitle,
    ),
  ),
  webp(
    _SaveFormatConfig(
      extensions: <String>[FileExtensions.webp],
      write: saveAsWebp,
      defaultExportFileName: '$exportBaseFileName.${FileExtensions.webp}',
    ),
  ),
  heic(
    _SaveFormatConfig(
      extensions: <String>[FileExtensions.heic],
      write: saveAsHeic,
      defaultExportFileName: '$exportBaseFileName.${FileExtensions.heic}',
      exportDialogTitle: _saveImageAsHeicTitle,
    ),
  );

  const SaveFileFormat(this._config);

  final _SaveFormatConfig _config;

  /// Every file extension that maps to this format; the first is canonical.
  List<String> get extensions => _config.extensions;

  /// Whether the format embeds individual layers (and can therefore store the
  /// selected layer inside the file). Flat formats rely on a preference keyed
  /// by file path instead.
  bool get supportsLayers => _config.supportsLayers;

  /// Adjusts [fileName] to the canonical name this format writes.
  String normalizeFileName(String fileName) => _config.normalizeFileName(fileName);

  /// Suggested file name when exporting with no name in hand.
  String get defaultExportFileName => _config.defaultExportFileName;

  /// Extensions offered in the export save dialog.
  List<String> get pickerExtensions => _config.pickerExtensions ?? _config.extensions;

  /// Title shown on the export save dialog.
  String get exportDialogTitle => _config.exportDialogTitle;

  /// Upper-case label for this format, e.g. `PNG`.
  String get displayName => _config.extensions.first.toUpperCase();

  /// Writes [layers] to [fileName] in this format.
  Future<void> write(LayersProvider layers, String fileName) => _config.write(layers, fileName);

  /// Resolves a save format from a file extension, or null when unsupported.
  static SaveFileFormat? fromExtension(String extension) {
    final String normalized = extension.toLowerCase();
    for (final SaveFileFormat format in SaveFileFormat.values) {
      if (format._config.extensions.contains(normalized)) {
        return format;
      }
    }
    return null;
  }

  /// Resolves a save format from a file name.
  static SaveFileFormat? fromFileName(String fileName) => fromExtension(fileName.split('.').last);
}
