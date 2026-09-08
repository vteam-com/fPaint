import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/viewport_transform_helper.dart';
import 'package:fpaint/providers/layer_provider.dart';

/// A custom painter that paints the canvas panel.
class CanvasPanelPainter extends CustomPainter {
  CanvasPanelPainter(
    this._layers, {
    required this.viewport,
    this.includeTransparentBackground = false,
    this.displayScale = 1.0,
    required this.visibleCanvasBounds,
    this.onNeedsDisplayCache,
    this.isInteractiveViewportChange,
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

  /// The canvas-to-screen viewport transform (pan, zoom and rotation).
  final ViewportTransform viewport;

  /// Whether to include the transparent background.
  final bool includeTransparentBackground;

  /// On-screen canvas-pixels per canvas-pixel (zoom × devicePixelRatio). Layers
  /// draw from a display-resolution cache sized for this; when it's stale/absent
  /// (or zoomed in past it) they fall back to full-res and request a rebuild.
  final double displayScale;

  /// Visible viewport expressed in document coordinates.
  final Rect visibleCanvasBounds;

  /// Called (during paint) when a layer needs its display cache (re)built for
  /// the current [displayScale]. The owner schedules the async build and repaints.
  final void Function(LayerProvider layer, double requiredScale)? onNeedsDisplayCache;

  /// Whether an active pan or pinch should use faster, unfiltered cache blits.
  final bool Function()? isInteractiveViewportChange;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    if (includeTransparentBackground) {
      canvas.save();
      canvas.transform(viewport.matrix.storage);
      canvas.clipRect(visibleCanvasBounds, doAntiAlias: false);
      canvas.drawRect(
        visibleCanvasBounds,
        Paint()..shader = _resolveTransparentBackgroundShader(),
      );
      canvas.restore();
    }

    final Rect viewportBounds = Offset.zero & size;
    final void Function(LayerProvider, double)? requestRebuild = onNeedsDisplayCache;
    final bool useLowQualitySampling = isInteractiveViewportChange?.call() ?? false;
    for (final LayerProvider layer in _layers.reversed) {
      if (layer.isVisible) {
        if (requestRebuild == null) {
          layer.renderLayerInViewport(
            canvas,
            viewportBounds: viewportBounds,
            viewport: viewport,
            visibleCanvasBounds: visibleCanvasBounds,
          );
        } else {
          layer.renderLayerForViewportDisplay(
            canvas,
            displayScale,
            () => requestRebuild(layer, displayScale),
            viewportBounds: viewportBounds,
            viewport: viewport,
            visibleCanvasBounds: visibleCanvasBounds,
            filterQuality: useLowQualitySampling ? FilterQuality.none : FilterQuality.medium,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(CanvasPanelPainter oldDelegate) {
    return oldDelegate._layers != _layers ||
        oldDelegate.viewport != viewport ||
        oldDelegate.includeTransparentBackground != includeTransparentBackground ||
        oldDelegate.displayScale != displayScale ||
        oldDelegate.visibleCanvasBounds != visibleCanvasBounds;
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
