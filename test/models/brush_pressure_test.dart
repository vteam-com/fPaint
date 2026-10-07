import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/stylus_pressure.dart';
import 'package:fpaint/models/render_helper.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/layer_provider.dart';

const int _imageWidth = 200;
const int _imageHeight = 120;
const double _strokeY = 60;
const double _brushSize = 30;
const int _alphaThreshold = 128;
const int _opaque = 255;

/// Pressure at which a stroke paints exactly the set brush size.
const double _nominalPressure =
    (1 - AppInteraction.brushPressureMinWidthFactor) /
    (AppInteraction.brushPressureMaxWidthFactor - AppInteraction.brushPressureMinWidthFactor);

/// Evenly spaced points along a horizontal line across the image.
List<Offset> _horizontalPoints(int pointCount) => List<Offset>.generate(
  pointCount,
  (int i) => Offset(20 + i * (160 / (pointCount - 1)), _strokeY),
);

/// Renders a Brush stroke through [points] (a horizontal line by default) with
/// the given [pressures], returning its RGBA bytes.
Future<ByteData> _renderStroke({required MyBrush brush, List<double>? pressures, List<Offset>? points}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  renderPath(Canvas(recorder), points ?? _horizontalPoints(11), brush, AppColors.transparent, pressures: pressures);
  final ui.Image image = await recorder.endRecording().toImage(_imageWidth, _imageHeight);
  return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
}

int _alphaAt(ByteData bytes, int x, int y) => bytes.getUint8((y * _imageWidth + x) * 4 + 3);

/// Height of the painted band in column [x] (pixels above the alpha threshold).
int _columnCoverage(ByteData bytes, int x) {
  int count = 0;
  for (int y = 0; y < _imageHeight; y++) {
    if (_alphaAt(bytes, x, y) >= _alphaThreshold) {
      count++;
    }
  }
  return count;
}

/// Total ink in column [x], in pixels: the summed alpha over [_opaque], which is
/// the painted width even when antialiasing spreads it over partial pixels.
double _columnInk(ByteData bytes, int x) {
  int sum = 0;
  for (int y = 0; y < _imageHeight; y++) {
    sum += _alphaAt(bytes, x, y);
  }
  return sum / _opaque;
}

