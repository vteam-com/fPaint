import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/export_file_name.dart';
import 'package:fpaint/files/save.dart';

void main() {
  group('SaveFileFormat.fromFileName', () {
    test('resolves PNG', () {
      expect(SaveFileFormat.fromFileName('image.png'), SaveFileFormat.png);
    });

    test('resolves JPG', () {
      expect(SaveFileFormat.fromFileName('photo.jpg'), SaveFileFormat.jpeg);
    });

    test('resolves JPEG', () {
      expect(SaveFileFormat.fromFileName('photo.jpeg'), SaveFileFormat.jpeg);
    });

    test('resolves ORA', () {
      expect(SaveFileFormat.fromFileName('layers.ora'), SaveFileFormat.ora);
    });

    test('resolves TIF', () {
      expect(SaveFileFormat.fromFileName('scan.tif'), SaveFileFormat.tiff);
    });

    test('resolves TIFF', () {
      expect(SaveFileFormat.fromFileName('scan.tiff'), SaveFileFormat.tiff);
    });

    test('resolves WEBP', () {
      expect(SaveFileFormat.fromFileName('web.webp'), SaveFileFormat.webp);
    });

    test('resolves HEIC', () {
      expect(SaveFileFormat.fromFileName('apple.heic'), SaveFileFormat.heic);
    });

    test('returns null for unknown extension', () {
      expect(SaveFileFormat.fromFileName('file.bmp'), null);
    });

    test('returns null for no extension', () {
      expect(SaveFileFormat.fromFileName('noext'), null);
    });

    test('case insensitive', () {
      expect(SaveFileFormat.fromFileName('IMAGE.PNG'), SaveFileFormat.png);
      expect(SaveFileFormat.fromFileName('photo.JPEG'), SaveFileFormat.jpeg);
    });
  });

  group('SaveFileFormat.fromExtension', () {
    test('resolves every declared extension to its format', () {
      const Map<String, SaveFileFormat> expected = <String, SaveFileFormat>{
        FileExtensions.png: SaveFileFormat.png,
        FileExtensions.jpg: SaveFileFormat.jpeg,
        FileExtensions.jpeg: SaveFileFormat.jpeg,
        FileExtensions.ora: SaveFileFormat.ora,
        FileExtensions.tif: SaveFileFormat.tiff,
        FileExtensions.tiff: SaveFileFormat.tiff,
        FileExtensions.webp: SaveFileFormat.webp,
        FileExtensions.heic: SaveFileFormat.heic,
      };

      expected.forEach((String extension, SaveFileFormat format) {
        expect(
          SaveFileFormat.fromExtension(extension),
          format,
          reason: 'extension "$extension" should resolve to $format',
        );
      });
    });

    test('is case insensitive and rejects unsupported extensions', () {
      expect(SaveFileFormat.fromExtension('PNG'), SaveFileFormat.png);
      expect(SaveFileFormat.fromExtension('bmp'), isNull);
    });
  });

  group('SaveFileFormat metadata', () {
    test('only layered formats report supportsLayers', () {
      expect(SaveFileFormat.ora.supportsLayers, isTrue);
      expect(SaveFileFormat.tiff.supportsLayers, isTrue);
      expect(SaveFileFormat.png.supportsLayers, isFalse);
      expect(SaveFileFormat.jpeg.supportsLayers, isFalse);
      expect(SaveFileFormat.webp.supportsLayers, isFalse);
      expect(SaveFileFormat.heic.supportsLayers, isFalse);
    });

    test('extensions lists the format own extensions, canonical first', () {
      expect(SaveFileFormat.tiff.extensions, <String>[FileExtensions.tif, FileExtensions.tiff]);
      expect(SaveFileFormat.png.extensions, <String>[FileExtensions.png]);
    });

    test('every declared extension resolves back to its own format', () {
      for (final SaveFileFormat format in SaveFileFormat.values) {
        for (final String extension in format.extensions) {
          expect(SaveFileFormat.fromExtension(extension), format);
        }
      }
    });

    test('TIFF normalizes the target file name, other formats do not', () {
      expect(SaveFileFormat.tiff.normalizeFileName('scan.tiff'), normalizeTiffExportFileName('scan.tiff'));
      expect(SaveFileFormat.png.normalizeFileName('image.png'), 'image.png');
      expect(SaveFileFormat.ora.normalizeFileName('layers.ora'), 'layers.ora');
    });

    test('normalizing an already-normalized TIFF name is stable', () {
      final String once = SaveFileFormat.tiff.normalizeFileName('scan.tiff');

      expect(SaveFileFormat.tiff.normalizeFileName(once), once);
    });
  });
}
