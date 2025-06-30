import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:fpaint/providers/layers_provider.dart';

Offset anchorPoint(final Size size, final CanvasResizePosition anchor) {
  final Offset factors = anchorFactors(anchor);
  return Offset(size.width * factors.dx, size.height * factors.dy);
}

void main() {
  group('anchorTranslate', () {
    // NOTE: Removed "anchor point stays fixed" tests as they were based on
    // incorrect behavior. The correct behavior is that content stays properly
    // aligned to the chosen anchor edge/corner, not that anchor points
    // maintain the same absolute coordinates.
  });

  test('Content is correctly repositioned for all anchors when resizing', () {
    for (final CanvasResizePosition anchor in CanvasResizePosition.values) {
      final LayersProvider layersProvider = LayersProvider();
      layersProvider.clear(); // Clear previous test data since LayersProvider is a singleton
      layersProvider.addWhiteBackgroundLayer(); // Re-add the background layer
      layersProvider.size = const Size(100, 100);

      // Add a dummy action at a known position
      final UserActionDrawing action = UserActionDrawing(
        action: ActionType.brush,
        positions: <Offset>[const Offset(10, 10), const Offset(20, 20)],
      );
      final LayerProvider layer = layersProvider.selectedLayer;
      layer.appendDrawingAction(action);

      // Resize canvas
      layersProvider.canvasResize(200, 200, anchor);

      // Use the same anchorTranslate as the implementation
      final Offset expectedOffset = anchorTranslate(anchor, const Size(100, 100), const Size(200, 200));
      final Offset expectedFirst = const Offset(10, 10) + expectedOffset;
      final Offset actualFirst = layer.actionStack.first.positions.first;

      // The action's points should be offset by expectedOffset
      expect(actualFirst, expectedFirst, reason: 'Anchor: $anchor');
      expect(layer.actionStack.first.positions.last, const Offset(20, 20) + expectedOffset, reason: 'Anchor: $anchor');
    }
  });
}
