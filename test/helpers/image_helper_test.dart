import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:material_ui/material_ui.dart';

const int _testWidth = 40;
const int _testHeight = 30;

/// Creates a solid-color test image.
ui.Image _createTestImage({
  Color color = Colors.red,
  int width = _testWidth,
  int height = _testHeight,
}) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  return recorder.endRecording().toImageSync(width, height);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('getImageColors', () {
    test('returns color list for solid image', () async {
      final ui.Image image = _createTestImage(color: Colors.blue);
      final List<ColorUsage> colors = await getImageColors(image);
      expect(colors, isNotEmpty);
      // The dominant color should be blue
      expect(colors.first.percentage, greaterThan(0));
    });

    test('returns empty for fully transparent image', () async {
      final ui.Image image = _createTestImage(color: Colors.transparent);
      final List<ColorUsage> colors = await getImageColors(image);
      expect(colors, isEmpty);
    });
  });

  group('fromBytesToImage', () {
    test('converts PNG bytes to image', () async {
      final ui.Image original = _createTestImage();
      final ByteData? pngData = await original.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = pngData!.buffer.asUint8List();

      final ui.Image decoded = await fromBytesToImage(pngBytes);
      expect(decoded.width, _testWidth);
      expect(decoded.height, _testHeight);
    });
  });

  group('encodeImageToPng', () {
    test('returns PNG-encoded bytes that decode back to the same size', () async {
      final Uint8List? pngBytes = await encodeImageToPng(_createTestImage());

      expect(pngBytes, isNotNull);
      final ui.Image decoded = await fromBytesToImage(pngBytes!);
      expect(decoded.width, _testWidth);
      expect(decoded.height, _testHeight);
    });
  });

  group('unpremultiplyRgbaInPlace', () {
    test('divides colour by alpha and zeroes transparent pixels', () {
      final Uint8List pixels = Uint8List.fromList(<int>[
        64, 32, 0, 128, // half-transparent, premultiplied
        10, 20, 30, 0, // fully transparent with stray colour
        1, 2, 3, 255, // opaque, left untouched
      ]);

      final Uint8List result = unpremultiplyRgbaInPlace(pixels);

      expect(identical(result, pixels), isTrue);
      expect(pixels, <int>[128, 64, 0, 128, 0, 0, 0, 0, 1, 2, 3, 255]);
    });

    test('inverts premultiplyRgbaInPlace for opaque-enough colours', () {
      final List<int> straight = <int>[200, 100, 50, 200];
      final Uint8List pixels = premultiplyRgbaInPlace(Uint8List.fromList(straight));

      unpremultiplyRgbaInPlace(pixels);

      for (int i = 0; i < straight.length; i++) {
        expect((pixels[i] - straight[i]).abs(), lessThanOrEqualTo(1));
      }
    });
  });

  group('downsampleRgbaBox', () {
    // Builds a [width]x[height] straight-RGBA buffer from per-pixel [pixel]
    // callbacks returning an (r, g, b, a) 4-list.
    Uint8List buildRgba(int width, int height, List<int> Function(int x, int y) pixel) {
      final Uint8List out = Uint8List(width * height * 4);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final List<int> channels = pixel(x, y);
          final int index = ((y * width) + x) * 4;
          out[index] = channels[0];
          out[index + 1] = channels[1];
          out[index + 2] = channels[2];
          out[index + 3] = channels[3];
        }
      }
      return out;
    }

    test('preserves a uniform buffer without cross-channel bleed', () {
      // Every source pixel is (10, 20, 30, 40); a 2x2 -> 1x1 box average must
      // return exactly that, proving each channel offset is handled separately.
      final Uint8List src = buildRgba(2, 2, (int x, int y) => <int>[10, 20, 30, 40]);
      final Uint8List dst = downsampleRgbaBox(src, 2, 2, 1, 1);
      expect(dst.length, 1 * 1 * 4);
      expect(dst, <int>[10, 20, 30, 40]);
    });

    test('averages the source pixels mapping into each destination pixel', () {
      // 2x2 with red channel {0, 90, 180, 250}: average = 520 ~/ 4 = 130.
      const List<List<int>> reds = <List<int>>[
        <int>[0, 0, 0, 255],
        <int>[90, 0, 0, 255],
        <int>[180, 0, 0, 255],
        <int>[250, 0, 0, 255],
      ];
      final Uint8List src = buildRgba(2, 2, (int x, int y) => reds[(y * 2) + x]);
      final Uint8List dst = downsampleRgbaBox(src, 2, 2, 1, 1);
      expect(dst[0], (0 + 90 + 180 + 250) ~/ 4);
      expect(dst[3], 255);
    });

    test('produces the requested destination dimensions', () {
      final Uint8List src = buildRgba(4, 4, (int x, int y) => <int>[x * 10, y * 10, 0, 255]);
      final Uint8List dst = downsampleRgbaBox(src, 4, 4, 2, 2);
      expect(dst.length, 2 * 2 * 4);
    });

    test('weights colour by alpha so transparent RGB cannot bleed in', () {
      // Regression guard for the smudge white-edge bug. Two opaque black pixels
      // beside two fully transparent ones whose RGB is white (what a cleared
      // buffer carries). A plain per-channel average returns mid grey at half
      // alpha - a pale fringe. Weighting colour by alpha keeps it black.
      final Uint8List src = buildRgba(2, 2, (int x, int y) {
        final bool ink = y == 0;
        return ink ? <int>[0, 0, 0, 255] : <int>[255, 255, 255, 0];
      });
      final Uint8List dst = downsampleRgbaBox(src, 2, 2, 1, 1);
      expect(dst[3], 127, reason: 'alpha is still a plain count average');
      expect(dst[0], 0, reason: 'only the opaque samples contribute colour');
      expect(dst[1], 0);
      expect(dst[2], 0);
    });

    test('yields zero colour when every source sample is transparent', () {
      final Uint8List src = buildRgba(2, 2, (int x, int y) => <int>[255, 255, 255, 0]);
      final Uint8List dst = downsampleRgbaBox(src, 2, 2, 1, 1);
      expect(dst, <int>[0, 0, 0, 0]);
    });
  });

  group('convertImageToUint8List', () {
    test('returns raw RGBA bytes', () async {
      final ui.Image image = _createTestImage();
      final Uint8List? bytes = await convertImageToUint8List(image);
      expect(bytes, isNotNull);
      // 4 bytes per pixel * width * height
      expect(bytes!.length, _testWidth * _testHeight * 4);
    });
  });

  group('flipImage', () {
    test('flips image horizontally', () async {
      final ui.Image image = _createTestImage();
      final ui.Image flipped = await flipImage(image, isHorizontal: true);
      expect(flipped.width, image.width);
      expect(flipped.height, image.height);
    });

    test('flips image vertically', () async {
      final ui.Image image = _createTestImage();
      final ui.Image flipped = await flipImage(image, isHorizontal: false);
      expect(flipped.width, image.width);
      expect(flipped.height, image.height);
    });
  });

  group('rotateImage90', () {
    test('swaps width and height', () async {
      final ui.Image image = _createTestImage();
      final ui.Image rotated = await rotateImage90(image);
      expect(rotated.width, image.height);
      expect(rotated.height, image.width);
    });

    test('rotates pixels clockwise', () async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 4, 2), Paint()..color = const Color(0xFF0000FF));
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint()..color = const Color(0xFFFF0000));
      final ui.Image image = recorder.endRecording().toImageSync(4, 2);

      final ui.Image rotated = await rotateImage90(image);
      final ByteData? bytes = await rotated.toByteData();

      // Top-left marker of the 4x2 source lands top-right of the 2x4 result.
      const int topRightOffset = 1 * 4;
      expect(bytes!.getUint8(topRightOffset), 0xFF); // red channel
      expect(bytes.getUint8(0), 0x00); // top-left is now blue fill
    });
  });

  group('clipImageToPath', () {
    test('crops to bounds and clears pixels outside the path', () async {
      final ui.Image image = _createTestImage(color: Colors.red);
      const Rect bounds = Rect.fromLTWH(10, 5, 20, 10);
      final ui.Path triangle = ui.Path()
        ..moveTo(bounds.left, bounds.top)
        ..lineTo(bounds.right, bounds.top)
        ..lineTo(bounds.left, bounds.bottom)
        ..close();

      final ui.Image clipped = await clipImageToPath(image, triangle, bounds);
      final ByteData? bytes = await clipped.toByteData();

      expect(clipped.width, 20);
      expect(clipped.height, 10);
      expect(bytes!.getUint8(3), 0xFF); // top-left inside the triangle
      final int bottomRightAlpha = ((clipped.height - 1) * clipped.width + clipped.width - 1) * 4 + 3;
      expect(bytes.getUint8(bottomRightAlpha), 0x00); // outside the path
      expect(image.debugDisposed, isFalse); // source ownership stays with caller
    });
  });

  group('cropImage', () {
    test('crops to specified rect', () {
      final ui.Image image = _createTestImage();
      const Rect cropRect = Rect.fromLTWH(5, 5, 20, 15);
      final ui.Image cropped = cropImage(image, cropRect);
      expect(cropped.width, 20);
      expect(cropped.height, 15);
    });
  });

  group('getNonTransparentBounds', () {
    test('returns bounds for opaque image', () async {
      final ui.Image image = _createTestImage(color: Colors.red);
      final Rect? bounds = await getNonTransparentBounds(image);
      expect(bounds, isNotNull);
      expect(bounds!.left, 0);
      expect(bounds.top, 0);
      expect(bounds.right, _testWidth.toDouble());
      expect(bounds.bottom, _testHeight.toDouble());
    });

    test('returns null for fully transparent image', () async {
      final ui.Image image = _createTestImage(color: Colors.transparent);
      final Rect? bounds = await getNonTransparentBounds(image);
      expect(bounds, isNull);
    });
  });

  group('Debouncer', () {
    late Debouncer debouncer;

    setUp(() {
      debouncer = Debouncer(const Duration(milliseconds: 100));
    });

    test('creates debouncer with default duration', () {
      final Debouncer defaultDebouncer = Debouncer();
      expect(defaultDebouncer.duration, equals(const Duration(seconds: 1)));
    });

    test('creates debouncer with custom duration', () {
      expect(debouncer.duration, equals(const Duration(milliseconds: 100)));
    });

    test('debounces multiple calls', () async {
      int callCount = 0;
      void callback() => callCount++;

      debouncer.run(callback);
      debouncer.run(callback);
      debouncer.run(callback);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(callCount, equals(0));

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(callCount, equals(1));
    });

    test('cancels pending operation', () async {
      int callCount = 0;
      void callback() => callCount++;

      debouncer.run(callback);
      debouncer.cancel();

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(callCount, equals(0));
    });

    test('restarts timer on new calls', () async {
      int callCount = 0;
      void callback() => callCount++;

      debouncer.run(callback);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      debouncer.run(callback);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(callCount, equals(0));

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(callCount, equals(1));
    });
  });

  group('premultiplyRgbaInPlace', () {
    test('scales colour by alpha and returns the same buffer', () {
      // ui.PixelFormat.rgba8888 is premultiplied; handing it straight bytes made
      // the engine divide by alpha twice, blowing a 50% mid grey out to 50%
      // white. This is the conversion that prevents that.
      final Uint8List pixels = Uint8List.fromList(<int>[128, 128, 128, 128]);
      final Uint8List result = premultiplyRgbaInPlace(pixels);
      expect(identical(result, pixels), isTrue, reason: 'converts in place');
      expect(result[0], 64);
      expect(result[1], 64);
      expect(result[2], 64);
      expect(result[3], 128, reason: 'alpha is untouched');
    });

    test('leaves fully opaque pixels unchanged', () {
      final Uint8List pixels = Uint8List.fromList(<int>[10, 200, 255, 255]);
      premultiplyRgbaInPlace(pixels);
      expect(pixels, <int>[10, 200, 255, 255]);
    });

    test('zeroes the colour of fully transparent pixels', () {
      // A transparent pixel's straight RGB is undefined; zeroing it stops the
      // white of a cleared buffer bleeding out during GPU interpolation.
      final Uint8List pixels = Uint8List.fromList(<int>[255, 255, 255, 0]);
      premultiplyRgbaInPlace(pixels);
      expect(pixels, <int>[0, 0, 0, 0]);
    });

    test('round-trips through a decoded image without lightening the colour', () async {
      // End-to-end proof: a 50%-opaque mid grey must come back as 50% mid grey.
      // Before the fix it returned (255, 255, 255, 128) - pure white.
      final Uint8List straight = Uint8List.fromList(<int>[128, 128, 128, 128]);
      final ui.Image decoded = await imageFromPixelsDecode(
        premultiplyRgbaInPlace(Uint8List.fromList(straight)),
        1,
        1,
      );
      final Uint8List? readBack = await extractImagePixels(
        decoded,
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      decoded.dispose();
      expect(readBack, isNotNull);
      expect(readBack![3], 128);
      expect(readBack[0], closeTo(128, 2));
      expect(readBack[1], closeTo(128, 2));
      expect(readBack[2], closeTo(128, 2));
    });
  });

  test('copyRgbaRect and blitRgbaRect round-trip a sub-rectangle', () {
    const int width = 4;
    const int height = 3;
    final Uint8List pixels = Uint8List.fromList(List<int>.generate(width * height * 4, (int i) => i));
    final Uint8List patch = copyRgbaRect(pixels: pixels, imageWidth: width, left: 1, top: 1, width: 2, height: 2);
    expect(patch.sublist(0, 4), pixels.sublist(20, 24));
    expect(patch.sublist(8, 12), pixels.sublist(36, 40));

    final Uint8List destination = Uint8List(pixels.length);
    blitRgbaRect(source: patch, destination: destination, imageWidth: width, left: 1, top: 1, width: 2, height: 2);
    expect(destination.sublist(20, 28), pixels.sublist(20, 28));
    expect(destination.sublist(36, 44), pixels.sublist(36, 44));
    expect(destination.sublist(0, 20).every((int v) => v == 0), isTrue);
  });
}
