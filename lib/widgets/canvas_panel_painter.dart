import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/smudge_helper.dart';
import 'package:fpaint/providers/layer_provider.dart';

/// A custom painter that paints the canvas panel.
class CanvasPanelPainter extends CustomPainter {
  CanvasPanelPainter(
    this._layers, {
    this.includeTransparentBackground = false,
    super.repaint,
  });

  /// Cached repeating checkerboard tile + shader. Built once (per process) and
  /// reused across painter instances, so a reconstructed painter doesn't rebuild
  /// the background. See [_resolveTransparentBackgroundShader].
  // Retained so the tile image isn't finalized/disposed while [_tileShader]
  // still samples it.
  // ignore: unused_field
  static ui.Image? _tileImage;
  static ui.ImageShader? _tileShader;

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
      canvas.drawRect(
        Offset.zero & size,
        Paint()..shader = _resolveTransparentBackgroundShader(),
      );
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

  /// Returns a repeating checkerboard shader. The tile is rasterized once and
  /// reused, so filling the whole canvas is a single `drawRect` regardless of
  /// canvas size — instead of tens of thousands of per-cell `drawRect` calls
  /// re-recorded on the UI thread every paint (the old per-cell loop measured
  /// ~24ms per paint and dominated frame time during strokes).
  static ui.ImageShader _resolveTransparentBackgroundShader() {
    final ui.ImageShader? cached = _tileShader;
    if (cached != null) {
      return cached;
    }

    const int cell = AppLimits.transparentPatternSize;
    const int tile = cell * 2;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas tileCanvas = Canvas(recorder);
    final double cellSize = cell.toDouble();
    tileCanvas.drawRect(
      Rect.fromLTWH(0, 0, tile.toDouble(), tile.toDouble()),
      Paint()..color = AppColors.grey300,
    );
    final Paint cellPaint = Paint()..color = AppColors.grey400;
    tileCanvas.drawRect(Rect.fromLTWH(0, 0, cellSize, cellSize), cellPaint);
    tileCanvas.drawRect(Rect.fromLTWH(cellSize, cellSize, cellSize, cellSize), cellPaint);

    final ui.Image tileImage = recorder.endRecording().toImageSync(tile, tile);
    _tileImage = tileImage;
    final ui.ImageShader shader = ui.ImageShader(
      tileImage,
      TileMode.repeated,
      TileMode.repeated,
      Matrix4.identity().storage,
    );
    _tileShader = shader;
    return shader;
  }
}
