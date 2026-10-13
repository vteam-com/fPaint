import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/quick_menu_geometry.dart';

const Offset _center = Offset(400, 300);
const int _slotCount = 8;
const double _farDistance = AppLayout.quickMenuRingRadius;
const double _positionTolerance = 0.001;
const Size _viewport = Size(800, 600);
const double _reach = AppLayout.quickMenuReach;

void main() {
  group('quickMenuSlotCenter', () {
    test('places the first slot straight above the centre', () {
      final Offset first = quickMenuSlotCenter(center: _center, index: 0, count: _slotCount);

      expect(first.dx, closeTo(_center.dx, _positionTolerance));
      expect(first.dy, closeTo(_center.dy - AppLayout.quickMenuRingRadius, _positionTolerance));
    });

    test('runs clockwise: a quarter of the ring lands to the right', () {
      final Offset quarter = quickMenuSlotCenter(center: _center, index: _slotCount ~/ 4, count: _slotCount);

      expect(quarter.dx, closeTo(_center.dx + AppLayout.quickMenuRingRadius, _positionTolerance));
      expect(quarter.dy, closeTo(_center.dy, _positionTolerance));
    });

    test('honours a custom radius', () {
      final Offset first = quickMenuSlotCenter(
        center: _center,
        index: 0,
        count: _slotCount,
        radius: AppLayout.quickMenuColorRadius,
      );

      expect((first - _center).distance, closeTo(AppLayout.quickMenuColorRadius, _positionTolerance));
    });
  });

  group('quickMenuSlotAt', () {
    test('picks nothing inside the flick radius', () {
      expect(quickMenuSlotAt(center: _center, point: _center, count: _slotCount), isNull);
      expect(
        quickMenuSlotAt(
          center: _center,
          point: _center + const Offset(0, -quickMenuFlickRadius / 2),
          count: _slotCount,
        ),
        isNull,
      );
    });

    test('maps each direction to the slot drawn there', () {
      for (int index = 0; index < _slotCount; index++) {
        final Offset slotCenter = quickMenuSlotCenter(
          center: _center,
          index: index,
          count: _slotCount,
          radius: _farDistance,
        );
        expect(quickMenuSlotAt(center: _center, point: slotCenter, count: _slotCount), index);
      }
    });

    test('only the direction matters past the flick radius', () {
      final Offset farAbove = _center + const Offset(0, -_farDistance * 3);

      expect(quickMenuSlotAt(center: _center, point: farAbove, count: _slotCount), 0);
    });

    test('a point just left of straight up still belongs to the first slot', () {
      final Offset slightlyLeft = _center + const Offset(-1, -_farDistance);

      expect(quickMenuSlotAt(center: _center, point: slightlyLeft, count: _slotCount), 0);
    });

    test('returns null for an empty ring', () {
      expect(quickMenuSlotAt(center: _center, point: _center + const Offset(0, -_farDistance), count: 0), isNull);
    });
  });

  group('quickMenuSubmenuSlotCenter', () {
    test('sits on the outer ring', () {
      final Offset slot = quickMenuSubmenuSlotCenter(
        center: _center,
        parentIndex: 3,
        parentCount: _slotCount,
        index: 0,
        count: 2,
      );

      expect((slot - _center).distance, closeTo(AppLayout.quickMenuOuterRingRadius, _positionTolerance));
    });

    test('a single item lines up with its parent slot', () {
      final Offset parent = quickMenuSlotCenter(center: _center, index: 2, count: _slotCount);
      final Offset item = quickMenuSubmenuSlotCenter(
        center: _center,
        parentIndex: 2,
        parentCount: _slotCount,
        index: 0,
        count: 1,
      );
      final Offset parentDirection = (parent - _center) / AppLayout.quickMenuRingRadius;
      final Offset itemDirection = (item - _center) / AppLayout.quickMenuOuterRingRadius;

      expect(itemDirection.dx, closeTo(parentDirection.dx, _positionTolerance));
      expect(itemDirection.dy, closeTo(parentDirection.dy, _positionTolerance));
    });

    test('neighbouring items are the submenu spacing apart along the arc', () {
      Offset item(int index) => quickMenuSubmenuSlotCenter(
        center: _center,
        parentIndex: 0,
        parentCount: _slotCount,
        index: index,
        count: 5,
      );

      // Chord length for a small arc is just under the arc length.
      expect((item(1) - item(0)).distance, closeTo(AppLayout.quickMenuSubmenuSpacing, 1));
    });
  });

  group('clampQuickMenuAnchor', () {
    test('leaves an anchor with room around it untouched', () {
      expect(clampQuickMenuAnchor(_center, _viewport), _center);
    });

    test('pulls an anchor near the corner in so even an expanded sub-ring is visible', () {
      final Offset clamped = clampQuickMenuAnchor(Offset.zero, _viewport);

      expect(clamped, const Offset(_reach, _reach));
    });

    test('centres the menu when the viewport is smaller than the disc', () {
      const Size tiny = Size(100, 100);

      expect(clampQuickMenuAnchor(Offset.zero, tiny), const Offset(50, 50));
    });
  });
}
