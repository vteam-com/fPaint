// ignore: fcheck_one_class_per_file
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

// ignore: fcheck_one_class_per_file
const String _errorCausePrefix = 'Cause: ';
const String _errorUnsupportedSaveFormatPrefix = 'Unsupported file extension for saving: ';

/// Creates a typed [FileOperationException] from a message and optional cause.
typedef FileOperationExceptionBuilder<T extends FileOperationException> = T Function(String message, {Object? cause});

/// Base exception for image import/export and file codec operations.
class FileOperationException implements Exception {
  const FileOperationException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return message;
    }

    return '$message $_errorCausePrefix$cause';
  }
}

/// Save operation failure.
class FileSaveException extends FileOperationException {
  const FileSaveException(super.message, {super.cause});
}

/// HEIC conversion failure.
class HeicConversionException extends FileOperationException {
  const HeicConversionException(super.message, {super.cause});
}

/// JPEG conversion failure.
class JpegConversionException extends FileOperationException {
  const JpegConversionException(super.message, {super.cause});
}

/// ORA import/export failure.
class OraFileException extends FileOperationException {
  const OraFileException(super.message, {super.cause});
}

/// PSD import failure.
class PsdFileException extends FileOperationException {
  const PsdFileException(super.message, {super.cause});
}

/// TIFF import/export failure.
class TiffFileException extends FileOperationException {
  const TiffFileException(super.message, {super.cause});
}

/// Unsupported save file format.
class UnsupportedSaveFormatException extends FileOperationException {
  const UnsupportedSaveFormatException(this.extension) : super('$_errorUnsupportedSaveFormatPrefix$extension');

  final String extension;
}

/// WebP conversion failure.
class WebpConversionException extends FileOperationException {
  const WebpConversionException(super.message, {super.cause});
}

/// Throws a typed [FileOperationException] while preserving [stackTrace].
Never throwFileOperationException<T extends FileOperationException>({
  required String message,
  required Object error,
  required StackTrace stackTrace,
  required FileOperationExceptionBuilder<T> exceptionBuilder,
}) {
  Error.throwWithStackTrace(
    exceptionBuilder(message, cause: error),
    stackTrace,
  );
}

/// Returns non-null byte data for [image] encoded as [format], or throws.
Future<ByteData> requireImageByteData<T extends FileOperationException>({
  required ui.Image image,
  required ui.ImageByteFormat format,
  required String errorMessage,
  required FileOperationExceptionBuilder<T> exceptionBuilder,
}) async {
  final ByteData? byteData = await image.toByteData(format: format);
  if (byteData == null) {
    throw exceptionBuilder(errorMessage);
  }

  return byteData;
}

/// Decodes the bytes of a layered document into the canvas.
typedef LayeredFileByteReader = Future<void> Function(Uint8List bytes);

/// Reads the layered file at [path] and hands its bytes to [readBytes].
///
/// Every layered reader (ORA, PSD, TIFF) needs the same disk-side envelope:
/// a missing-file check, a read, and failures reported as that format's own
/// [FileOperationException] with the original stack trace preserved. Only the
/// exception type and the two message prefixes differ, so they are parameters
/// here rather than a copy per format.
Future<void> readLayeredFileFromPath<T extends FileOperationException>({
  required String path,
  required LayeredFileByteReader readBytes,
  required String fileNotFoundPrefix,
  required String readFailedPrefix,
  required FileOperationExceptionBuilder<T> exceptionBuilder,
}) async {
  final File file = File(path);
  if (!await file.exists()) {
    throw exceptionBuilder('$fileNotFoundPrefix "$path"');
  }

  try {
    await readBytes(await file.readAsBytes());
  } on T {
    rethrow;
  } catch (error, stackTrace) {
    throwFileOperationException<T>(
      message: '$readFailedPrefix "$path"',
      error: error,
      stackTrace: stackTrace,
      exceptionBuilder: exceptionBuilder,
    );
  }
}
