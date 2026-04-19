import 'package:fpaint/files/file_operation_exception.dart';

/// ORA import/export failure.
class OraFileException extends FileOperationException {
  const OraFileException(super.message, {super.cause});
}
