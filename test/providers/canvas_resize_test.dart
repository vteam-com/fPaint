import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/layers_provider.dart';

import '../helpers/layers_provider_test_helper.dart';

void main() {
  group('Canvas Resize Feature Tests', () {
    late LayersProvider layersProvider;

    setUp(() {
      layersProvider = createInitializedLayersProvider();
    });

    group('anchorTranslate() calculation', () {
      test('Top-left anchor: no offset when expanding to larger canvas', () {
        const Size oldSize = Size(100, 100);
        const Size newSize = Size(200, 200);
        final Offset offset = anchorTranslate(CanvasResizePosition.topLeft, oldSize, newSize);

        expect(offset.dx, 0.0);
        expect(offset.dy, 0.0);
      });

      test('Center anchor: centers content when expanding', () {
        const Size oldSize = Size(100, 100);
        const Size newSize = Size(300, 300);
        final Offset offset = anchorTranslate(CanvasResizePosition.center, oldSize, newSize);

        // Centered: (300-100)/2 = 100 offset for both x and y
        expect(offset.dx, 100.0);
        expect(offset.dy, 100.0);
      });

      test('Bottom-right anchor: offset content up-left', () {
        const Size oldSize = Size(100, 100);
        const Size newSize = Size(300, 300);
        final Offset offset = anchorTranslate(CanvasResizePosition.bottomRight, oldSize, newSize);

        // Bottom-right: offset = (newSize - oldSize)
        expect(offset.dx, 200.0);
        expect(offset.dy, 200.0);
      });

      test('Top-right anchor: offset x only', () {
        const Size oldSize = Size(100, 100);
        const Size newSize = Size(300, 300);
        final Offset offset = anchorTranslate(CanvasResizePosition.topRight, oldSize, newSize);

        expect(offset.dx, 200.0);
        expect(offset.dy, 0.0);
      });

      test('Center anchor: negative offset when shrinking', () {
        const Size oldSize = Size(300, 300);
        const Size newSize = Size(100, 100);
        final Offset offset = anchorTranslate(CanvasResizePosition.center, oldSize, newSize);

        // Centered shrink: (100-300)/2 = -100 offset for both x and y
        expect(offset.dx, -100.0);
        expect(offset.dy, -100.0);
      });
    });

    group('Canvas Resize Operation', () {
      test('Resizing canvas updates size', () {
        expect(layersProvider.size, const Size(800, 600));

        layersProvider.canvasResize(
          1024,
          768,
          CanvasResizePosition.topLeft,
        );

        expect(layersProvider.size, const Size(1024, 768));
      });

      test('Resizing with same dimensions is no-op', () {
        final Size originalSize = layersProvider.size;
        final int originalLength = layersProvider.length;

        layersProvider.canvasResize(
          800,
          600,
          CanvasResizePosition.center,
        );

        expect(layersProvider.size, originalSize);
        expect(layersProvider.length, originalLength);
      });

      test('Resizing with invalid dimensions (0 or negative) is rejected', () {
        final Size originalSize = layersProvider.size;

        layersProvider.canvasResize(
          -1,
          600,
          CanvasResizePosition.center,
        );

        expect(layersProvider.size, originalSize);

        layersProvider.canvasResize(
          800,
          0,
          CanvasResizePosition.center,
        );

        expect(layersProvider.size, originalSize);
      });
    });

    group('Layer Content Offset During Resize', () {
      test('Layer positions are offset when canvas is resized', () {
        // Add a drawing action at a known position
        final LayerProvider layer = layersProvider.selectedLayer;
        final UserActionDrawing action = UserActionDrawing(
          action: ActionType.line,
          positions: <Offset>[const Offset(100, 100), const Offset(200, 200)],
          brush: MyBrush(color: Colors.black, size: 2.0),
          fillColor: Colors.transparent,
        );
        layer.appendDrawingAction(action);

        final Offset originalPos1 = action.positions[0];
        final Offset originalPos2 = action.positions[1];

        // Resize with center anchor: oldSize=800×600, newSize=1200×900
        // Center offset = ((1200-800)/2, (900-600)/2) = (200, 150)
        layersProvider.canvasResize(
          1200,
          900,
          CanvasResizePosition.center,
        );

        // Position should be offset by (200, 150)
        expect(action.positions[0], Offset(originalPos1.dx + 200, originalPos1.dy + 150));
        expect(action.positions[1], Offset(originalPos2.dx + 200, originalPos2.dy + 150));
      });

      test('Image position is offset when canvas is resized', () {
        final LayerProvider layer = layersProvider.selectedLayer;

        // Create a dummy image action
        final UserActionDrawing imageAction = UserActionDrawing(
          action: ActionType.image,
          positions: <Offset>[const Offset(50, 50), const Offset(150, 150)],
          image: null, // Would be a real image in practice
        );
        layer.appendDrawingAction(imageAction);

        final Offset originalTopLeft = imageAction.positions[0];

        // Resize with topLeft anchor: no offset
        layersProvider.canvasResize(
          1600,
          1200,
          CanvasResizePosition.topLeft,
        );

        expect(imageAction.positions[0], originalTopLeft);
      });

      test('Multiple layers are offset consistently', () {
        // Add a second layer
        layersProvider.addTop(name: 'TestLayer');
        final LayerProvider layer1 = layersProvider.get(0);
        final LayerProvider layer2 = layersProvider.get(1);

        // Add actions to both layers
        final UserActionDrawing action1 = UserActionDrawing(
          action: ActionType.pencil,
          positions: <Offset>[const Offset(100, 100), const Offset(150, 150)],
          brush: MyBrush(color: Colors.red, size: 2.0),
        );
        layer1.appendDrawingAction(action1);

        final UserActionDrawing action2 = UserActionDrawing(
          action: ActionType.pencil,
          positions: <Offset>[const Offset(200, 200), const Offset(250, 250)],
          brush: MyBrush(color: Colors.blue, size: 2.0),
        );
        layer2.appendDrawingAction(action2);

        // Resize with center anchor
        layersProvider.canvasResize(
          400,
          400,
          CanvasResizePosition.center,
        );

        // Both should be offset by the same amount (center: (400-800)/2, (400-600)/2) = (-200, -100)
        expect(action1.positions[0], const Offset(-100, 0)); // 100 - 200, 100 - 100
        expect(action2.positions[0], const Offset(0, 100)); // 200 - 200, 200 - 100
      });
    });

    group('Canvas Resize Display', () {
      test('Canvas width and height getters return new dimensions', () {
        layersProvider.canvasResize(
          1920,
          1080,
          CanvasResizePosition.center,
        );

        expect(layersProvider.width, 1920.0);
        expect(layersProvider.height, 1080.0);
      });

      test('View scale is not auto-adjusted by resize', () {
        final double originalScale = layersProvider.scale;

        layersProvider.canvasResize(
          400,
          400,
          CanvasResizePosition.center,
        );

        expect(layersProvider.scale, originalScale);
      });
    });

    group('Canvas Resize Layer Size Update', () {
      test('Layer size is updated to match canvas size', () {
        for (int i = 0; i < layersProvider.length; i++) {
          expect(layersProvider.get(i).size, const Size(800, 600));
        }

        layersProvider.canvasResize(
          1024,
          768,
          CanvasResizePosition.topLeft,
        );

        for (int i = 0; i < layersProvider.length; i++) {
          expect(
            layersProvider.get(i).size,
            const Size(1024, 768),
            reason: 'Layer ${layersProvider.get(i).name} should have updated size',
          );
        }
      });
    });

    group('Anchor Position Behavior', () {
      test('Top-left anchor preserves top-left position', () {
        layersProvider.canvasResize(
          1200,
          900,
          CanvasResizePosition.topLeft,
        );

        expect(layersProvider.size, const Size(1200, 900));
        expect(layersProvider.get(0).size, const Size(1200, 900));
      });

      test('All 9 anchor positions are handled without error', () {
        final List<CanvasResizePosition> anchors = <CanvasResizePosition>[
          CanvasResizePosition.topLeft,
          CanvasResizePosition.top,
          CanvasResizePosition.topRight,
          CanvasResizePosition.left,
          CanvasResizePosition.center,
          CanvasResizePosition.right,
          CanvasResizePosition.bottomLeft,
          CanvasResizePosition.bottom,
          CanvasResizePosition.bottomRight,
        ];

        for (final CanvasResizePosition anchor in anchors) {
          layersProvider.canvasResize(
            600,
            450,
            anchor,
          );
          expect(layersProvider.size, const Size(600, 450));

          // Reset
          layersProvider.canvasResize(
            800,
            600,
            anchor,
          );
        }
      });
    });
  });
}
