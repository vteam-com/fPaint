import 'package:fpaint/files/file_operation_exception.dart';

/// WebP conversion failure.
class WebpConversionException extends FileOperationException {
  const WebpConversionException(super.message, {super.cause});
}
