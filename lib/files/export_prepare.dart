import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fpaint/files/file_heic.dart' if (dart.library.html) 'package:fpaint/files/file_heic_web.dart';
import 'package:fpaint/files/file_jpeg.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/files/file_webp.dart' show convertImageToWebp;
import 'package:fpaint/providers/layers_provider.dart';

/// Captures the current canvas as PNG-encoded bytes.
Future<Uint8List> preparePngBytes(final LayersProvider layers) async {
  return layers.capturePainterToImageBytes();
}

/// Captures the current canvas and converts to JPEG-encoded bytes.
Future<Uint8List> prepareJpegBytes(final LayersProvider layers) async {
  final ui.Image image = await layers.capturePainterToImage();
  return convertToJpg(image);
}

/// Creates an ORA archive from the current layers.
Future<Uint8List> prepareOraBytes(final LayersProvider layers) async {
  final List<int> encodedData = await createOraArchive(layers);
  return Uint8List.fromList(encodedData);
}

/// Captures the current canvas and converts to WebP-encoded bytes.
Future<Uint8List> prepareWebpBytes(final LayersProvider layers) async {
  final ui.Image image = await layers.capturePainterToImage();
  return convertImageToWebp(image);
}

/// Captures the current canvas and converts to HEIC-encoded bytes.
Future<Uint8List> prepareHeicBytes(final LayersProvider layers) async {
  final Uint8List pngBytes = await layers.capturePainterToImageBytes();
  return encodeToHeic(pngBytes);
}
