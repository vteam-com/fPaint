import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/canvas_resize.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  group('CanvasResizePosition', () {
    test('anchorTranslate should handle same source and destination sizes', () {
      final Offset result = anchorTranslate(
        CanvasResizePosition.bottomRight,
        const Size(100, 100),
        const Size(100, 100),
      );
      expect(result, equals(Offset.zero));
    });

    test('anchorTranslate should return zero offset for topLeft position', () {
      final Offset result = anchorTranslate(
        CanvasResizePosition.topLeft,
        const Size(100, 100),
        const Size(200, 200),
      );
      expect(result, equals(Offset.zero));
    });

    test('anchorTranslate should return correct offset for center position', () {
      final Offset result = anchorTranslate(
        CanvasResizePosition.center,
        const Size(100, 100),
        const Size(200, 200),
      );
      // Center anchor should shift content to maintain visual centering
      // When enlarging 100x100 to 200x200, content should move by (50, 50)
      // to stay centered in the new canvas
      expect(result, equals(const Offset(50, 50)));
    });

    test('center anchor maintains visual centering when resizing', () {
      // Test enlarging: content at old center should move to new center
      final Offset enlargeOffset = anchorTranslate(
        CanvasResizePosition.center,
        const Size(100, 100),
        const Size(300, 200),
      );
      expect(enlargeOffset, equals(const Offset(100, 50)));

      // Verify: content originally at (50, 50) moves to (150, 100) - the new center
      const Offset oldCenter = Offset(50, 50);
      final Offset newPosition = oldCenter + enlargeOffset;
      const Offset expectedNewCenter = Offset(150, 100); // 300/2, 200/2
      expect(newPosition, equals(expectedNewCenter));

      // Test reducing: content should move to stay centered
      final Offset reduceOffset = anchorTranslate(
        CanvasResizePosition.center,
        const Size(200, 200),
        const Size(100, 100),
      );
      expect(reduceOffset, equals(const Offset(-50, -50)));
    });

    test('anchorTranslate should handle negative size differences', () {
      final Offset result = anchorTranslate(
        CanvasResizePosition.right,
        const Size(200, 200),
        const Size(100, 100),
      );
      // When reducing canvas with right anchor, content should move left to stay right-aligned
      // Size change: -100 width, -100 height
      // Right factors: (1, 0.5)
      // dx = -100 * 1 = -100, dy = -100 * 0.5 = -50
      expect(result, equals(const Offset(-100, -50)));
    });

    test('anchorTranslate should calculate correct offset for all positions', () {
      const Size sourceSize = Size(100, 100);
      const Size destSize = Size(200, 200);
      // Size change: +100 width, +100 height (enlarging)
      final double dx = destSize.width - sourceSize.width; // 100
      final double dy = destSize.height - sourceSize.height; // 100

      expect(
        anchorTranslate(
          CanvasResizePosition.top,
          sourceSize,
          destSize,
        ),
        equals(Offset(dx / 2, 0)), // (50, 0)
      );
      expect(
        anchorTranslate(
          CanvasResizePosition.topRight,
          sourceSize,
          destSize,
        ),
        equals(Offset(dx, 0)), // (100, 0)
      );
      expect(
        anchorTranslate(
          CanvasResizePosition.right,
          sourceSize,
          destSize,
        ),
        equals(Offset(dx, dy / 2)), // (100, 50)
      );
      expect(
        anchorTranslate(
          CanvasResizePosition.left,
          sourceSize,
          destSize,
        ),
        equals(Offset(0, dy / 2)), // (0, 50)
      );
      expect(
        anchorTranslate(
          CanvasResizePosition.bottomLeft,
          sourceSize,
          destSize,
        ),
        equals(Offset(0, dy)), // (0, 100)
      );
      expect(
        anchorTranslate(
          CanvasResizePosition.bottom,
          sourceSize,
          destSize,
        ),
        equals(Offset(dx / 2, dy)), // (50, 100)
      );
      expect(
        anchorTranslate(
          CanvasResizePosition.bottomRight,
          sourceSize,
          destSize,
        ),
        equals(Offset(dx, dy)), // (100, 100)
      );
    });

    test('anchor behavior verification for topRight and bottomLeft', () {
      // TopRight anchor: content should stay aligned to top-right corner
      // Content 10px from right edge (90, 10) in 100x100 canvas
      // Should move to (190, 10) in 200x200 canvas to stay 10px from right edge
      // Required offset: (100, 0)
      final Offset topRightOffset = anchorTranslate(
        CanvasResizePosition.topRight,
        const Size(100, 100),
        const Size(200, 200),
      );
      expect(topRightOffset, equals(const Offset(100, 0)));

      // Verify: content at (90, 10) moves to (190, 10)
      const Offset contentNearTopRight = Offset(90, 10);
      final Offset newContentPosition = contentNearTopRight + topRightOffset;
      expect(newContentPosition, equals(const Offset(190, 10)));

      // BottomLeft anchor: content should stay aligned to bottom-left corner
      final Offset bottomLeftOffset = anchorTranslate(
        CanvasResizePosition.bottomLeft,
        const Size(100, 100),
        const Size(200, 200),
      );
      expect(bottomLeftOffset, equals(const Offset(0, 100)));

      // Verify: content at (10, 90) moves to (10, 190) - same distance from bottom
      const Offset contentNearBottomLeft = Offset(10, 90);
      final Offset newBottomLeftPosition = contentNearBottomLeft + bottomLeftOffset;
      expect(newBottomLeftPosition, equals(const Offset(10, 190)));
    });
  });
}
