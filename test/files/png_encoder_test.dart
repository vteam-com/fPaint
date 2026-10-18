import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/png_encoder.dart';

const int _width = 7;
const int _height = 5;
const int _bytesPerPixel = 4;
const int _byteRange = 256;
const int _budget = 100;
const int _halfBudget = 60;

/// A deterministic opaque gradient that exercises the row filter. Opaque,
/// because the engine premultiplies decoded PNGs, which would round
/// translucent pixels on the way back and hide encoder bugs behind noise.
Uint8List _gradient() {
  final Uint8List rgba = Uint8List(_width * _height * _bytesPerPixel);
  for (int i = 0; i < rgba.length; i++) {
    rgba[i] = (i * 37 + i ~/ _bytesPerPixel) % _byteRange;
  }
  for (int p = 0; p < _width * _height; p++) {
    rgba[p * _bytesPerPixel + 3] = 255;
  }
  return rgba;
}

Future<Uint8List> _decodeStraightRgba(Uint8List png) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  final ui.Image image = (await codec.getNextFrame()).image;
  final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!;
  image.dispose();
  return data.buffer.asUint8List();
}

void main() {
  testWidgets('encodeStraightRgbaPng round-trips pixels exactly at every level', (WidgetTester tester) async {
    await tester.runAsync(() async {
      final Uint8List rgba = _gradient();
      for (final int level in <int>[1, 4, 9]) {
        final Uint8List png = encodeStraightRgbaPng(rgba: rgba, width: _width, height: _height, level: level);
        expect(listEquals(await _decodeStraightRgba(png), rgba), isTrue, reason: 'level $level');
      }
    });
  });

  testWidgets('encodeImageToPngFast matches the source image and can release it', (WidgetTester tester) async {
    await tester.runAsync(() async {
      final Uint8List rgba = _gradient();
      final Completer<ui.Image> decoded = Completer<ui.Image>();
      ui.decodeImageFromPixels(rgba, _width, _height, ui.PixelFormat.rgba8888, decoded.complete);
      final ui.Image image = await decoded.future;
      final Uint8List expected = (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer
          .asUint8List();

      final Uint8List png = (await encodeImageToPngFast(image, disposeAfterReadback: true))!;

      expect(image.debugDisposed, isTrue);
      expect(listEquals(await _decodeStraightRgba(png), expected), isTrue);
    });
  });

  group('PngEncodePool', () {
    test('runs jobs that fit the budget together and queues the rest', () async {
      final PngEncodePool pool = PngEncodePool(pixelBudget: _budget);
      final Completer<void> releaseFirst = Completer<void>();
      final List<String> started = <String>[];

      final Future<void> first = pool.run(_halfBudget, () async {
        started.add('first');
        await releaseFirst.future;
      });
      final Future<void> second = pool.run(_halfBudget, () async => started.add('second'));
      await Future<void>.delayed(Duration.zero);
      expect(started, <String>['first'], reason: 'the second job would exceed the budget');

      releaseFirst.complete();
      await Future.wait(<Future<void>>[first, second]);
      expect(started, <String>['first', 'second']);
    });

    test('always runs a lone job larger than the budget', () async {
      final PngEncodePool pool = PngEncodePool(pixelBudget: _budget);
      expect(await pool.run(_budget * 2, () async => 'done'), 'done');
    });

    test('releases its slot when a job throws', () async {
      final PngEncodePool pool = PngEncodePool(pixelBudget: _budget);
      await expectLater(pool.run(_budget, () async => throw StateError('boom')), throwsStateError);
      expect(await pool.run(_budget, () async => 'next'), 'next');
    });

    test('platform budget is positive', () {
      expect(PngEncodePool.platformPixelBudget, greaterThan(0));
    });
  });
}
