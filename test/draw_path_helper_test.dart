import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('expandPathInDirectionWithOffset expands path to the left', () {
    final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
    const Offset offset = Offset(-20, 0);
    final Path result = expandPathInDirectionWithOffset(path, offset, NineGridHandle.left);

    final Rect resultBounds = result.getBounds();
    expect(resultBounds.left, closeTo(-20, 0.001));
    expect(resultBounds.width, closeTo(120, 0.001));
  });

  test('expandPathInDirectionWithOffset expands path to the right', () {
    final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
    const Offset offset = Offset(20, 0);
    final Path result = expandPathInDirectionWithOffset(path, offset, NineGridHandle.right);

    final Rect resultBounds = result.getBounds();
    expect(resultBounds.right, closeTo(120, 0.001));
    expect(resultBounds.width, closeTo(120, 0.001));
  });

  test('expandPathInDirectionWithOffset expands path to the top', () {
    final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
    const Offset offset = Offset(0, -20);
    final Path result = expandPathInDirectionWithOffset(path, offset, NineGridHandle.top);

    final Rect resultBounds = result.getBounds();
    expect(resultBounds.top, closeTo(-20, 0.001));
    expect(resultBounds.height, closeTo(120, 0.001));
  });

  test('expandPathInDirectionWithOffset expands path to the bottom', () {
    final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
    const Offset offset = Offset(0, 20);
    final Path result = expandPathInDirectionWithOffset(path, offset, NineGridHandle.bottom);

    final Rect resultBounds = result.getBounds();
    expect(resultBounds.bottom, closeTo(120, 0.001));
    expect(resultBounds.height, closeTo(120, 0.001));
  });

  test('expandPathInDirectionWithOffset expands path to the top left', () {
    final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
    const Offset offset = Offset(-20, -20);
    final Path result = expandPathInDirectionWithOffset(path, offset, NineGridHandle.topLeft);

    final Rect resultBounds = result.getBounds();
    expect(resultBounds.left, closeTo(-20, 0.001));
    expect(resultBounds.top, closeTo(-20, 0.001));
    expect(resultBounds.width, closeTo(120, 0.001));
    expect(resultBounds.height, closeTo(120, 0.001));
  });

  test('expandPathInDirectionWithOffset expands path to the top right', () {
    final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
    const Offset offset = Offset(20, -20);
    final Path result = expandPathInDirectionWithOffset(
      path,
      offset,
      NineGridHandle.topRight,
    );

    final Rect resultBounds = result.getBounds();
    expect(resultBounds.right, closeTo(120, 0.001));
    expect(resultBounds.top, closeTo(-20, 0.001));
    expect(resultBounds.width, closeTo(120, 0.001));
    expect(resultBounds.height, closeTo(120, 0.001));
  });

  test('expandPathInDirectionWithOffset expands path to the bottom left', () {
    final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
    const Offset offset = Offset(-20, 20);
    final Path result = expandPathInDirectionWithOffset(
      path,
      offset,
      NineGridHandle.bottomLeft,
    );

    final Rect resultBounds = result.getBounds();
    expect(resultBounds.left, closeTo(-20, 0.001));
    expect(resultBounds.bottom, closeTo(120, 0.001));
    expect(resultBounds.width, closeTo(120, 0.001));
    expect(resultBounds.height, closeTo(120, 0.001));
  });

  test('expandPathInDirectionWithOffset expands path to the bottom right', () {
    final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
    const Offset offset = Offset(20, 20);
    final Path result = expandPathInDirectionWithOffset(
      path,
      offset,
      NineGridHandle.bottomRight,
    );

    final Rect resultBounds = result.getBounds();
    expect(resultBounds.right, closeTo(120, 0.001));
    expect(resultBounds.bottom, closeTo(120, 0.001));
    expect(resultBounds.width, closeTo(120, 0.001));
    expect(resultBounds.height, closeTo(120, 0.001));
  });

  test('expandPathInDirectionWithOffset returns original path for zero-width horizontal resize', () {
    final Path path = Path()
      ..moveTo(10, 10)
      ..lineTo(10, 110);
    final Rect before = path.getBounds();

    final Path result = expandPathInDirectionWithOffset(
      path,
      const Offset(20, 0),
      NineGridHandle.right,
    );

    final Rect after = result.getBounds();
    expect(after.left, closeTo(before.left, 0.001));
    expect(after.top, closeTo(before.top, 0.001));
    expect(after.width, closeTo(before.width, 0.001));
    expect(after.height, closeTo(before.height, 0.001));
  });

  test('expandPathInDirectionWithOffset returns original path for zero-height vertical resize', () {
    final Path path = Path()
      ..moveTo(10, 10)
      ..lineTo(110, 10);
    final Rect before = path.getBounds();

    final Path result = expandPathInDirectionWithOffset(
      path,
      const Offset(0, 20),
      NineGridHandle.bottom,
    );

    final Rect after = result.getBounds();
    expect(after.left, closeTo(before.left, 0.001));
    expect(after.top, closeTo(before.top, 0.001));
    expect(after.width, closeTo(before.width, 0.001));
    expect(after.height, closeTo(before.height, 0.001));
  });

  group('rotatePathAroundCenter', () {
    test('rotating by 0 preserves the path bounds', () {
      final Path path = Path()..addRect(const Rect.fromLTWH(10, 10, 100, 100));
      final Path result = rotatePathAroundCenter(path, 0);

      final Rect resultBounds = result.getBounds();
      expect(resultBounds.left, closeTo(10, 0.001));
      expect(resultBounds.top, closeTo(10, 0.001));
      expect(resultBounds.width, closeTo(100, 0.001));
      expect(resultBounds.height, closeTo(100, 0.001));
    });

    test('rotating 90 degrees preserves center and swaps dimensions for non-square', () {
      final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 200, 100));
      final Rect before = path.getBounds();
      final Path result = rotatePathAroundCenter(path, pi / 2);
      final Rect after = result.getBounds();

      // Center should remain the same
      expect(after.center.dx, closeTo(before.center.dx, 0.5));
      expect(after.center.dy, closeTo(before.center.dy, 0.5));

      // Width and height swap for a 90° rotation
      expect(after.width, closeTo(before.height, 0.5));
      expect(after.height, closeTo(before.width, 0.5));
    });

    test('rotating 360 degrees restores original bounds', () {
      final Path path = Path()..addRect(const Rect.fromLTWH(50, 50, 80, 60));
      final Rect before = path.getBounds();
      final Path result = rotatePathAroundCenter(path, 2 * pi);
      final Rect after = result.getBounds();

      expect(after.left, closeTo(before.left, 0.5));
      expect(after.top, closeTo(before.top, 0.5));
      expect(after.width, closeTo(before.width, 0.5));
      expect(after.height, closeTo(before.height, 0.5));
    });

    test('rotating 180 degrees preserves center', () {
      final Path path = Path()..addRect(const Rect.fromLTWH(20, 30, 100, 100));
      final Rect before = path.getBounds();
      final Path result = rotatePathAroundCenter(path, pi);
      final Rect after = result.getBounds();

      expect(after.center.dx, closeTo(before.center.dx, 0.5));
      expect(after.center.dy, closeTo(before.center.dy, 0.5));
      expect(after.width, closeTo(before.width, 0.5));
      expect(after.height, closeTo(before.height, 0.5));
    });
  });

  group('boundsOfPoints', () {
    test('returns null for no points', () {
      expect(boundsOfPoints(<Offset>[]), isNull);
    });

    test('returns the box enclosing every point', () {
      expect(
        boundsOfPoints(const <Offset>[Offset(5, -2), Offset(-3, 7), Offset(1, 1)]),
        const Rect.fromLTRB(-3, -2, 5, 7),
      );
    });
  });

  group('inflateClampToCanvas', () {
    test('inflates, snaps outward and clamps to the canvas', () {
      expect(
        inflateClampToCanvas(const Rect.fromLTRB(2.5, 3.5, 8.2, 9.7), 4, const Size(10, 12)),
        const Rect.fromLTRB(0, 0, 10, 12),
      );
      expect(
        inflateClampToCanvas(const Rect.fromLTRB(4.5, 4.5, 5.2, 5.2), 1, const Size(10, 10)),
        const Rect.fromLTRB(3, 3, 7, 7),
      );
    });

    test('returns null when the clamped rect is empty', () {
      expect(inflateClampToCanvas(const Rect.fromLTRB(20, 20, 30, 30), 1, const Size(10, 10)), isNull);
    });
  });
}
