import 'package:flutter_test/flutter_test.dart';
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
}
