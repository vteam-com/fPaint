import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/brush_style.dart';
import 'package:fpaint/models/hatch_marks.dart';
import 'package:fpaint/models/hatch_marks_renderer.dart';
import 'package:fpaint/models/render_helper.dart';

void main() {
  group('HatchMarks', () {
    test('defaults come from AppHatchMarks', () {
      const HatchMarks marks = HatchMarks();
      expect(marks.angleDegrees, AppHatchMarks.defaultAngleDegrees);
      expect(marks.spacing, AppHatchMarks.defaultSpacing);
      expect(marks.length, AppHatchMarks.defaultLength);
      expect(marks.taperPercent, AppHatchMarks.defaultTaperPercent);
      expect(marks.curvePercent, AppHatchMarks.defaultCurvePercent);
      expect(marks.taper, 1.0);
      expect(marks.curve, 0.0);
    });

    test('angleRadians wraps a full turn and fractions convert', () {
      expect(const HatchMarks(angleDegrees: 90).angleRadians, closeTo(math.pi / 2, 1e-9));
      expect(const HatchMarks(angleDegrees: 360).angleRadians, 0);
      expect(const HatchMarks(taperPercent: 50).taper, 0.5);
      expect(const HatchMarks(curvePercent: -100).curve, -1.0);
    });

    test('copyWith, clamped, equality', () {
      const HatchMarks base = HatchMarks(angleDegrees: 45, spacing: 4, length: 30, taperPercent: 70, curvePercent: 10);
      expect(base.copyWith(length: 50).length, 50);
      expect(base.copyWith(), base);
      expect(base.copyWith(curvePercent: 20), isNot(base));
      expect(base.hashCode, base.copyWith().hashCode);
      expect(base.toString(), contains('30'));

      final HatchMarks clamped = const HatchMarks(
        angleDegrees: 999,
        spacing: 0,
        length: 9999,
        taperPercent: 300,
        curvePercent: -500,
      ).clamped();
      expect(clamped.angleDegrees, AppHatchMarks.maxAngleDegrees);
      expect(clamped.spacing, AppHatchMarks.minSpacing);
      expect(clamped.length, AppHatchMarks.maxLength);
      expect(clamped.taperPercent, AppLimits.percentMax);
      expect(clamped.curvePercent, AppHatchMarks.minCurvePercent);
    });
  });

  group('hatch marks renderer', () {
    Future<ByteData> render(void Function(Canvas canvas) draw) async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      draw(canvas);
      final ui.Image image = await recorder.endRecording().toImage(128, 128);
      final ByteData bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      image.dispose();
      return bytes;
    }

    int alphaAt(ByteData data, int x, int y) => data.getUint8((y * 128 + x) * 4 + 3);

    test('marks fan out perpendicular to the stroke and taper toward the tip', () async {
      // Horizontal stroke at y=100 heading right; 90° = upward on screen.
      const HatchMarks marks = HatchMarks(angleDegrees: 90, spacing: 10, length: 60, taperPercent: 100);
      final ByteData bytes = await render((Canvas canvas) {
        drawPathWithBrushStyle(
          canvas,
          Paint()..color = AppColors.black,
          Path()
            ..moveTo(10, 100)
            ..lineTo(110, 100),
          BrushStyle.hatchMarks,
          8.0,
          marks: marks,
        );
      });

      // A mark starts at x=10 (base) and rises to y=40 (tip).
      final int nearBase = alphaAt(bytes, 10, 95);
      final int midway = alphaAt(bytes, 10, 70);
      final int nearTip = alphaAt(bytes, 10, 45);
      expect(nearBase, greaterThan(200));
      expect(midway, greaterThan(0));
      expect(midway, lessThan(nearBase));
      expect(nearTip, lessThan(midway));
      // Nothing is painted below the stroke (marks only fan out to one side)
      // and nothing beyond the mark length.
      expect(alphaAt(bytes, 10, 110), 0);
      expect(alphaAt(bytes, 10, 30), 0);
      // Marks are discrete: between two bases (x=10 and x=20) the gap is empty.
      expect(alphaAt(bytes, 15, 80), 0);
    });

    test('taper 0 keeps full width and opacity to the tip', () async {
      const HatchMarks marks = HatchMarks(angleDegrees: 90, spacing: 20, length: 60, taperPercent: 0);
      final ByteData bytes = await render((Canvas canvas) {
        drawHatchMark(canvas, const Offset(64, 100), math.pi / 2, AppColors.black, 8.0, marks);
      });
      expect(alphaAt(bytes, 64, 95), greaterThan(250));
      expect(alphaAt(bytes, 64, 45), greaterThan(250));
      // Full width at the tip: 3px off-centre is still inside an 8px mark.
      expect(alphaAt(bytes, 67, 45), greaterThan(200));
    });

    test('curve bends the tip sideways', () async {
      const HatchMarks straight = HatchMarks(length: 60, taperPercent: 0);
      const HatchMarks bent = HatchMarks(length: 60, taperPercent: 0, curvePercent: 100);
      final ByteData straightBytes = await render((Canvas canvas) {
        drawHatchMark(canvas, const Offset(64, 100), math.pi / 2, AppColors.black, 6.0, straight);
      });
      final ByteData bentBytes = await render((Canvas canvas) {
        drawHatchMark(canvas, const Offset(64, 100), math.pi / 2, AppColors.black, 6.0, bent);
      });
      // The straight tip sits on the base column; the bent tip has mostly
      // left it and is painted well off to the side instead.
      expect(alphaAt(straightBytes, 64, 45), greaterThan(200));
      expect(alphaAt(bentBytes, 64, 45), lessThan(100));
      final bool paintedToTheSide =
          List<int>.generate(50, (int i) => alphaAt(bentBytes, 14 + i, 45)).any((int a) => a > 200) ||
          List<int>.generate(50, (int i) => alphaAt(bentBytes, 70 + i, 45)).any((int a) => a > 200);
      expect(paintedToTheSide, isTrue);
    });

    test('a single tap draws one mark and shapes accept the style', () {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final MyBrush brush = MyBrush(style: BrushStyle.hatchMarks, color: AppColors.black, size: 4);
      renderPath(canvas, <Offset>[const Offset(5, 5), const Offset(5, 5)], brush, AppColors.black);
      renderLine(canvas, const Offset(0, 0), const Offset(50, 0), brush, AppColors.black);
      renderRectangle(canvas, const Offset(0, 0), const Offset(50, 40), brush, AppColors.transparent);
      renderCircle(canvas, const Offset(0, 0), const Offset(50, 50), brush, AppColors.transparent);
      recorder.endRecording();
    });

    test('hatchMarksOutset covers the mark length plus half the base width', () {
      const HatchMarks marks = HatchMarks(length: 40);
      expect(hatchMarksOutset(10, marks), 45);
    });
  });
}
