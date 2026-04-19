import 'package:fpaint/files/file_operation_exception.dart';

/// JPEG conversion failure.
class JpegConversionException extends FileOperationException {
  const JpegConversionException(super.message, {super.cause});
}
