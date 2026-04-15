import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/export_file_name.dart';

const String _tiffInputFileName = 'image.tiff';
const String _tifInputFileName = 'image.tif';
const String _extensionlessInputFileName = 'image';
const String _pngInputFileName = 'image.png';
const String _unixTiffPath = '/tmp/export/image.tiff';
const String _windowsTiffPath = r'C:\temp\export\image.tiff';
const String _normalizedTiffFileName = 'image.tif';
const String _normalizedUnixTiffPath = '/tmp/export/image.tif';
const String _normalizedWindowsTiffPath = r'C:\temp\export\image.tif';

void main() {
  group('normalizeTiffExportFileName', () {
    test('uses tif for the default TIFF export filename', () {
      expect(defaultTiffExportFileName, _normalizedTiffFileName);
    });

    test('normalizes tiff suffixes to tif', () {
      expect(normalizeTiffExportFileName(_tiffInputFileName), _normalizedTiffFileName);
    });

    test('keeps tif suffixes as tif', () {
      expect(normalizeTiffExportFileName(_tifInputFileName), _normalizedTiffFileName);
    });

    test('adds tif when no suffix is present', () {
      expect(normalizeTiffExportFileName(_extensionlessInputFileName), _normalizedTiffFileName);
    });

    test('replaces non-tiff suffixes with tif', () {
      expect(normalizeTiffExportFileName(_pngInputFileName), _normalizedTiffFileName);
    });

    test('normalizes unix and windows paths', () {
      expect(normalizeTiffExportFileName(_unixTiffPath), _normalizedUnixTiffPath);
      expect(normalizeTiffExportFileName(_windowsTiffPath), _normalizedWindowsTiffPath);
    });
  });
}
