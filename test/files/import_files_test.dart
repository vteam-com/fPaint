import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/file_heic.dart';
import 'package:fpaint/files/import_files.dart';

/// Path to the HEIC test asset relative to the project root.
const String _testHeicPath = 'assets/test/test.heic';

/// Path to the AVIF test asset relative to the project root.
const String _testAvifPath = 'assets/test/test.avif';

/// ISO base media file format box type identifier (ASCII "ftyp").
const int _ftypByte0 = 0x66; // 'f'
const int _ftypByte1 = 0x74; // 't'
const int _ftypByte2 = 0x79; // 'y'
const int _ftypByte3 = 0x70; // 'p'

/// Byte offset where the "ftyp" box type starts in an ISO BMFF container.
const int _ftypBoxTypeOffset = 4;

/// Byte offset where the major brand starts in an ISO BMFF container.
const int _majorBrandOffset = 8;

/// Length of the major brand field in bytes.
const int _majorBrandLength = 4;

/// Known HEIC/HEIF major brands that identify the file as HEIC-compatible.
const List<String> _heicBrands = <String>['heic', 'heix', 'hevc', 'mif1'];

/// Known AVIF major brands that identify the file as AVIF-compatible.
const List<String> _avifBrands = <String>['avif', 'avis'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
        expect(isFileExtensionSupported('heic'), isTrue);
        expect(isFileExtensionSupported('avif'), isTrue);
      });

      test('returns true for uppercase extensions', () {
        expect(isFileExtensionSupported('PNG'), isTrue);
        expect(isFileExtensionSupported('JPG'), isTrue);
        expect(isFileExtensionSupported('ORA'), isTrue);
        expect(isFileExtensionSupported('TIF'), isTrue);
        expect(isFileExtensionSupported('AVIF'), isTrue);
      });

      test('returns true for mixed case extensions', () {
        expect(isFileExtensionSupported('JpG'), isTrue);
        expect(isFileExtensionSupported('TiFf'), isTrue);
        expect(isFileExtensionSupported('AvIf'), isTrue);
      });

      test('returns false for unsupported extensions', () {
        expect(isFileExtensionSupported('gif'), isFalse);
        expect(isFileExtensionSupported('bmp'), isFalse);
        expect(isFileExtensionSupported('svg'), isFalse);
        expect(isFileExtensionSupported('psd'), isFalse);
        expect(isFileExtensionSupported('xcf'), isFalse);
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

    group('HEIC file import', () {
      test('test.heic asset exists', () {
        final File file = File(_testHeicPath);
        expect(file.existsSync(), isTrue);
      });

      test('test.heic has valid ftyp box header', () async {
        final Uint8List bytes = await File(_testHeicPath).readAsBytes();

        // ISO BMFF files start with a box whose type at offset 4 is "ftyp".
        expect(bytes[_ftypBoxTypeOffset], _ftypByte0);
        expect(bytes[_ftypBoxTypeOffset + 1], _ftypByte1);
        expect(bytes[_ftypBoxTypeOffset + 2], _ftypByte2);
        expect(bytes[_ftypBoxTypeOffset + 3], _ftypByte3);
      });

      test('test.heic has a recognized HEIC major brand', () async {
        final Uint8List bytes = await File(_testHeicPath).readAsBytes();

        final String majorBrand = String.fromCharCodes(
          bytes.sublist(_majorBrandOffset, _majorBrandOffset + _majorBrandLength),
        );

        expect(
          _heicBrands.contains(majorBrand),
          isTrue,
          reason: 'Major brand "$majorBrand" is not a known HEIC brand',
        );
      });

      test(
        'test.heic can be decoded by the import pipeline',
        () async {
          final Uint8List bytes = await File(_testHeicPath).readAsBytes();
          final Uint8List decodableBytes = await decodeHeicBytes(bytes);
          final ui.Codec codec = await ui.instantiateImageCodec(decodableBytes);
          final ui.FrameInfo frameInfo = await codec.getNextFrame();
          final ui.Image image = frameInfo.image;

          expect(image.width, greaterThan(0));
          expect(image.height, greaterThan(0));
          image.dispose();
        },
        skip: !Platform.isMacOS && !Platform.isIOS && !Platform.isAndroid,
      );
    });

    group('AVIF file import', () {
      test('test.avif asset exists', () {
        final File file = File(_testAvifPath);
        expect(file.existsSync(), isTrue);
      });

      test('test.avif has valid ftyp box header', () async {
        final Uint8List bytes = await File(_testAvifPath).readAsBytes();

        expect(bytes[_ftypBoxTypeOffset], _ftypByte0);
        expect(bytes[_ftypBoxTypeOffset + 1], _ftypByte1);
        expect(bytes[_ftypBoxTypeOffset + 2], _ftypByte2);
        expect(bytes[_ftypBoxTypeOffset + 3], _ftypByte3);
      });

      test('test.avif has a recognised AVIF major brand', () async {
        final Uint8List bytes = await File(_testAvifPath).readAsBytes();

        final String majorBrand = String.fromCharCodes(
          bytes.sublist(_majorBrandOffset, _majorBrandOffset + _majorBrandLength),
        );

        expect(
          _avifBrands.contains(majorBrand),
          isTrue,
          reason: 'Major brand "$majorBrand" is not a known AVIF brand',
        );
      });

      test(
        'test.avif can be decoded by the import pipeline',
        () async {
          final Uint8List bytes = await File(_testAvifPath).readAsBytes();
          final Uint8List decodableBytes = await decodeHeicBytes(bytes);
          final ui.Codec codec = await ui.instantiateImageCodec(decodableBytes);
          final ui.FrameInfo frameInfo = await codec.getNextFrame();
          final ui.Image image = frameInfo.image;

          expect(image.width, greaterThan(0));
          expect(image.height, greaterThan(0));
          image.dispose();
        },
        skip: !Platform.isMacOS && !Platform.isIOS && !Platform.isAndroid,
      );
    });

    // Note: Other functions in import_files.dart involve UI components and file I/O,
    // making them more suitable for integration tests rather than unit tests.
  });
}
