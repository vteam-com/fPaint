import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';

void main() {
  test('expandPathInDirectionWithOffset expands path to the left', () {
    final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
    final Offset offset = const Offset(-20, 0);
    final Path result =
        expandPathInDirectionWithOffset(path, offset, NineGridHandle.left);

    final Rect resultBounds = result.getBounds();
    expect(resultBounds.left, closeTo(-20, 0.001));
    expect(resultBounds.width, closeTo(120, 0.001));
  });

  test('expandPathInDirectionWithOffset expands path to the right', () {
    final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
    final Offset offset = const Offset(20, 0);
    final Path result =
        expandPathInDirectionWithOffset(path, offset, NineGridHandle.right);

    final Rect resultBounds = result.getBounds();
    expect(resultBounds.right, closeTo(120, 0.001));
    expect(resultBounds.width, closeTo(120, 0.001));
  });

  test('expandPathInDirectionWithOffset expands path to the top', () {
    final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
    final Offset offset = const Offset(0, -20);
    final Path result =
        expandPathInDirectionWithOffset(path, offset, NineGridHandle.top);

    final Rect resultBounds = result.getBounds();
    expect(resultBounds.top, closeTo(-20, 0.001));
    expect(resultBounds.height, closeTo(120, 0.001));
  });

  test('expandPathInDirectionWithOffset expands path to the bottom', () {
    final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
    final Offset offset = const Offset(0, 20);
    final Path result =
        expandPathInDirectionWithOffset(path, offset, NineGridHandle.bottom);

    final Rect resultBounds = result.getBounds();
    expect(resultBounds.bottom, closeTo(120, 0.001));
    expect(resultBounds.height, closeTo(120, 0.001));
  });

  test('expandPathInDirectionWithOffset expands path to the top left', () {
    final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
    final Offset offset = const Offset(-20, -20);
    final Path result =
        expandPathInDirectionWithOffset(path, offset, NineGridHandle.topLeft);

    final Rect resultBounds = result.getBounds();
    expect(resultBounds.left, closeTo(-20, 0.001));
    expect(resultBounds.top, closeTo(-20, 0.001));
    expect(resultBounds.width, closeTo(120, 0.001));
    expect(resultBounds.height, closeTo(120, 0.001));
  });

  test('expandPathInDirectionWithOffset expands path to the top right', () {
    final Path path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
    final Offset offset = const Offset(20, -20);
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
    final Offset offset = const Offset(-20, 20);
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
    final Offset offset = const Offset(20, 20);
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
}
