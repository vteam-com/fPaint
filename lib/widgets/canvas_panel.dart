import 'package:flutter/widgets.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/canvas_panel_painter.dart';

/// A widget that displays the canvas panel.
class CanvasPanel extends StatelessWidget {
  const CanvasPanel({super.key});

  @override
  Widget build(final BuildContext context) {
    final LayersProvider layers = LayersProvider.of(context);
    // RepaintBoundary isolates the expensive multi-layer canvas composite into
    // its own raster layer. Without it, any repaint elsewhere in the main-view
    // Stack (brush-size hover preview, marching-ants animation, transform mesh,
    // eyedropper) drags the full canvas re-raster along with it. The painter's
    // stable `canvasPainterRepaint` listenable means the layer only re-rasters
    // when pixels actually change — not on every pan/hover rebuild.
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: CanvasPanelPainter(
          layers.list,
          includeTransparentBackground: true,
          repaint: layers.canvasPainterRepaint,
        ),
      ),
    );
  }
}
