import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/widgets/image_painter.dart';

Future<ui.Image> _makeImage(int width, int height) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = Colors.blue,
  );
  return recorder.endRecording().toImage(width, height);
}

void main() {
  group('ImagePainter', () {
    test('repaints when the image handle changes', () async {
      final ui.Image first = await _makeImage(8, 8);
      final ui.Image second = await _makeImage(8, 8);
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      // A constant `false` here is what stranded the old painter (and its
      // already-disposed image) across a thumbnail swap.
      expect(ImagePainter(second).shouldRepaint(ImagePainter(first)), isTrue);
      expect(ImagePainter(first).shouldRepaint(ImagePainter(first)), isFalse);
    });

    test('skips the draw instead of asserting on a disposed image', () async {
      final ui.Image image = await _makeImage(8, 8);
      final ImagePainter painter = ImagePainter(image);

      // Mirrors a thumbnail freed between frame scheduling and paint.
      image.dispose();

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      expect(() => painter.paint(canvas, const Size(60, 60)), returnsNormally);
      recorder.endRecording().dispose();
    });

    test('draws a live image scaled and centred', () async {
      final ui.Image image = await _makeImage(8, 4);
      addTearDown(image.dispose);
      final ImagePainter painter = ImagePainter(image);

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      expect(() => painter.paint(canvas, const Size(60, 60)), returnsNormally);
      recorder.endRecording().dispose();
    });
  });
}
