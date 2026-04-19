import 'package:fpaint/files/file_operation_exception.dart';

/// Save operation failure.
class FileSaveException extends FileOperationException {
  const FileSaveException(super.message, {super.cause});
}
