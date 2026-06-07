import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/fill_model.dart';

void main() {
  late FillModel model;

  setUp(() {
    model = FillModel();
  });

  group('FillModel defaults', () {
    test('mode defaults to solid', () {
      expect(model.mode, FillMode.solid);
    });

    test('isVisible defaults to false', () {
      expect(model.isVisible, isFalse);
    });

    test('gradientPoints is empty', () {
      expect(model.gradientPoints, isEmpty);
    });
  });

  group('mode setter', () {
    test('can be set to linear', () {
      model.mode = FillMode.linear;
      expect(model.mode, FillMode.linear);
    });

    test('can be set to radial', () {
      model.mode = FillMode.radial;
      expect(model.mode, FillMode.radial);
    });

    test('setting to solid clears gradient points', () {
      model.mode = FillMode.linear;
      model.addPoint(GradientPoint(offset: Offset.zero, color: const Color(0xFFFF0000)));
      model.mode = FillMode.solid;
      expect(model.gradientPoints, isEmpty);
      expect(model.isVisible, isFalse);
    });
  });

  group('clear', () {
    test('clears gradient points and hides', () {
      model.mode = FillMode.linear;
      model.isVisible = true;
      model.sampleAllLayers = true;
      model.addPoint(GradientPoint(offset: const Offset(10, 10), color: const Color(0xFFFF0000)));
      model.addPoint(GradientPoint(offset: const Offset(50, 50), color: const Color(0xFF0000FF)));
      model.clear();
      expect(model.gradientPoints, isEmpty);
      expect(model.isVisible, isFalse);
      expect(model.sampleAllLayers, isFalse);
    });
  });

  group('addPoint', () {
    test('adds a gradient point', () {
      model.addPoint(GradientPoint(offset: const Offset(10, 20), color: const Color(0xFFFF0000)));
      expect(model.gradientPoints.length, 1);
      expect(model.gradientPoints.first.offset, const Offset(10, 20));
      expect(model.gradientPoints.first.color, const Color(0xFFFF0000));
    });

    test('can add multiple points', () {
      model.addPoint(GradientPoint(offset: const Offset(10, 20), color: const Color(0xFFFF0000)));
      model.addPoint(GradientPoint(offset: const Offset(30, 40), color: const Color(0xFF00FF00)));
      model.addPoint(GradientPoint(offset: const Offset(50, 60), color: const Color(0xFF0000FF)));
      expect(model.gradientPoints.length, 3);
    });
  });

  group('centerPoint', () {
    test('returns center of two points', () {
      model.addPoint(GradientPoint(offset: const Offset(0, 0), color: const Color(0xFFFF0000)));
      model.addPoint(GradientPoint(offset: const Offset(100, 200), color: const Color(0xFF0000FF)));
      final Offset center = model.centerPoint;
      expect(center.dx, 50.0);
      expect(center.dy, 100.0);
    });

    test('returns center of three points', () {
      model.addPoint(GradientPoint(offset: const Offset(0, 0), color: const Color(0xFFFF0000)));
      model.addPoint(GradientPoint(offset: const Offset(30, 60), color: const Color(0xFF00FF00)));
      model.addPoint(GradientPoint(offset: const Offset(60, 30), color: const Color(0xFF0000FF)));
      final Offset center = model.centerPoint;
      expect(center.dx, 30.0);
      expect(center.dy, 30.0);
    });

    test('single point returns that point', () {
      model.addPoint(GradientPoint(offset: const Offset(42, 99), color: const Color(0xFFFF0000)));
      final Offset center = model.centerPoint;
      expect(center.dx, 42.0);
      expect(center.dy, 99.0);
    });
  });

  group('GradientPoint', () {
    test('can be constructed', () {
      final GradientPoint point = GradientPoint(
        offset: const Offset(10, 20),
        color: const Color(0xFFFF0000),
      );
      expect(point.offset, const Offset(10, 20));
      expect(point.color, const Color(0xFFFF0000));
    });

    test('offset is mutable', () {
      final GradientPoint point = GradientPoint(
        offset: const Offset(10, 20),
        color: const Color(0xFFFF0000),
      );
      point.offset = const Offset(30, 40);
      expect(point.offset, const Offset(30, 40));
    });

    test('color is mutable', () {
      final GradientPoint point = GradientPoint(
        offset: const Offset(10, 20),
        color: const Color(0xFFFF0000),
      );
      point.color = const Color(0xFF00FF00);
      expect(point.color, const Color(0xFF00FF00));
    });
  });

  group('FillMode enum', () {
    test('has 3 values', () {
      expect(FillMode.values.length, 3);
    });

    test('contains solid, linear, and radial', () {
      expect(FillMode.values, contains(FillMode.solid));
      expect(FillMode.values, contains(FillMode.linear));
      expect(FillMode.values, contains(FillMode.radial));
    });
  });
}
