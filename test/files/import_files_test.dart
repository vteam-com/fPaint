import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/import_files.dart';

void main() {
  group('ImportFiles Tests', () {
    group('isFileExtensionSupported', () {
      test('returns true for supported image extensions', () {
        expect(isFileExtensionSupported('png'), isTrue);
        expect(isFileExtensionSupported('jpg'), isTrue);
        expect(isFileExtensionSupported('jpeg'), isTrue);
        expect(isFileExtensionSupported('ora'), isTrue);
        expect(isFileExtensionSupported('tif'), isTrue);
        expect(isFileExtensionSupported('tiff'), isTrue);
        expect(isFileExtensionSupported('webp'), isTrue);
      });

      test('returns true for uppercase extensions', () {
        expect(isFileExtensionSupported('PNG'), isTrue);
        expect(isFileExtensionSupported('JPG'), isTrue);
        expect(isFileExtensionSupported('ORA'), isTrue);
        expect(isFileExtensionSupported('TIF'), isTrue);
      });

      test('returns true for mixed case extensions', () {
        expect(isFileExtensionSupported('JpG'), isTrue);
        expect(isFileExtensionSupported('TiFf'), isTrue);
      });

      test('returns false for unsupported extensions', () {
        expect(isFileExtensionSupported('gif'), isFalse);
        expect(isFileExtensionSupported('bmp'), isFalse);
        expect(isFileExtensionSupported('svg'), isFalse);
        expect(isFileExtensionSupported('psd'), isFalse);
        expect(isFileExtensionSupported('xcf'), isFalse); // Explicitly unsupported
        expect(isFileExtensionSupported('txt'), isFalse);
        expect(isFileExtensionSupported('exe'), isFalse);
      });

      test('returns false for empty extension', () {
        expect(isFileExtensionSupported(''), isFalse);
      });

      test('returns false for null or invalid input', () {
        // Note: This function assumes extension is always a String
        // and doesn't handle null - in practice it would be called with valid strings
        expect(isFileExtensionSupported(''), isFalse);
      });
    });

    // Note: Other functions in import_files.dart involve UI components and file I/O,
    // making them more suitable for integration tests rather than unit tests.
    // Functions like onFileOpen, onFileNew, openFileFromPath, etc. would require
    // significant mocking of BuildContext, FilePicker, LayersProvider, etc.
  });
}
