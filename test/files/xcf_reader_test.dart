import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/xcf_reader.dart';

void main() {
  group('XcfReader Tests', () {
    test('FileXcf.readXcf throws exception for invalid XCF signature', () async {
      final Uint8List invalidBytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);

      final FileXcf xcfReader = FileXcf();

      await expectLater(
        xcfReader.readXcf(invalidBytes),
        throwsA(anything), // Could be Exception, IndexError, etc.
      );
    });

    test('FileXcf.readXcf throws for too short data', () async {
      // XCF files need at least the signature and some header data
      final Uint8List shortBytes = Uint8List.fromList(<int>[0x67, 0x69, 0x6D, 0x70]); // "gimp"

      final FileXcf xcfReader = FileXcf();

      await expectLater(
        xcfReader.readXcf(shortBytes),
        throwsA(anything),
      );
    });

    test('FileXcf.readXcf processes valid minimal XCF signature', () async {
      // This is a very minimal mock XCF file with just the "gimp xcf " signature
      // followed by minimal version and properties to avoid exceptions
      final Uint8List mockXcfBytes = Uint8List.fromList(<int>[
        0x67, 0x69, 0x6D, 0x70, 0x20, 0x78, 0x63, 0x66, 0x20, // "gimp xcf "
        0x76, 0x30, 0x30, 0x31, 0x00, // version "v001" + null
        0x00, 0x00, 0x00, 0x01, // width
        0x00, 0x00, 0x00, 0x01, // height
        0x00, 0x00, 0x00, 0x00, // base type
        0x00, 0x00, 0x00, 0x64, // precision
        0x00, 0x00, 0x00, 0x00, // PROP_END
        0x00, 0x00, 0x00, 0x00, // end of layer pointers
      ]);

      final FileXcf xcfReader = FileXcf();

      await expectLater(
        xcfReader.readXcf(mockXcfBytes),
        completes,
        reason: 'Should process minimal valid XCF structure without throwing',
      );
    });

    test('PropType enum values are correctly defined', () {
      expect(PropType.PROP_END.value, 0);
      expect(PropType.PROP_COLORMAP.value, 1);
      expect(PropType.PROP_ACTIVE_LAYER.value, 2);
      expect(PropType.PROP_COMPRESSION.value, 17);
      expect(PropType.PROP_NUM_PROPS.value, 40);
    });

    test('PropType.fromValue returns correct enum for valid values', () {
      expect(PropType.fromValue(0), PropType.PROP_END);
      expect(PropType.fromValue(1), PropType.PROP_COLORMAP);
      expect(PropType.fromValue(17), PropType.PROP_COMPRESSION);
    });

    test('PropType.fromValue returns null for invalid values', () {
      expect(PropType.fromValue(-1), isNull);
      expect(PropType.fromValue(999), isNull);
    });

    // Note: More comprehensive XCF testing would require creating valid XCF file
    // structures, which is complex due to the binary format specifications.
    // The existing tests focus on basic signature validation and enum functionality.
  });
}
