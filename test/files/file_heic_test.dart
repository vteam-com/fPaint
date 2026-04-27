import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/file_heic.dart';
import 'package:fpaint/files/file_operation_exception.dart';
import 'package:heic_to_png_jpg/heic_to_png_jpg.dart' show HeicConverter;

/// Path to the HEIC test asset relative to the project root.
const String _testHeicPath = 'assets/test/test.heic';

/// Path to the PNG test asset used for encode tests.
const String _testPngPath = 'test/output/final.png';

/// HEIC ftyp box offset where the major brand starts.
const int _ftypBrandOffset = 8;

/// Length of the major brand identifier in bytes.
const int _ftypBrandLength = 4;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileHeic Tests', () {
    group('decodeHeicBytes', () {
      test('returns unchanged bytes on macOS (native codec)', () async {
        if (!Platform.isMacOS) {
          return;
        }
        final Uint8List heicBytes = await File(_testHeicPath).readAsBytes();
        final Uint8List result = await decodeHeicBytes(heicBytes);
        expect(result, heicBytes);
      });

      test('wraps errors in HeicConversionException', () async {
        if (Platform.isLinux || Platform.isWindows) {
          final Uint8List invalidBytes = Uint8List.fromList(<int>[0, 1, 2, 3]);
          expect(
            () => decodeHeicBytes(invalidBytes),
            throwsA(isA<HeicConversionException>()),
          );
        }
      });
    });

    group('encodeToHeic', () {
      test('encodes PNG to HEIC on macOS', () async {
        if (!Platform.isMacOS) {
          return;
        }
        final Uint8List pngBytes = await File(_testPngPath).readAsBytes();
        final Uint8List heicBytes = await encodeToHeic(pngBytes);
        expect(heicBytes.isNotEmpty, isTrue);

        // Verify the output has a valid HEIC ftyp box.
        final String brand = String.fromCharCodes(
          heicBytes.sublist(_ftypBrandOffset, _ftypBrandOffset + _ftypBrandLength),
        );
        expect(brand, isIn(<String>['heic', 'heix', 'mif1']));
      });

      test('isHeicExportSupported reflects macOS', () {
        expect(isHeicExportSupported, Platform.isMacOS);
      });
    });

    group('HeicConverter.isHeic', () {
      test('recognises test.heic as valid HEIC', () async {
        final Uint8List heicBytes = await File(_testHeicPath).readAsBytes();
        expect(HeicConverter.isHeic(heicBytes), isTrue);
      });

      test('rejects non-HEIC bytes', () {
        final Uint8List pngHeader = Uint8List.fromList(<int>[
          0x89, 0x50, 0x4E, 0x47, // PNG magic
          0x0D, 0x0A, 0x1A, 0x0A,
          0x00, 0x00, 0x00, 0x0D,
        ]);
        expect(HeicConverter.isHeic(pngHeader), isFalse);
      });
    });
  });
}
