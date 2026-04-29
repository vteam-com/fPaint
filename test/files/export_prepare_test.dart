import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/export_prepare.dart';
import 'package:fpaint/providers/layers_provider.dart';

import '../helpers/layers_provider_test_helper.dart';

void main() {
  group('export_prepare', () {
    late LayersProvider layers;

    setUp(() {
      layers = createInitializedLayersProvider();
    });

    test('preparePngBytes returns valid PNG bytes', () async {
      final Uint8List bytes = await preparePngBytes(layers);
      expect(bytes, isNotEmpty);
      // PNG magic number: 137 80 78 71
      expect(bytes[0], 137);
      expect(bytes[1], 80);
    });

    test('prepareJpegBytes returns valid JPEG bytes', () async {
      final Uint8List bytes = await prepareJpegBytes(layers);
      expect(bytes, isNotEmpty);
      // JPEG magic number: 0xFF 0xD8
      expect(bytes[0], 0xFF);
      expect(bytes[1], 0xD8);
    });

    test('prepareOraBytes returns valid ORA bytes', () async {
      final Uint8List bytes = await prepareOraBytes(layers);
      expect(bytes, isNotEmpty);
      // ORA is a ZIP file, magic: 0x50 0x4B
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
    });

    test('prepareWebpBytes returns valid WebP bytes', () async {
      final Uint8List bytes = await prepareWebpBytes(layers);
      expect(bytes, isNotEmpty);
    });
  });
}
