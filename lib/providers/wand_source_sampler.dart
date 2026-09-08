import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/providers/fill_service.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/wand_selection_manager_cache.dart';

/// Rasterizes the pixels the magic wand and paint bucket sample from.
///
/// Split out of the selection provider because producing the source raster is a
/// distinct job from deciding what to do with the region it yields: it maps a
/// layer stack to bytes and caches them, and touches no selection state
/// (Single Responsibility). It holds no state itself — the cache lives in the
/// injected [WandSourceCache] — so it is straightforward to exercise directly.
class WandSourceSampler {
  const WandSourceSampler(this._cache);

  final WandSourceCache _cache;

  /// Returns the RGBA source for [layers], reusing the cache when the stack has
  /// not changed since it was filled.
  ///
  /// Samples every visible layer when [sampleAllLayers] is set, otherwise only
  /// the selected one. Returns null when the pixels could not be read back.
  Future<FillImageData?> sample(
    LayersProvider layers, {
    required bool sampleAllLayers,
  }) async {
    final int signature = sourceSignature(layers, sampleAllLayers: sampleAllLayers);
    final FillImageData? cached = _cache.cachedImageData(signature);
    if (cached != null) {
      return cached;
    }

    final _SourceExtent extent = _SourceExtent.forCanvas(layers);
    final ui.Image image = await renderCanvasImage(
      width: extent.width,
      height: extent.height,
      draw: (ui.Canvas canvas) => _drawSource(
        canvas,
        layers,
        extent: extent,
        sampleAllLayers: sampleAllLayers,
      ),
    );

    try {
      final Uint8List? pixels = await convertImageToUint8List(image);
      if (pixels == null) {
        return null;
      }

      _cache.storeCache(
        signature: signature,
        pixels: pixels,
        width: image.width,
        height: image.height,
        canvasScaleX: extent.scaleX,
        canvasScaleY: extent.scaleY,
      );

      return FillImageData(
        pixels: pixels,
        width: image.width,
        height: image.height,
        canvasScaleX: extent.scaleX,
        canvasScaleY: extent.scaleY,
      );
    } finally {
      image.dispose();
    }
  }

  /// Paints the pixels the wand samples onto [canvas].
  ///
  /// Scaled to the reduced raster in [extent], compositing either every visible
  /// layer or just the selected one. Each layer is clipped to the canvas bounds
  /// so content that extends past the edge cannot bleed into the sample.
  void _drawSource(
    ui.Canvas canvas,
    LayersProvider layers, {
    required _SourceExtent extent,
    required bool sampleAllLayers,
  }) {
    final Rect compositeBounds = Offset.zero & layers.size;
    canvas.scale(extent.scaleX, extent.scaleY);
    if (!sampleAllLayers) {
      layers.selectedLayer.renderLayer(canvas, compositeBounds: compositeBounds);
      return;
    }
    for (final LayerProvider layer in layers.list.reversed) {
      if (layer.isVisible) {
        layer.renderLayer(canvas, compositeBounds: compositeBounds);
      }
    }
  }

  /// Creates a stable fingerprint of the pixels the wand would sample.
  ///
  /// Changing any input the raster depends on — canvas size, which layers are
  /// visible, or each layer's content or compositing — yields a different value,
  /// which is what invalidates the cache.
  ///
  /// Both paths hash the same per-layer fields via [_layerSignature], so a
  /// render-affecting property can never be covered in one mode but stale in
  /// the other. Compositing matters because [LayerProvider.renderLayer] bakes
  /// opacity and blend mode into the sampled pixels and paints the background
  /// fill beneath the action stack.
  int sourceSignature(
    LayersProvider layers, {
    required bool sampleAllLayers,
  }) {
    if (sampleAllLayers) {
      // hashAll, not hash: a List hashes by identity, so passing the per-layer
      // list to Object.hash produced a fresh value on every call and the
      // all-layers cache never hit.
      return Object.hashAll(<Object?>[
        layers,
        layers.width.toInt(),
        layers.height.toInt(),
        sampleAllLayers,
        ...layers.list.map(_layerSignature),
      ]);
    }

    return Object.hash(
      layers.selectedLayerIndex,
      layers.width.toInt(),
      layers.height.toInt(),
      sampleAllLayers,
      _layerSignature(layers.selectedLayer),
    );
  }

  /// Fingerprints one layer's content and compositing state.
  int _layerSignature(LayerProvider layer) => Object.hash(
    layer,
    layer.actionStack.length,
    layer.redoStack.length,
    layer.lastUserAction,
    layer.isVisible,
    layer.opacity,
    layer.blendMode,
    layer.backgroundColor,
  );
}

/// The pixel dimensions and scale the wand source is rasterized at.
///
/// Large canvases are sampled at reduced resolution so a wand tap stays
/// responsive; the scale factors map canvas coordinates onto that raster.
class _SourceExtent {
  const _SourceExtent({
    required this.width,
    required this.height,
    required this.scaleX,
    required this.scaleY,
  });

  factory _SourceExtent.forCanvas(LayersProvider layers) {
    final int canvasWidth = layers.width.toInt();
    final int canvasHeight = layers.height.toInt();
    final int longestSide = canvasWidth > canvasHeight ? canvasWidth : canvasHeight;
    final double sourceScale = longestSide > AppLimits.floodFillSourceMaxDimension
        ? AppLimits.floodFillSourceMaxDimension / longestSide
        : AppVisual.full;
    final int width = (canvasWidth * sourceScale).round().clamp(AppMath.one, canvasWidth);
    final int height = (canvasHeight * sourceScale).round().clamp(AppMath.one, canvasHeight);

    return _SourceExtent(
      width: width,
      height: height,
      scaleX: width / canvasWidth,
      scaleY: height / canvasHeight,
    );
  }

  final int width;
  final int height;
  final double scaleX;
  final double scaleY;
}
