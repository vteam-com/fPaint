import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/hatch_pattern.dart';

void main() {
  group('HatchPattern', () {
    test('defaults come from AppHatch', () {
      const HatchPattern pattern = HatchPattern();
      expect(pattern.angleDegrees, AppHatch.defaultAngleDegrees);
      expect(pattern.spacing, AppHatch.defaultSpacing);
      expect(pattern.lineWidth, AppHatch.defaultLineWidth);
      expect(pattern.crossed, isFalse);
    });

    test('angleRadians converts degrees and wraps every half turn', () {
      expect(const HatchPattern(angleDegrees: 0).angleRadians, 0);
      expect(const HatchPattern(angleDegrees: 90).angleRadians, closeTo(math.pi / 2, 1e-9));
      expect(const HatchPattern(angleDegrees: 180).angleRadians, 0);
      expect(const HatchPattern(angleDegrees: 225).angleRadians, closeTo(math.pi / 4, 1e-9));
    });

    test('effectiveLineWidth stays at least one pixel below the spacing', () {
      expect(const HatchPattern(spacing: 8, lineWidth: 3).effectiveLineWidth, 3);
      expect(const HatchPattern(spacing: 4, lineWidth: 16).effectiveLineWidth, 3);
      expect(const HatchPattern(spacing: 2, lineWidth: 0).effectiveLineWidth, AppHatch.minLineWidth);
    });

    test('copyWith replaces only the given fields', () {
      const HatchPattern base = HatchPattern(angleDegrees: 30, spacing: 10, lineWidth: 2);
      final HatchPattern crossed = base.copyWith(crossed: true);
      expect(crossed.angleDegrees, 30);
      expect(crossed.spacing, 10);
      expect(crossed.lineWidth, 2);
      expect(crossed.crossed, isTrue);
      expect(base.copyWith(spacing: 12).spacing, 12);
      expect(base.copyWith(), base);
    });

    test('clamped keeps every field inside the AppHatch bounds', () {
      const HatchPattern wild = HatchPattern(angleDegrees: 999, spacing: 1, lineWidth: 500, crossed: true);
      final HatchPattern clamped = wild.clamped();
      expect(clamped.angleDegrees, AppHatch.maxAngleDegrees);
      expect(clamped.spacing, AppHatch.minSpacing);
      expect(clamped.lineWidth, AppHatch.maxLineWidth);
      expect(clamped.crossed, isTrue);
      expect(const HatchPattern(angleDegrees: -5).clamped().angleDegrees, AppHatch.minAngleDegrees);
      expect(const HatchPattern().clamped(), const HatchPattern());
    });

    test('value equality and hashCode', () {
      const HatchPattern a = HatchPattern(angleDegrees: 45, spacing: 8, lineWidth: 1);
      const HatchPattern b = HatchPattern(angleDegrees: 45, spacing: 8, lineWidth: 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(a.copyWith(crossed: true)));
      expect(a, isNot(a.copyWith(angleDegrees: 46)));
      expect(a.toString(), contains('45'));
    });
  });
}
