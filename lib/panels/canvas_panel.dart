import 'package:flutter/material.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/transparent_background.dart';

/// A widget that displays the canvas panel.
class CanvasPanel extends StatelessWidget {
  const CanvasPanel({super.key});

  @override
  Widget build(final BuildContext context) {
    final LayersProvider layers = LayersProvider.of(context);
    return CustomPaint(
      size: Size.infinite,
      painter: CanvasPanelPainter(layers, includeTransparentBackground: true),
    );
  }
}

/// A custom painter that paints the canvas panel.
class CanvasPanelPainter extends CustomPainter {
  CanvasPanelPainter(
    this._layers, {
    this.includeTransparentBackground = false,
  });

  /// The layers to paint.
  final LayersProvider _layers;

  /// Whether to include the transparent background.
  final bool includeTransparentBackground;

  @override
  void paint(final Canvas canvas, final Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    if (includeTransparentBackground) {
      drawTransaparentBackgroundOffsetAndSize(
        canvas: canvas,
        size: _layers.size,
      );
    }

    for (final LayerProvider layer in _layers.list.reversed) {
      if (layer.isVisible) {
        layer.renderLayer(canvas);
      }
    }
  }

  @override
  bool shouldRepaint(final CanvasPanelPainter oldDelegate) => true;
}
