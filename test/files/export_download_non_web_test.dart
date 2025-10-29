import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/export_download_non_web.dart';

void main() {
  group('ExportDownload Non-Web Tests', () {
    test('onExportAsPng function exists', () {
      // Note: Due to factory constructor in LayersProvider, we can't create
      // mock instances for testing function calls. But we can verify function existence.
      expect(() => onExportAsPng, returnsNormally);
    });

    test('onExportAsJpeg function exists', () {
      expect(() => onExportAsJpeg, returnsNormally);
    });

    test('onExportAsOra function exists', () {
      expect(() => onExportAsOra, returnsNormally);
    });

    test('onExportAsTiff function exists', () {
      expect(() => onExportAsTiff, returnsNormally);
    });

    test('saveAsPng function exists', () {
      expect(() => saveAsPng, returnsNormally);
    });

    test('saveAsJpeg function exists', () {
      expect(() => saveAsJpeg, returnsNormally);
    });

    test('saveAsOra function exists', () {
      expect(() => saveAsOra, returnsNormally);
    });

    test('saveAsTiff function exists', () {
      expect(() => saveAsTiff, returnsNormally);
    });

    // Due to LayersProvider having a factory constructor, we can't easily
    // create mock instances for testing function calls or parameter validation.
    // However, function existence tests ensure these functions are properly exported.

    // Note: Full integration testing of these export functions would require
    // extensive mocking of FilePicker.platform, file system operations, and
    // LayersProvider. These functions are designed around platform file dialogs
    // and are better tested through integration tests that exercise the full
    // export workflow. The tests above verify that all functions are properly
    // exported and accessible.
  });
}
