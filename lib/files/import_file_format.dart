import 'package:fpaint/constants/constants.dart';

/// How a supported input file is turned into layers.
///
/// Layered formats rebuild the whole layer stack from the file; flat formats
/// decode to a single image. HEIF-family formats need a platform decode pass
/// before the bytes can be handed to the image decoder.
enum ImportDecodeKind {
  /// ORA — a layered format with its own reader.
  ora,

  /// PSD — a layered format with its own reader.
  psd,

  /// TIFF — a layered format with its own reader.
  tiff,

  /// HEIC/AVIF — needs a platform HEIF decode before image decoding.
  heif,

  /// A format the engine's image decoder handles directly.
  image,
}

/// Static metadata for an importable file format.
class _ImportFormatConfig {
  const _ImportFormatConfig({required this.extensions, required this.decodeKind});

  final List<String> extensions;
  final ImportDecodeKind decodeKind;
}

/// Every file format the app can open.
///
/// Extensions and decode strategy live on the enum entry, so adding a format
/// means adding one entry rather than editing each `if`/`else` import chain
/// (Open/Closed).
enum ImportFileFormat {
  ora(
    _ImportFormatConfig(
      extensions: <String>[FileExtensions.ora],
      decodeKind: ImportDecodeKind.ora,
    ),
  ),
  psd(
    _ImportFormatConfig(
      extensions: <String>[FileExtensions.psd],
      decodeKind: ImportDecodeKind.psd,
    ),
  ),
  tiff(
    _ImportFormatConfig(
      extensions: <String>[FileExtensions.tif, FileExtensions.tiff],
      decodeKind: ImportDecodeKind.tiff,
    ),
  ),
  heic(
    _ImportFormatConfig(
      extensions: <String>[FileExtensions.heic, FileExtensions.avif],
      decodeKind: ImportDecodeKind.heif,
    ),
  ),
  png(
    _ImportFormatConfig(
      extensions: <String>[FileExtensions.png],
      decodeKind: ImportDecodeKind.image,
    ),
  ),
  jpeg(
    _ImportFormatConfig(
      extensions: <String>[FileExtensions.jpg, FileExtensions.jpeg],
      decodeKind: ImportDecodeKind.image,
    ),
  ),
  webp(
    _ImportFormatConfig(
      extensions: <String>[FileExtensions.webp],
      decodeKind: ImportDecodeKind.image,
    ),
  );

  const ImportFileFormat(this._config);

  final _ImportFormatConfig _config;

  /// Every file extension that maps to this format; the first is canonical.
  List<String> get extensions => _config.extensions;

  /// How this format's bytes are turned into layers.
  ImportDecodeKind get decodeKind => _config.decodeKind;

  /// Whether the format rebuilds the full layer stack rather than decoding to
  /// a single flat image.
  ///
  /// Flat formats fall back to a selected-layer preference keyed by file path.
  /// ORA and TIFF embed the selected layer and restore it inside their reader;
  /// PSD has no such marker, so its selection simply defaults to the top layer.
  bool get supportsLayers => const <ImportDecodeKind>{
    ImportDecodeKind.ora,
    ImportDecodeKind.psd,
    ImportDecodeKind.tiff,
  }.contains(_config.decodeKind);

  /// Resolves an import format from a file extension, or null when unsupported.
  static ImportFileFormat? fromExtension(String extension) {
    final String normalized = extension.toLowerCase();
    for (final ImportFileFormat format in ImportFileFormat.values) {
      if (format._config.extensions.contains(normalized)) {
        return format;
      }
    }
    return null;
  }

  /// Resolves an import format from a file name.
  static ImportFileFormat? fromFileName(String fileName) => fromExtension(fileName.split('.').last);

  /// Every extension the app can open, for file-picker filters and support
  /// checks.
  static List<String> get allExtensions => <String>[
    for (final ImportFileFormat format in ImportFileFormat.values) ...format._config.extensions,
  ];
}
