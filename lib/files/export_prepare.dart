import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fpaint/files/file_heic.dart' if (dart.library.html) 'package:fpaint/files/file_heic_web.dart';
import 'package:fpaint/files/file_jpeg.dart';
import 'package:fpaint/files/file_operation_exception.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/files/file_webp.dart' show convertImageToWebp;
import 'package:fpaint/providers/layers_provider.dart';

const String _errorFailedToEncodePng = 'Failed to encode the canvas as PNG.';

/// Encodes an in-memory image into PNG bytes, throwing when the engine fails.
Future<Uint8List> _imageToPngBytes(ui.Image image) async {
  final ByteData byteData = await requireImageByteData<FileSaveException>(
    image: image,
    format: ui.ImageByteFormat.png,
    errorMessage: _errorFailedToEncodePng,
    exceptionBuilder: FileSaveException.new,
  );
  return byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
}

/// Captures the current canvas as PNG-encoded bytes.
Future<Uint8List> preparePngBytes(LayersProvider layers) async {
  return _imageToPngBytes(await layers.captureCompositeForExport());
}

/// Captures the current canvas and converts to JPEG-encoded bytes.
Future<Uint8List> prepareJpegBytes(LayersProvider layers) async {
  return convertToJpg(await layers.captureCompositeForExport());
}

/// Creates an ORA archive from the current layers.
Future<Uint8List> prepareOraBytes(LayersProvider layers) async {
  final List<int> encodedData = await createOraArchive(layers);
  return Uint8List.fromList(encodedData);
}

/// Captures the current canvas and converts to WebP-encoded bytes.
Future<Uint8List> prepareWebpBytes(LayersProvider layers) async {
  return convertImageToWebp(await layers.captureCompositeForExport());
}

/// Captures the current canvas and converts to HEIC-encoded bytes.
Future<Uint8List> prepareHeicBytes(LayersProvider layers) async {
  final Uint8List pngBytes = await _imageToPngBytes(await layers.captureCompositeForExport());
  return encodeToHeic(pngBytes);
}
