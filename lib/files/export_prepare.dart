import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fpaint/files/file_heic.dart' if (dart.library.html) 'package:fpaint/files/file_heic_web.dart';
import 'package:fpaint/files/file_jpeg.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/files/file_webp.dart' show convertImageToWebp;
import 'package:fpaint/providers/layers_provider.dart';

/// Returns a reusable export image when nothing changed, otherwise re-renders.
Future<ui.Image> _captureImageForExport(final LayersProvider layers) {
  if (!layers.hasChanged && layers.cachedImage != null) {
    return Future<ui.Image>.value(layers.cachedImage);
  }
  return layers.capturePainterToImage();
}

/// Encodes an in-memory image into PNG bytes.
Future<Uint8List> _imageToPngBytes(final ui.Image image) async {
  final ByteData? byteData = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  return byteData!.buffer.asUint8List();
}

/// Captures the current canvas as PNG-encoded bytes.
Future<Uint8List> preparePngBytes(final LayersProvider layers) async {
  final ui.Image image = await _captureImageForExport(layers);
  return _imageToPngBytes(image);
}

/// Captures the current canvas and converts to JPEG-encoded bytes.
Future<Uint8List> prepareJpegBytes(final LayersProvider layers) async {
  final ui.Image image = await _captureImageForExport(layers);
  return convertToJpg(image);
}

/// Creates an ORA archive from the current layers.
Future<Uint8List> prepareOraBytes(final LayersProvider layers) async {
  final List<int> encodedData = await createOraArchive(layers);
  return Uint8List.fromList(encodedData);
}

/// Captures the current canvas and converts to WebP-encoded bytes.
Future<Uint8List> prepareWebpBytes(final LayersProvider layers) async {
  final ui.Image image = await _captureImageForExport(layers);
  return convertImageToWebp(image);
}

/// Captures the current canvas and converts to HEIC-encoded bytes.
Future<Uint8List> prepareHeicBytes(final LayersProvider layers) async {
  final ui.Image image = await _captureImageForExport(layers);
  final Uint8List pngBytes = await _imageToPngBytes(image);
  return encodeToHeic(pngBytes);
}
