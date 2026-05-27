import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/file_heic.dart';
import 'package:fpaint/files/file_operation_exception.dart';

/// Path to the HEIC test asset relative to the project root.
const String _testHeicPath = 'assets/test/test.heic';

/// Path to the PNG test asset used for encode tests.
const String _testPngPath = 'test/output/final.png';

/// HEIC ftyp box offset where the major brand starts.
const int _ftypBrandOffset = 8;

/// Length of the major brand identifier in bytes.
const int _ftypBrandLength = 4;

const int _ftypBoxTypeStart = 4;
const int _ftypBoxTypeEnd = 8;
const int _minimumHeicHeaderLength = 12;
const String _ftypBoxType = 'ftyp';

const Set<String> _heicMajorBrands = <String>{
  'heic',
  'heix',
  'hevc',
  'hevx',
  'mif1',
  'msf1',
};

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

    group('isHeicBytes', () {
      test('recognises test.heic as valid HEIC', () async {
        final Uint8List heicBytes = await File(_testHeicPath).readAsBytes();
        expect(_isHeicBytes(heicBytes), isTrue);
      });

      test('rejects non-HEIC bytes', () {
        final Uint8List pngHeader = Uint8List.fromList(<int>[
          0x89, 0x50, 0x4E, 0x47, // PNG magic
          0x0D, 0x0A, 0x1A, 0x0A,
          0x00, 0x00, 0x00, 0x0D,
        ]);
        expect(_isHeicBytes(pngHeader), isFalse);
      });
    });
  });
}

bool _isHeicBytes(final Uint8List data) {
  if (data.length < _minimumHeicHeaderLength) {
    return false;
  }

  final String boxType = String.fromCharCodes(
    data.sublist(_ftypBoxTypeStart, _ftypBoxTypeEnd),
  );
  if (boxType != _ftypBoxType) {
    return false;
  }

  final String majorBrand = String.fromCharCodes(
    data.sublist(_ftypBrandOffset, _ftypBrandOffset + _ftypBrandLength),
  );
  return _heicMajorBrands.contains(majorBrand);
}
