import 'dart:typed_data';

import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/export_file_name.dart';
import 'package:fpaint/files/file_heic.dart' if (dart.library.html) 'package:fpaint/files/file_heic_web.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/files/file_psd.dart';
import 'package:fpaint/files/file_tiff.dart';
import 'package:fpaint/files/flat_image_reader.dart';
import 'package:fpaint/providers/layers_provider.dart';

/// Decodes a file's [bytes] into [layers], replacing the open document.
///
/// [name] names the layer a flat format creates; layered formats keep the
/// layer names stored in the file. Throws on undecodable input.
typedef ImportDocumentReader = Future<void> Function(LayersProvider layers, Uint8List bytes, String name);

/// Extracts the image-decodable preview from a file's bytes, or null when the
/// file carries none.
typedef ImportPreviewExtractor = Future<Uint8List?> Function(Uint8List bytes);

/// Static metadata for an importable file format.
class _ImportFormatConfig {
  const _ImportFormatConfig({
    required this.extensions,
    required this.reader,
    this.supportsLayers = false,
    this.previewExtractor,
  });

  final List<String> extensions;
  final ImportDocumentReader reader;
  final bool supportsLayers;

  /// Null when the file's own bytes are already image-decodable.
  final ImportPreviewExtractor? previewExtractor;
}

Future<void> _readOra(LayersProvider layers, Uint8List bytes, String _) => readOraFileFromBytes(layers, bytes);

Future<void> _readPsd(LayersProvider layers, Uint8List bytes, String _) => readPsdFileFromBytes(layers, bytes);

Future<void> _readTiff(LayersProvider layers, Uint8List bytes, String _) => readTiffFileFromBytes(layers, bytes);

/// HEIC/AVIF need a platform HEIF decode before the image decoder sees them.
Future<void> _readHeif(LayersProvider layers, Uint8List bytes, String name) async =>
    readFlatImageFromBytes(layers, await decodeHeicBytes(bytes), name);

/// Every file format the app can open.
///
/// Extensions and the reader live on the enum entry, so adding a format means
/// adding one entry rather than editing each open/import flow (Open/Closed).
enum ImportFileFormat {
  ora(
    _ImportFormatConfig(
      extensions: <String>[FileExtensions.ora],
      reader: _readOra,
      supportsLayers: true,
      previewExtractor: extractOraPreviewPngBytes,
    ),
  ),
  psd(
    _ImportFormatConfig(
      extensions: <String>[FileExtensions.psd],
      reader: _readPsd,
      supportsLayers: true,
      previewExtractor: extractPsdPreviewPngBytes,
    ),
  ),
  tiff(
    _ImportFormatConfig(
      extensions: <String>[FileExtensions.tif, FileExtensions.tiff],
      reader: _readTiff,
      supportsLayers: true,
    ),
  ),
  heic(
    _ImportFormatConfig(
      extensions: <String>[FileExtensions.heic, FileExtensions.avif],
      reader: _readHeif,
    ),
  ),
  png(
    _ImportFormatConfig(
      extensions: <String>[FileExtensions.png],
      reader: readFlatImageFromBytes,
    ),
  ),
  jpeg(
    _ImportFormatConfig(
      extensions: <String>[FileExtensions.jpg, FileExtensions.jpeg],
      reader: readFlatImageFromBytes,
    ),
  ),
  webp(
    _ImportFormatConfig(
      extensions: <String>[FileExtensions.webp],
      reader: readFlatImageFromBytes,
    ),
  );

  const ImportFileFormat(this._config);

  final _ImportFormatConfig _config;

  /// Every file extension that maps to this format; the first is canonical.
  List<String> get extensions => _config.extensions;

  /// Decodes this format's bytes into a document; see [ImportDocumentReader].
  Future<void> read(LayersProvider layers, Uint8List bytes, String name) => _config.reader(layers, bytes, name);

  /// Thumbnail-ready bytes for a file of this format: the embedded composite
  /// for containers the image decoder cannot read (ORA, PSD), else [bytes]
  /// as-is.
  Future<Uint8List?> previewBytes(Uint8List bytes) async {
    final ImportPreviewExtractor? extractor = _config.previewExtractor;
    return extractor == null ? bytes : extractor(bytes);
  }

  /// Whether the format rebuilds the full layer stack rather than decoding to
  /// a single flat image.
  ///
  /// Flat formats fall back to a selected-layer preference keyed by file path.
  /// ORA and TIFF embed the selected layer and restore it inside their reader;
  /// PSD has no such marker, so its selection simply defaults to the top layer.
  bool get supportsLayers => _config.supportsLayers;

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
  static ImportFileFormat? fromFileName(String fileName) => fromExtension(fileExtensionOf(fileName));

  /// Every extension the app can open, for file-picker filters and support
  /// checks.
  static List<String> get allExtensions => <String>[
    for (final ImportFileFormat format in ImportFileFormat.values) ...format._config.extensions,
  ];
}
