import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/import_file_format.dart';
import 'package:fpaint/providers/layers_provider.dart';

import '../helpers/file_flow_harness.dart';

const int _pngWidth = 6;
const int _pngHeight = 4;
const String _layerName = 'imported';
const List<int> _garbageBytes = <int>[0, 1, 2, 3, 4, 5, 6, 7];

void main() {
  group('ImportFileFormat.fromExtension', () {
    test('resolves every declared extension to its format', () {
      const Map<String, ImportFileFormat> expected = <String, ImportFileFormat>{
        FileExtensions.ora: ImportFileFormat.ora,
        FileExtensions.psd: ImportFileFormat.psd,
        FileExtensions.tif: ImportFileFormat.tiff,
        FileExtensions.tiff: ImportFileFormat.tiff,
        FileExtensions.heic: ImportFileFormat.heic,
        FileExtensions.avif: ImportFileFormat.heic,
        FileExtensions.png: ImportFileFormat.png,
        FileExtensions.jpg: ImportFileFormat.jpeg,
        FileExtensions.jpeg: ImportFileFormat.jpeg,
        FileExtensions.webp: ImportFileFormat.webp,
      };

      expected.forEach((String extension, ImportFileFormat format) {
        expect(
          ImportFileFormat.fromExtension(extension),
          format,
          reason: 'extension "$extension" should resolve to $format',
        );
      });
    });

    test('is case insensitive', () {
      expect(ImportFileFormat.fromExtension('PNG'), ImportFileFormat.png);
      expect(ImportFileFormat.fromExtension('TifF'), ImportFileFormat.tiff);
    });

    test('returns null for an unsupported extension', () {
      expect(ImportFileFormat.fromExtension('bmp'), isNull);
      expect(ImportFileFormat.fromExtension(''), isNull);
    });
  });

  group('ImportFileFormat.fromFileName', () {
    test('resolves from the file name extension', () {
      expect(ImportFileFormat.fromFileName('layers.ora'), ImportFileFormat.ora);
      expect(ImportFileFormat.fromFileName('artwork.psd'), ImportFileFormat.psd);
      expect(ImportFileFormat.fromFileName('IMAGE.PNG'), ImportFileFormat.png);
    });

    test('resolves from a full path', () {
      expect(
        ImportFileFormat.fromFileName('/tmp/some.dir/photo.jpeg'),
        ImportFileFormat.jpeg,
      );
    });

    test('returns null for an unsupported or missing extension', () {
      expect(ImportFileFormat.fromFileName('file.bmp'), isNull);
      expect(ImportFileFormat.fromFileName('noext'), isNull);
    });
  });

  group('ImportFileFormat metadata', () {
    testWidgets('a flat reader replaces the document with one named layer', (WidgetTester tester) async {
      await tester.runAsync(() async {
        final LayersProvider layers = LayersProvider();
        final Uint8List bytes = await encodeSolidPng(width: _pngWidth, height: _pngHeight);

        await ImportFileFormat.png.read(layers, bytes, _layerName);

        expect(layers.size, const Size(_pngWidth * 1.0, _pngHeight * 1.0));
        expect(layers.list.map((LayerProvider layer) => layer.name), contains(_layerName));
        layers.dispose();
      });
    });

    testWidgets('every reader rejects undecodable bytes', (WidgetTester tester) async {
      await tester.runAsync(() async {
        for (final ImportFileFormat format in ImportFileFormat.values) {
          final LayersProvider layers = LayersProvider();
          await expectLater(
            format.read(layers, Uint8List.fromList(_garbageBytes), _layerName),
            throwsA(anything),
            reason: '$format must reject garbage',
          );
          layers.dispose();
        }
      });
    });

    test('previewBytes passes decodable formats through and extracts container previews', () async {
      final Uint8List bytes = Uint8List.fromList(_garbageBytes);

      expect(await ImportFileFormat.png.previewBytes(bytes), same(bytes));
      expect(await ImportFileFormat.tiff.previewBytes(bytes), same(bytes));
      // ORA and PSD extract their embedded composite; garbage carries none.
      expect(await ImportFileFormat.ora.previewBytes(bytes), isNull);
      expect(await ImportFileFormat.psd.previewBytes(bytes), isNull);
    });

    test('only the layered formats report supportsLayers', () {
      expect(ImportFileFormat.ora.supportsLayers, isTrue);
      expect(ImportFileFormat.psd.supportsLayers, isTrue);
      expect(ImportFileFormat.tiff.supportsLayers, isTrue);
      expect(ImportFileFormat.heic.supportsLayers, isFalse);
      expect(ImportFileFormat.png.supportsLayers, isFalse);
      expect(ImportFileFormat.jpeg.supportsLayers, isFalse);
      expect(ImportFileFormat.webp.supportsLayers, isFalse);
    });

    test('extensions lists the format own extensions, canonical first', () {
      expect(ImportFileFormat.tiff.extensions, <String>[FileExtensions.tif, FileExtensions.tiff]);
      expect(ImportFileFormat.png.extensions, <String>[FileExtensions.png]);
    });

    test('allExtensions covers every format and resolves back', () {
      final List<String> all = ImportFileFormat.allExtensions;

      for (final ImportFileFormat format in ImportFileFormat.values) {
        for (final String extension in format.extensions) {
          expect(all, contains(extension));
          expect(ImportFileFormat.fromExtension(extension), format);
        }
      }
      expect(all, hasLength(all.toSet().length), reason: 'extensions must be unique');
    });
  });
}
