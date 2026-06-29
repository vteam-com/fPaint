import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/smudge_helper.dart';
import 'package:fpaint/providers/layer_provider.dart';
import 'package:fpaint/widgets/transparent_background.dart';

/// A custom painter that paints the canvas panel.
class CanvasPanelPainter extends CustomPainter {
  CanvasPanelPainter(
    this._layers, {
    this.includeTransparentBackground = false,
    super.repaint,
  });

  ui.Picture? _cachedTransparentBackgroundPicture;
  Size? _cachedTransparentBackgroundSize;

  /// The layers to paint.
  final List<LayerProvider> _layers;

  /// Whether to include the transparent background.
  final bool includeTransparentBackground;

  @override
  void paint(final Canvas canvas, final Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final Stopwatch? paintWatch = PixelBrushProfiler.enabled ? (Stopwatch()..start()) : null;

    if (includeTransparentBackground) {
      final ui.Picture backgroundPicture = _resolveTransparentBackgroundPicture(size);
      canvas.drawPicture(backgroundPicture);
    }

    for (final LayerProvider layer in _layers.reversed) {
      if (layer.isVisible) {
        layer.renderLayer(canvas);
      }
    }

    if (paintWatch != null) {
      paintWatch.stop();
      PixelBrushProfiler.record('canvasPaint', paintWatch.elapsedMicroseconds);
    }
  }

  @override
  bool shouldRepaint(final CanvasPanelPainter oldDelegate) {
    return oldDelegate._layers != _layers || oldDelegate.includeTransparentBackground != includeTransparentBackground;
  }

  /// Returns a cached checkerboard background picture for the current canvas [size].
  ui.Picture _resolveTransparentBackgroundPicture(final Size size) {
    if (_cachedTransparentBackgroundPicture != null && _cachedTransparentBackgroundSize == size) {
      return _cachedTransparentBackgroundPicture!;
    }

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas pictureCanvas = Canvas(recorder);
    drawTransparentBackgroundOffsetAndSize(
      canvas: pictureCanvas,
      size: size,
    );

    final ui.Picture picture = recorder.endRecording();
    _cachedTransparentBackgroundPicture = picture;
    _cachedTransparentBackgroundSize = size;
    return picture;
  }
}
