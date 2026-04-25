import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/brush_style.dart';
import 'package:fpaint/models/render_helper.dart';
import 'package:fpaint/models/text_object.dart';

void main() {
  group('createDashedPath', () {
    test('returns empty path for empty source', () {
      final Path source = Path();
      final Path result = createDashedPath(source, dashWidth: 4.0, dashGap: 4.0);
      expect(result.computeMetrics().isEmpty, isTrue);
    });

    test('produces segments from a straight line', () {
      final Path source = Path()
        ..moveTo(0, 0)
        ..lineTo(100, 0);
      final Path result = createDashedPath(source, dashWidth: 10.0, dashGap: 5.0);
      final List<ui.PathMetric> metrics = result.computeMetrics().toList();
      // 100 / (10+5) = ~6.67 → expect 7 segments
      expect(metrics.length, greaterThanOrEqualTo(6));
    });
  });

  group('drawPathWithBrushStyle', () {
    late ui.PictureRecorder recorder;
    late Canvas canvas;
    late Paint paint;
    late Path path;

    setUp(() {
      recorder = ui.PictureRecorder();
      canvas = Canvas(recorder);
      paint = Paint()
        ..color = AppPalette.black
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke;
      path = Path()
        ..moveTo(0, 0)
        ..lineTo(200, 0);
    });

    tearDown(() {
      recorder.endRecording();
    });

    test('solid draws without error', () {
      drawPathWithBrushStyle(canvas, paint, path, BrushStyle.solid, 4.0);
    });

    test('dash draws without error', () {
      drawPathWithBrushStyle(canvas, paint, path, BrushStyle.dash, 4.0);
    });

    test('dotted draws without error', () {
      drawPathWithBrushStyle(canvas, paint, path, BrushStyle.dotted, 4.0);
    });

    test('dashDot draws without error', () {
      drawPathWithBrushStyle(canvas, paint, path, BrushStyle.dashDot, 4.0);
    });

    test('slash draws without error', () {
      drawPathWithBrushStyle(canvas, paint, path, BrushStyle.slash, 4.0);
    });
  });

  group('drawPathDash', () {
    test('draws on a non-empty path', () {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final Paint paint = Paint()
        ..color = AppPalette.black
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      final Path path = Path()
        ..moveTo(0, 0)
        ..lineTo(100, 0);
      drawPathDash(path, canvas, paint, 8.0, 4.0);
      recorder.endRecording();
    });
  });

  group('render functions', () {
    late ui.PictureRecorder recorder;
    late Canvas canvas;

    setUp(() {
      recorder = ui.PictureRecorder();
      canvas = Canvas(recorder);
    });

    tearDown(() {
      recorder.endRecording();
    });

    test('renderPencil draws a line', () {
      final MyBrush brush = MyBrush(color: AppPalette.black, size: 2.0);
      renderPencil(canvas, const Offset(0, 0), const Offset(50, 50), brush);
    });

    test('renderPencilEraser draws with clear blend mode', () {
      final MyBrush brush = MyBrush(size: 5.0);
      renderPencilEraser(canvas, const Offset(0, 0), const Offset(50, 50), brush);
    });

    test('renderRectangle with solid brush', () {
      final MyBrush brush = MyBrush(color: AppPalette.black, size: 2.0);
      renderRectangle(canvas, const Offset(10, 10), const Offset(100, 100), brush, AppPalette.red);
    });

    test('renderRectangle with dash brush', () {
      final MyBrush brush = MyBrush(color: AppPalette.black, size: 2.0, style: BrushStyle.dash);
      renderRectangle(canvas, const Offset(10, 10), const Offset(100, 100), brush, AppPalette.blue);
    });

    test('renderCircle with solid brush', () {
      final MyBrush brush = MyBrush(color: AppPalette.black, size: 2.0);
      renderCircle(canvas, const Offset(50, 50), const Offset(100, 100), brush, AppPalette.green);
    });

    test('renderCircle with dotted brush', () {
      final MyBrush brush = MyBrush(color: AppPalette.black, size: 3.0, style: BrushStyle.dotted);
      renderCircle(canvas, const Offset(50, 50), const Offset(100, 100), brush, AppPalette.green);
    });

    test('renderLine with solid brush', () {
      final MyBrush brush = MyBrush(color: AppPalette.black, size: 2.0);
      renderLine(canvas, const Offset(0, 0), const Offset(100, 100), brush, AppPalette.transparent);
    });

    test('renderLine with slash brush', () {
      final MyBrush brush = MyBrush(color: AppPalette.black, size: 2.0, style: BrushStyle.slash);
      renderLine(canvas, const Offset(0, 0), const Offset(100, 100), brush, AppPalette.transparent);
    });

    test('renderPath with multiple points', () {
      final MyBrush brush = MyBrush(color: AppPalette.black, size: 2.0);
      renderPath(
        canvas,
        const <Offset>[Offset(0, 0), Offset(50, 50), Offset(100, 0)],
        brush,
        AppPalette.transparent,
      );
    });

    test('renderPath with dashDot brush', () {
      final MyBrush brush = MyBrush(color: AppPalette.black, size: 2.0, style: BrushStyle.dashDot);
      renderPath(
        canvas,
        const <Offset>[Offset(0, 0), Offset(50, 50), Offset(100, 0)],
        brush,
        AppPalette.transparent,
      );
    });

    test('renderRegion with solid fill', () {
      final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
      renderRegion(canvas, path, AppPalette.red, null);
    });

    test('renderRegion with gradient fill', () {
      final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
      const LinearGradient gradient = LinearGradient(
        colors: <Color>[AppPalette.red, AppPalette.blue],
      );
      renderRegion(canvas, path, null, gradient);
    });

    test('renderRegionErase clears path area', () {
      final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 50, 50));
      renderRegionErase(canvas, path);
    });
  });

  group('renderText', () {
    late ui.PictureRecorder recorder;
    late Canvas canvas;

    setUp(() {
      recorder = ui.PictureRecorder();
      canvas = Canvas(recorder);
    });

    tearDown(() {
      recorder.endRecording();
    });

    test('renders non-empty text', () {
      final TextObject textObject = TextObject(
        text: 'Hello World',
        position: const Offset(10, 20),
        color: AppPalette.black,
        size: 16.0,
      );
      renderText(canvas, textObject);
    });

    test('skips empty text', () {
      final TextObject textObject = TextObject(
        text: '',
        position: const Offset(10, 20),
        color: AppPalette.black,
        size: 16.0,
      );
      renderText(canvas, textObject);
    });

    test('skips placeholder text', () {
      final TextObject textObject = TextObject(
        text: 'Type here...',
        position: const Offset(10, 20),
        color: AppPalette.black,
        size: 16.0,
      );
      renderText(canvas, textObject);
    });

    test('renders long text', () {
      final TextObject textObject = TextObject(
        text: 'A' * 60,
        position: const Offset(0, 0),
        color: AppPalette.black,
        size: 14.0,
      );
      renderText(canvas, textObject);
    });

    test('renders text with bold and italic', () {
      final TextObject textObject = TextObject(
        text: 'Styled',
        position: const Offset(0, 0),
        color: AppPalette.red,
        size: 20.0,
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
      );
      renderText(canvas, textObject);
    });
  });
}
