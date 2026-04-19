import 'package:fpaint/files/file_operation_exception.dart';

/// TIFF import/export failure.
class TiffFileException extends FileOperationException {
  const TiffFileException(super.message, {super.cause});
}
