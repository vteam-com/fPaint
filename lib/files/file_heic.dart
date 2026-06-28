import 'dart:io';
import 'dart:typed_data';

import 'package:fpaint/files/file_operation_exception.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';

final Logger _log = Logger(logNameFileHeic);

const String _errorConvertPrefix = 'Failed to decode HEIC image';
const String _errorEncodePrefix = 'Failed to encode HEIC image';
const String _errorEncodeSipsFailedPrefix = 'sips exited with error:';

const String _sipsCommand = 'sips';
const String _sipsFormatFlag = '-s';
const String _sipsFormatProperty = 'format';
const String _sipsFormatHeic = 'heic';
const String _sipsOutputFlag = '--out';
const String _tempDirPrefix = 'fpaint_heic_';
const String _tempInputFileName = 'input.png';
const String _tempOutputFileName = 'output.heic';

/// Whether HEIC export encoding is supported on the current platform.
///
/// On macOS, encoding uses the system `sips` tool.
bool get isHeicExportSupported => Platform.isMacOS;

/// Converts HEIC bytes into a format decodable by Flutter's image codec.
///
/// On macOS, iOS, and Android the platform provides a native HEIC decoder,
/// so the bytes are returned unchanged for `decodeImageFromList` to handle.
///
/// On Linux and Windows, the `heic_to_png_jpg` package is attempted
/// (uses `package:image` internally). A [HeicConversionException] is thrown
/// on failure.
Future<Uint8List> decodeHeicBytes(final Uint8List heicBytes) async {
  // Native Flutter codec handles HEIC on Apple platforms and Android.
  if (Platform.isMacOS || Platform.isIOS || Platform.isAndroid) {
    return heicBytes;
  }

  return _decodeHeicBytesWithImagePackage(heicBytes);
}

/// Encodes PNG bytes to HEIC format.
///
/// On macOS, uses the system `sips` tool to convert PNG → HEIC.
/// Throws [HeicConversionException] on unsupported platforms or failure.
Future<Uint8List> encodeToHeic(final Uint8List pngBytes) async {
  if (!Platform.isMacOS) {
    throw const HeicConversionException(_errorEncodePrefix);
  }

  final Directory tempDir = await Directory.systemTemp.createTemp(_tempDirPrefix);
  try {
    final File pngFile = File('${tempDir.path}/$_tempInputFileName');
    final File heicFile = File('${tempDir.path}/$_tempOutputFileName');
    await pngFile.writeAsBytes(pngBytes);

    final ProcessResult result = await Process.run(_sipsCommand, <String>[
      _sipsFormatFlag,
      _sipsFormatProperty,
      _sipsFormatHeic,
      pngFile.path,
      _sipsOutputFlag,
      heicFile.path,
    ]);

    if (result.exitCode != 0) {
      throw HeicConversionException(
        '$_errorEncodeSipsFailedPrefix ${result.stderr}',
      );
    }

    return await heicFile.readAsBytes();
  } catch (e) {
    if (e is HeicConversionException) {
      rethrow;
    }
    throw HeicConversionException(_errorEncodePrefix, cause: e);
  } finally {
    try {
      await tempDir.delete(recursive: true);
    } catch (e, stackTrace) {
      // Best-effort cleanup of temporary files.
      _log.warning('Failed to delete temporary HEIC directory', e, stackTrace);
    }
  }
}

/// Converts HEIC bytes to PNG using the same minimal desktop fallback strategy
/// previously supplied by `heic_to_png_jpg`.
Future<Uint8List> _decodeHeicBytesWithImagePackage(
  final Uint8List heicBytes,
) async {
  try {
    final img.Image? decodedImage = img.decodeImage(heicBytes);
    if (decodedImage == null) {
      throw const HeicConversionException(_errorConvertPrefix);
    }

    return Uint8List.fromList(img.encodePng(decodedImage));
  } on HeicConversionException {
    rethrow;
  } catch (e) {
    throw HeicConversionException(_errorConvertPrefix, cause: e);
  }
}
