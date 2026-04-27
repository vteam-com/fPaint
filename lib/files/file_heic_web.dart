import 'dart:typed_data';

import 'package:fpaint/files/file_operation_exception.dart';
import 'package:heic_to_png_jpg/heic_to_png_jpg.dart' show HeicConverter;

const String _errorConvertPrefix = 'Failed to decode HEIC image';
const String _errorEncodePrefix = 'Failed to encode HEIC image';

/// HEIC export encoding is not supported on the web platform.
bool get isHeicExportSupported => false;

/// Converts HEIC bytes into PNG bytes using the `heic_to_png_jpg` package.
///
/// On web, the package loads `libheif-js` (a WASM build of libheif)
/// and decodes the HEIC data via an HTML canvas.
///
/// Throws [HeicConversionException] on failure.
Future<Uint8List> decodeHeicBytes(final Uint8List heicBytes) async {
  try {
    return await HeicConverter.convertToPNG(heicData: heicBytes);
  } catch (e) {
    throw HeicConversionException(_errorConvertPrefix, cause: e);
  }
}

/// HEIC encoding is not supported on web.
///
/// Always throws [HeicConversionException].
Future<Uint8List> encodeToHeic(final Uint8List _) async {
  throw const HeicConversionException(_errorEncodePrefix);
}
