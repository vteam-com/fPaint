import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/image_helper.dart';

const int _testWidth = 40;
const int _testHeight = 30;

/// Creates a solid-color test image.
ui.Image _createTestImage({
  final Color color = Colors.red,
  final int width = _testWidth,
  final int height = _testHeight,
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

  group('downsampleRgbaBox', () {
    // Builds a [width]x[height] straight-RGBA buffer from per-pixel [pixel]
    // callbacks returning an (r, g, b, a) 4-list.
    Uint8List buildRgba(final int width, final int height, final List<int> Function(int x, int y) pixel) {
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
      final Uint8List src = buildRgba(2, 2, (final int x, final int y) => <int>[10, 20, 30, 40]);
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
      final Uint8List src = buildRgba(2, 2, (final int x, final int y) => reds[(y * 2) + x]);
      final Uint8List dst = downsampleRgbaBox(src, 2, 2, 1, 1);
      expect(dst[0], (0 + 90 + 180 + 250) ~/ 4);
      expect(dst[3], 255);
    });

    test('produces the requested destination dimensions', () {
      final Uint8List src = buildRgba(4, 4, (final int x, final int y) => <int>[x * 10, y * 10, 0, 255]);
      final Uint8List dst = downsampleRgbaBox(src, 4, 4, 2, 2);
      expect(dst.length, 2 * 2 * 4);
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
}
