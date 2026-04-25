import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';

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
}
