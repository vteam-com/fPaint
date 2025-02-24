import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/canvas_resize.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  group('CanvasResizePosition', () {
    test('anchorTranslate should handle same source and destination sizes', () {
      final Offset result = CanvasResizePosition.anchorTranslate(
        CanvasResizePosition.bottomRight,
        const Size(100, 100),
        const Size(100, 100),
      );
      expect(result, equals(Offset.zero));
    });

    test('anchorTranslate should return zero offset for topLeft position', () {
      final Offset result = CanvasResizePosition.anchorTranslate(
        CanvasResizePosition.topLeft,
        const Size(100, 100),
        const Size(200, 200),
      );
      expect(result, equals(Offset.zero));
    });

    test('anchorTranslate should return correct offset for center position',
        () {
      final Offset result = CanvasResizePosition.anchorTranslate(
        CanvasResizePosition.center,
        const Size(100, 100),
        const Size(200, 200),
      );
      expect(result, equals(const Offset(50, 50)));
    });

    test('anchorTranslate should handle negative size differences', () {
      final Offset result = CanvasResizePosition.anchorTranslate(
        CanvasResizePosition.right,
        const Size(200, 200),
        const Size(100, 100),
      );
      expect(result, equals(const Offset(-100, -50)));
    });

    test('anchorTranslate should calculate correct offset for all positions',
        () {
      const Size sourceSize = Size(100, 100);
      const Size destSize = Size(200, 200);
      final double dx = destSize.width - sourceSize.width;
      final double dy = destSize.height - sourceSize.height;

      expect(
        CanvasResizePosition.anchorTranslate(
          CanvasResizePosition.top,
          sourceSize,
          destSize,
        ),
        equals(Offset(dx / 2, 0)),
      );
      expect(
        CanvasResizePosition.anchorTranslate(
          CanvasResizePosition.topRight,
          sourceSize,
          destSize,
        ),
        equals(Offset(dx, 0)),
      );
      expect(
        CanvasResizePosition.anchorTranslate(
          CanvasResizePosition.right,
          sourceSize,
          destSize,
        ),
        equals(Offset(dx, dy / 2)),
      );
      expect(
        CanvasResizePosition.anchorTranslate(
          CanvasResizePosition.left,
          sourceSize,
          destSize,
        ),
        equals(Offset(0, dy / 2)),
      );
      expect(
        CanvasResizePosition.anchorTranslate(
          CanvasResizePosition.bottomLeft,
          sourceSize,
          destSize,
        ),
        equals(Offset(0, dy)),
      );
      expect(
        CanvasResizePosition.anchorTranslate(
          CanvasResizePosition.bottom,
          sourceSize,
          destSize,
        ),
        equals(Offset(dx / 2, dy)),
      );
      expect(
        CanvasResizePosition.anchorTranslate(
          CanvasResizePosition.bottomRight,
          sourceSize,
          destSize,
        ),
        equals(Offset(dx, dy)),
      );
    });
  });
}
