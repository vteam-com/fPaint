import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/import_file_format.dart';

void main() {
  group('ImportFileFormat.fromExtension', () {
    test('resolves every declared extension to its format', () {
      const Map<String, ImportFileFormat> expected = <String, ImportFileFormat>{
        FileExtensions.ora: ImportFileFormat.ora,
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
    test('decodeKind routes each format to the right reader', () {
      expect(ImportFileFormat.ora.decodeKind, ImportDecodeKind.ora);
      expect(ImportFileFormat.tiff.decodeKind, ImportDecodeKind.tiff);
      expect(ImportFileFormat.heic.decodeKind, ImportDecodeKind.heif);
      expect(ImportFileFormat.png.decodeKind, ImportDecodeKind.image);
      expect(ImportFileFormat.jpeg.decodeKind, ImportDecodeKind.image);
      expect(ImportFileFormat.webp.decodeKind, ImportDecodeKind.image);
    });

    test('only the layered formats report supportsLayers', () {
      expect(ImportFileFormat.ora.supportsLayers, isTrue);
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
