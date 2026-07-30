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

    test('ORA then PNG export does not dispose the cached image twice', () async {
      // The page editor saves via exportOra() then exportThumbnailPng(). The
      // ORA export's preview capture must not dispose layers.cachedImage, or the
      // following PNG capture reads a disposed image and trips an assertion.
      final Uint8List ora = await prepareOraBytes(layers);
      final Uint8List png = await preparePngBytes(layers);
      expect(ora, isNotEmpty);
      expect(png, isNotEmpty);
      expect(png[0], 137);
      expect(png[1], 80);
    });
  });
}
