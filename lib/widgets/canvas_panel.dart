import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/viewport_transform_helper.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/canvas_panel_painter.dart';

/// A widget that displays the canvas panel.
class CanvasPanel extends StatelessWidget {
  const CanvasPanel({
    super.key,
    required this.viewport,
    required this.visibleCanvasBounds,
  });

  /// The canvas-to-screen viewport transform (pan, zoom and rotation).
  final ViewportTransform viewport;

  /// The viewport expressed in document coordinates.
  final Rect visibleCanvasBounds;

  @override
  Widget build(BuildContext context) {
    final LayersProvider layers = LayersProvider.of(context);
    // On-screen resolution per canvas pixel (zoom × devicePixelRatio): the live
    // painter serves layers from a display-resolution cache sized for this rather
    // than sampling the full 62 MP layer textures every frame.
    final double displayScale = layers.scale * MediaQuery.devicePixelRatioOf(context);
    // This render object stays viewport-sized; pan and zoom are applied inside
    // the painter. Keeping the document transform out of the widget tree stops
    // Impeller's raster cache from allocating a zoomed full-document texture.
    // MainView provides the viewport-sized repaint boundary, while this
    // painter's stable listenable limits redraws to actual pixel changes.
    return CustomPaint(
      size: Size.infinite,
      painter: CanvasPanelPainter(
        layers.list,
        viewport: viewport,
        includeTransparentBackground: true,
        displayScale: displayScale,
        visibleCanvasBounds: visibleCanvasBounds,
        onNeedsDisplayCache: layers.scheduleDisplayCacheRebuild,
        isInteractiveViewportChange: () => layers.isInteractiveViewportChange,
        repaint: layers.canvasPainterRepaint,
      ),
    );
  }
}
