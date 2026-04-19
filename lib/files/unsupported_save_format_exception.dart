import 'package:fpaint/files/file_operation_exception.dart';

const String _errorUnsupportedSaveFormatPrefix = 'Unsupported file extension for saving: ';

/// Unsupported save file format.
class UnsupportedSaveFormatException extends FileOperationException {
  const UnsupportedSaveFormatException(this.extension) : super('$_errorUnsupportedSaveFormatPrefix$extension');

  final String extension;
}
