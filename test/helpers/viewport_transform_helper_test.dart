import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/viewport_transform_helper.dart';

/// Matches an [Offset] within floating-point tolerance.
void expectOffset(Offset actual, Offset expected, {double tolerance = 1e-9}) {
  expect(actual.dx, closeTo(expected.dx, tolerance));
  expect(actual.dy, closeTo(expected.dy, tolerance));
}

void main() {
  group('ViewportTransform at rotation 0', () {
    test('toScreen matches the legacy offset + point * scale mapping', () {
      const Offset offset = Offset(37, -12);
      const double scale = 2.5;
      final ViewportTransform viewport = ViewportTransform(
        offset: offset,
        scale: scale,
        rotation: 0,
      );

      for (final Offset point in <Offset>[
        Offset.zero,
        const Offset(1, 1),
        const Offset(-40.5, 300.25),
        const Offset(1920, 1080),
      ]) {
        expectOffset(viewport.toScreen(point), (point * scale) + offset, tolerance: 1e-6);
      }
    });

    test('toCanvas matches the legacy (point - offset) / scale mapping', () {
      const Offset offset = Offset(-88, 64);
      const double scale = 0.35;
      final ViewportTransform viewport = ViewportTransform(
        offset: offset,
        scale: scale,
        rotation: 0,
      );

      for (final Offset point in <Offset>[
        Offset.zero,
        const Offset(12, 900),
        const Offset(-500.5, -0.25),
      ]) {
        expectOffset(viewport.toCanvas(point), (point - offset) / scale, tolerance: 1e-6);
      }
    });

    test('deltaToCanvas matches the legacy delta / scale mapping', () {
      final ViewportTransform viewport = ViewportTransform(
        offset: const Offset(10, 20),
        scale: 4,
        rotation: 0,
      );

      expectOffset(viewport.deltaToCanvas(const Offset(8, -12)), const Offset(2, -3));
    });

    test('visibleCanvasBounds matches the legacy divide-by-scale rect', () {
      const Offset offset = Offset(-120, -80);
      const double scale = 2;
      final ViewportTransform viewport = ViewportTransform(
        offset: offset,
        scale: scale,
        rotation: 0,
      );
      const Rect screenViewport = Rect.fromLTWH(0, 0, 800, 600);

      final Rect bounds = viewport.visibleCanvasBounds(screenViewport);

      expect(bounds.left, closeTo(-offset.dx / scale, 1e-6));
      expect(bounds.top, closeTo(-offset.dy / scale, 1e-6));
      expect(bounds.width, closeTo(screenViewport.width / scale, 1e-6));
      expect(bounds.height, closeTo(screenViewport.height / scale, 1e-6));
    });
  });

  group('ViewportTransform with rotation', () {
    test('round-trips a point through screen space at an arbitrary angle', () {
      final ViewportTransform viewport = ViewportTransform(
        offset: const Offset(140, -35),
        scale: 1.75,
        rotation: 0.4,
      );

      const Offset canvasPoint = Offset(321.5, -47.25);
      expectOffset(
        viewport.toCanvas(viewport.toScreen(canvasPoint)),
        canvasPoint,
        tolerance: 1e-6,
      );
    });

    test('rotates a screen delta into canvas space rather than only scaling it', () {
      // A quarter turn: a purely horizontal screen drag becomes a purely
      // vertical canvas move. Dividing by the zoom alone would leave it
      // horizontal, which is the diagonal handle-drift bug.
      final ViewportTransform viewport = ViewportTransform(
        offset: Offset.zero,
        scale: 1,
        rotation: math.pi / 2,
      );

      expectOffset(viewport.deltaToCanvas(const Offset(10, 0)), const Offset(0, -10), tolerance: 1e-9);
    });

    test('a rotated viewport sees a larger axis-aligned canvas region', () {
      const Rect screenViewport = Rect.fromLTWH(0, 0, 800, 600);
      final ViewportTransform upright = ViewportTransform(
        offset: Offset.zero,
        scale: 1,
        rotation: 0,
      );
      final ViewportTransform rotated = upright.copyWith(rotation: math.pi / 4);

      final Rect uprightBounds = upright.visibleCanvasBounds(screenViewport);
      final Rect rotatedBounds = rotated.visibleCanvasBounds(screenViewport);

      // The visible region is a rotated quad, so its bounding box must grow —
      // culling with the unrotated rect would clip visible content away.
      expect(rotatedBounds.width, greaterThan(uprightBounds.width));
      expect(rotatedBounds.height, greaterThan(uprightBounds.height));
    });

    test('isRotated reflects the rotation field', () {
      expect(ViewportTransform.identity().isRotated, isFalse);
      expect(ViewportTransform.identity().copyWith(rotation: 0.1).isRotated, isTrue);
    });

    test('equal field values compare equal so painters can skip repaints', () {
      final ViewportTransform a = ViewportTransform(
        offset: const Offset(3, 4),
        scale: 2,
        rotation: 0.5,
      );
      final ViewportTransform b = ViewportTransform(
        offset: const Offset(3, 4),
        scale: 2,
        rotation: 0.5,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(a.copyWith(rotation: 0.6))));
    });
  });

  group('normalizeRadians', () {
    test('maps equivalent angles into (-pi, pi]', () {
      const double fullTurn = 2 * math.pi;
      expect(normalizeRadians(0), closeTo(0, 1e-9));
      expect(normalizeRadians(fullTurn), closeTo(0, 1e-9));
      expect(normalizeRadians(-fullTurn), closeTo(0, 1e-9));
      expect(normalizeRadians(math.pi), closeTo(math.pi, 1e-9));
      expect(normalizeRadians(math.pi + fullTurn), closeTo(math.pi, 1e-9));
      expect(normalizeRadians(3 * math.pi / 2), closeTo(-math.pi / 2, 1e-9));
    });
  });

  group('snapAngleToInterval', () {
    double snap(double degrees) => radiansToDegrees(
      snapAngleToInterval(
        degreesToRadians(degrees),
        snapIntervalDegrees: 45,
        snapToleranceDegrees: 4,
      ),
    );

    test('holds a cardinal angle inside the snap band', () {
      expect(snap(2), closeTo(0, 1e-6));
      expect(snap(-3), closeTo(0, 1e-6));
      expect(snap(43), closeTo(45, 1e-6));
      expect(snap(92), closeTo(90, 1e-6));
      expect(snap(-88), closeTo(-90, 1e-6));
    });

    test('leaves an angle outside the band free', () {
      expect(snap(20), closeTo(20, 1e-6));
      expect(snap(37), closeTo(37, 1e-6));
      expect(snap(-60), closeTo(-60, 1e-6));
    });

    test('snapping to 0 is reachable from either side', () {
      expect(snap(4), closeTo(0, 1e-6));
      expect(snap(-4), closeTo(0, 1e-6));
      expect(snap(5), closeTo(5, 1e-6));
    });
  });

  group('degree conversion', () {
    test('round-trips degrees through radians', () {
      for (final double degrees in <double>[0, 45, 90, -137.5, 180]) {
        expect(radiansToDegrees(degreesToRadians(degrees)), closeTo(degrees, 1e-6));
      }
    });
  });
}