void main() {
  group('stylusPressure', () {
    test('normalizes a pen pressure into 0..1 over the reported range', () {
      const PointerDownEvent event = PointerDownEvent(
        kind: PointerDeviceKind.stylus,
        pressure: 0.75,
        pressureMin: 0.5,
        pressureMax: 1.0,
      );
      expect(stylusPressure(event), closeTo(0.5, 1e-9));
    });

    test('ignores mouse and touch, which paint at the full size', () {
      expect(stylusPressure(const PointerDownEvent(pressure: 0.3)), isNull);
      expect(stylusPressure(const PointerDownEvent(kind: PointerDeviceKind.touch, pressure: 0.3)), isNull);
    });

    test('ignores a pen that reports no pressure range', () {
      const PointerDownEvent event = PointerDownEvent(
        kind: PointerDeviceKind.stylus,
        pressure: 1.0,
        pressureMin: 1.0,
        pressureMax: 1.0,
      );
      expect(stylusPressure(event), isNull);
    });
  });

  group('pressureWidthFactor', () {
    test('runs from the light-touch minimum to the heavy-press maximum', () {
      expect(pressureWidthFactor(0), AppInteraction.brushPressureMinWidthFactor);
      expect(pressureWidthFactor(1), closeTo(AppInteraction.brushPressureMaxWidthFactor, 1e-9));
      expect(pressureWidthFactor(0.5), greaterThan(pressureWidthFactor(0.25)));
    });

    test('puts the set brush size mid-range, so heavy presses paint larger', () {
      expect(AppInteraction.brushPressureMaxWidthFactor, greaterThan(1));
      expect(pressureWidthFactor(_nominalPressure), closeTo(1, 1e-9));
      expect(_nominalPressure, inInclusiveRange(0.4, 0.6));
    });

    test('the stroke width never drops below the 1 px hairline', () {
      expect(pressureStrokeWidth(_brushSize, 0), AppInteraction.brushPressureMinTipWidth);
      expect(pressureStrokeWidth(500, 0), AppInteraction.brushPressureMinTipWidth);
      expect(
        pressureStrokeWidth(_brushSize, 1),
        closeTo(_brushSize * AppInteraction.brushPressureMaxWidthFactor, 1e-9),
      );
    });

    test('clamps out-of-range pressure', () {
      expect(pressureWidthFactor(-1), AppInteraction.brushPressureMinWidthFactor);
      expect(pressureWidthFactor(2), closeTo(AppInteraction.brushPressureMaxWidthFactor, 1e-9));
    });
  });

  group('taperPressureTip', () {
    test('a fading lift-off drops the last sample to zero', () {
      final List<double> pressures = <double>[0.9, 0.6, 0.2];
      expect(taperPressureTip(pressures), isTrue);
      expect(pressures, <double>[0.9, 0.6, 0]);
    });

    test('a firm lift-off keeps its blunt end', () {
      final List<double> pressures = <double>[0.4, 0.8];
      expect(taperPressureTip(pressures), isFalse);
      expect(pressures, <double>[0.4, 0.8]);
    });

    test('an empty stroke is left alone', () {
      expect(taperPressureTip(<double>[]), isFalse);
    });
  });

  group('pressure-sensitive Brush rendering', () {
    test('a heavy-to-none stroke on a large brush ends in a 1 px tip', () async {
      final ByteData bytes = await _renderStroke(
        brush: MyBrush(color: AppColors.black, size: _brushSize),
        pressures: List<double>.generate(11, (int i) => 1 - i / 10),
      );

      // The last point sits at x = 180, so the column just inside it holds only
      // the hairline tip. Measured as total ink: an antialiased 1 px line
      // centred on a pixel boundary splits across two half-covered rows.
      expect(_columnInk(bytes, 179), inInclusiveRange(0.5, 1.5));
      expect(_columnCoverage(bytes, 20), greaterThan(_brushSize * 1.5));
    });

    test('a light-to-heavy stroke grows from a hairline to twice the brush size', () async {
      final ByteData bytes = await _renderStroke(
        brush: MyBrush(color: AppColors.black, size: _brushSize),
        pressures: List<double>.generate(11, (int i) => i / 10),
      );

      final int start = _columnCoverage(bytes, 22);
      final int end = _columnCoverage(bytes, 178);
      expect(start, lessThan(_brushSize * 0.3));
      expect(end, closeTo(_brushSize * AppInteraction.brushPressureMaxWidthFactor, 3));
    });

    test('light pressure paints thinner and heavy pressure thicker than the set size', () async {
      final MyBrush brush = MyBrush(color: AppColors.black, size: _brushSize);
      final int uniform = _columnCoverage(await _renderStroke(brush: brush), 100);
      final int nominal = _columnCoverage(
        await _renderStroke(brush: brush, pressures: List<double>.filled(11, _nominalPressure)),
        100,
      );
      final int light = _columnCoverage(
        await _renderStroke(brush: brush, pressures: List<double>.filled(11, 0.2)),
        100,
      );
      final int heavy = _columnCoverage(
        await _renderStroke(brush: brush, pressures: List<double>.filled(11, 0.9)),
        100,
      );

      expect(nominal, closeTo(uniform, 2));
      expect(light, lessThan(uniform));
      expect(heavy, greaterThan(uniform));
    });

    test('a translucent colour stays even across segment joints', () async {
      final ByteData bytes = await _renderStroke(
        brush: MyBrush(color: AppColors.black.withValues(alpha: 0.5), size: _brushSize),
        pressures: List<double>.filled(11, 1),
      );
      // Point 5 (a joint where two discs and two segments overlap) vs a
      // mid-segment pixel.
      final int atJoint = _alphaAt(bytes, 100, _strokeY.toInt());
      final int midSegment = _alphaAt(bytes, 108, _strokeY.toInt());
      expect(atJoint, closeTo(midSegment, 2));
    });

    test('a zig-zag stroke has no holes where its pieces overlap', () async {
      const List<Offset> zigZag = <Offset>[
        Offset(30, 40),
        Offset(70, 80),
        Offset(110, 40),
        Offset(150, 80),
        Offset(170, 50),
      ];
      final ByteData bytes = await _renderStroke(
        brush: MyBrush(color: AppColors.black, size: _brushSize),
        pressures: <double>[0.3, 0.6, 0.9, 0.5, 0.7],
        points: zigZag,
      );
      for (int i = 0; i < zigZag.length; i++) {
        final Offset point = zigZag[i];
        expect(_alphaAt(bytes, point.dx.round(), point.dy.round()), _opaque, reason: 'point $i');
        if (i > 0) {
          final Offset mid = (zigZag[i - 1] + point) / 2;
          expect(_alphaAt(bytes, mid.dx.round(), mid.dy.round()), _opaque, reason: 'segment $i');
        }
      }
    });

    test('patterned styles ignore pressure and keep a constant width', () async {
      final MyBrush dashed = MyBrush(color: AppColors.black, size: _brushSize, style: BrushStyle.dash);
      final ByteData pressured = await _renderStroke(brush: dashed, pressures: List<double>.filled(11, 0));
      final ByteData uniform = await _renderStroke(brush: dashed);

      for (int x = 0; x < _imageWidth; x += 10) {
        expect(_columnCoverage(pressured, x), _columnCoverage(uniform, x), reason: 'column $x');
      }
    });
  });

  group('LayerProvider.lastActionAppendPosition', () {
    StrokeAction brushStroke({List<double>? pressures}) => StrokeAction(
      action: ActionType.brush,
      positions: <Offset>[Offset.zero, Offset.zero],
      brush: MyBrush(color: AppColors.black, size: _brushSize),
      pressures: pressures,
    );

    test('keeps one pressure sample per point', () {
      final LayerProvider layer = LayerProvider(name: 'test', size: const Size(100, 100), onThumbnailChanged: () {});
      final StrokeAction stroke = brushStroke(pressures: <double>[0.2, 0.2]);
      layer.appendDrawingAction(stroke);

      layer.lastActionAppendPosition(position: const Offset(10, 0), pressure: 0.6);
      layer.lastActionAppendPosition(position: const Offset(20, 0));

      expect(stroke.positions.length, 4);
      expect(stroke.pressures, <double>[0.2, 0.2, 0.6, 0.6]);
    });

    test('leaves a pressure-less stroke without pressure', () {
      final LayerProvider layer = LayerProvider(name: 'test', size: const Size(100, 100), onThumbnailChanged: () {});
      final StrokeAction stroke = brushStroke();
      layer.appendDrawingAction(stroke);

      layer.lastActionAppendPosition(position: const Offset(10, 0), pressure: 0.6);

      expect(stroke.positions.length, 3);
      expect(stroke.pressures, isNull);
    });

    test('an awaiting stroke stays empty until its first sample, then back-fills', () {
      final LayerProvider layer = LayerProvider(name: 'test', size: const Size(100, 100), onThumbnailChanged: () {});
      final StrokeAction stroke = brushStroke(pressures: <double>[]);
      layer.appendDrawingAction(stroke);

      layer.lastActionAppendPosition(position: const Offset(10, 0));
      expect(stroke.pressures, isEmpty);

      layer.lastActionAppendPosition(position: const Offset(20, 0), pressure: 0.4);
      expect(stroke.pressures, <double>[0.4, 0.4, 0.4, 0.4]);
    });

    test('rotate/flip copies keep the pressure samples', () {
      final StrokeAction stroke = brushStroke(pressures: <double>[0.1, 0.9]);
      final StrokeAction moved = stroke.copyWith(positions: <Offset>[const Offset(5, 5), const Offset(6, 6)]);
      expect(moved.pressures, <double>[0.1, 0.9]);
    });
  });
}
