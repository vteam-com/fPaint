import 'package:flutter/material.dart';
import 'package:fpaint/providers/layer_provider.dart';
import 'package:fpaint/widgets/transparent_background.dart';

/// A custom painter that paints the canvas panel.
class CanvasPanelPainter extends CustomPainter {
  CanvasPanelPainter(
    this._layers,
    this._size, {
    this.includeTransparentBackground = false,
  });

  /// The layers to paint.
  final List<LayerProvider> _layers;

  /// The target canvas size.
  final Size _size;

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
        size: _size,
      );
    }

    for (final LayerProvider layer in _layers.reversed) {
      if (layer.isVisible) {
        layer.renderLayer(canvas);
      }
    }
  }

  @override
  bool shouldRepaint(final CanvasPanelPainter oldDelegate) => true;
}
