import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/brush_style.dart';
import 'package:fpaint/models/halftone_fill.dart';
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
        ..color = AppColors.black
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
        ..color = AppColors.black
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
      final MyBrush brush = MyBrush(color: AppColors.black, size: 2.0);
      renderPencil(canvas, const Offset(0, 0), const Offset(50, 50), brush);
    });

    test('renderPencilEraser draws with clear blend mode', () {
      final MyBrush brush = MyBrush(size: 5.0);
      renderPencilEraser(canvas, const Offset(0, 0), const Offset(50, 50), brush);
    });

    test('renderRectangle with solid brush', () {
      final MyBrush brush = MyBrush(color: AppColors.black, size: 2.0);
      renderRectangle(canvas, const Offset(10, 10), const Offset(100, 100), brush, AppColors.red);
    });

    test('renderRectangle with dash brush', () {
      final MyBrush brush = MyBrush(color: AppColors.black, size: 2.0, style: BrushStyle.dash);
      renderRectangle(canvas, const Offset(10, 10), const Offset(100, 100), brush, AppColors.blue);
    });

    test('renderCircle with solid brush', () {
      final MyBrush brush = MyBrush(color: AppColors.black, size: 2.0);
      renderCircle(canvas, const Offset(50, 50), const Offset(100, 100), brush, AppColors.green);
    });

    test('renderCircle with dotted brush', () {
      final MyBrush brush = MyBrush(color: AppColors.black, size: 3.0, style: BrushStyle.dotted);
      renderCircle(canvas, const Offset(50, 50), const Offset(100, 100), brush, AppColors.green);
    });

    test('renderLine with solid brush', () {
      final MyBrush brush = MyBrush(color: AppColors.black, size: 2.0);
      renderLine(canvas, const Offset(0, 0), const Offset(100, 100), brush, AppColors.transparent);
    });

    test('renderLine with slash brush', () {
      final MyBrush brush = MyBrush(color: AppColors.black, size: 2.0, style: BrushStyle.slash);
      renderLine(canvas, const Offset(0, 0), const Offset(100, 100), brush, AppColors.transparent);
    });

    test('renderPath with multiple points', () {
      final MyBrush brush = MyBrush(color: AppColors.black, size: 2.0);
      renderPath(
        canvas,
        const <Offset>[Offset(0, 0), Offset(50, 50), Offset(100, 0)],
        brush,
        AppColors.transparent,
      );
    });

    test('renderPath with dashDot brush', () {
      final MyBrush brush = MyBrush(color: AppColors.black, size: 2.0, style: BrushStyle.dashDot);
      renderPath(
        canvas,
        const <Offset>[Offset(0, 0), Offset(50, 50), Offset(100, 0)],
        brush,
        AppColors.transparent,
      );
    });

    test('renderRegion with solid fill', () {
      final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
      renderRegion(canvas, path, AppColors.red, null, null);
    });

    test('renderRegion with gradient fill', () {
      final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
      const LinearGradient gradient = LinearGradient(
        colors: <Color>[AppColors.red, AppColors.blue],
      );
      renderRegion(canvas, path, null, gradient, null);
    });

    test('renderRegionErase clears path area', () {
      final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 50, 50));
      renderRegionErase(canvas, path);
    });
  });

  test('renderRegion with halftone fill follows linear gradient geometry', () async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 40, 20));

    const LinearGradient gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: <Color>[AppColors.white, AppColors.black],
    );

    const HalftoneFill halftoneFill = HalftoneFill(
      backgroundColor: AppColors.white,
      dotColor: AppColors.black,
    );

    renderRegion(canvas, path, null, gradient, halftoneFill);

    final ui.Image image = await recorder.endRecording().toImage(40, 20);

    expect((await _pixelColorAt(image, 1, 1)).toARGB32(), AppColors.white.toARGB32());
    expect((await _pixelColorAt(image, 35, 5)).toARGB32(), AppColors.black.toARGB32());
  });

  test('renderRegion with solid halftone fill draws uniform dots', () async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 20, 20));

    const HalftoneFill halftoneFill = HalftoneFill(
      backgroundColor: AppColors.transparent,
      dotColor: AppColors.black,
    );

    renderRegion(canvas, path, AppColors.white, null, halftoneFill);

    final ui.Image image = await recorder.endRecording().toImage(20, 20);

    expect((await _pixelColorAt(image, 1, 12)).toARGB32(), AppColors.transparent.toARGB32());
    expect((await _pixelColorAt(image, 5, 5)).toARGB32(), AppColors.black.toARGB32());
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
        color: AppColors.black,
        size: 16.0,
      );
      renderText(canvas, textObject);
    });

    test('skips empty text', () {
      final TextObject textObject = TextObject(
        text: '',
        position: const Offset(10, 20),
        color: AppColors.black,
        size: 16.0,
      );
      renderText(canvas, textObject);
    });

    test('skips placeholder text', () {
      final TextObject textObject = TextObject(
        text: 'Type here...',
        position: const Offset(10, 20),
        color: AppColors.black,
        size: 16.0,
      );
      renderText(canvas, textObject);
    });

    test('renders long text', () {
      final TextObject textObject = TextObject(
        text: 'A' * 60,
        position: const Offset(0, 0),
        color: AppColors.black,
        size: 14.0,
      );
      renderText(canvas, textObject);
    });

    test('renders text with bold and italic', () {
      final TextObject textObject = TextObject(
        text: 'Styled',
        position: const Offset(0, 0),
        color: AppColors.red,
        size: 20.0,
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
      );
      renderText(canvas, textObject);
    });
  });
}

Future<Color> _pixelColorAt(final ui.Image image, final int x, final int y) async {
  final ByteData? imageBytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

  expect(imageBytes, isNotNull);

  final int pixelOffset = ((y * image.width) + x) * AppMath.four;

  return Color.fromARGB(
    imageBytes!.getUint8(pixelOffset + AppMath.rgbChannelAlpha),
    imageBytes.getUint8(pixelOffset + AppMath.rgbChannelRed),
    imageBytes.getUint8(pixelOffset + AppMath.rgbChannelGreen),
    imageBytes.getUint8(pixelOffset + AppMath.rgbChannelBlue),
  );
}
