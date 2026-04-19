const String _errorCausePrefix = 'Cause: ';

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
