// ignore: fcheck_one_class_per_file
const String _errorCausePrefix = 'Cause: ';
const String _errorUnsupportedSaveFormatPrefix = 'Unsupported file extension for saving: ';

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

/// JPEG conversion failure.
class JpegConversionException extends FileOperationException {
  const JpegConversionException(super.message, {super.cause});
}

/// ORA import/export failure.
class OraFileException extends FileOperationException {
  const OraFileException(super.message, {super.cause});
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
