import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/providers/layer_provider.dart';
import 'package:fpaint/providers/stroke_layer_composite.dart';

/// Owns the [StrokeLayerComposite] lifecycle: built when exactly one layer
/// starts drawing, dropped when the stroke ends or the layer stack changes.
///
/// Driven entirely by the painter through [resolve], so every single-layer
/// tool (brush, eraser, smudge, blur, effect brushes) benefits without wiring
/// into each gesture path. A multi-layer stroke (cross-layer eraser) gets none.
class StrokeCompositeController {
  StrokeCompositeController({required this.onReady});

  /// Called when a freshly built composite is ready to be painted.
  final VoidCallback onReady;

  StrokeLayerComposite? _current;
  bool _building = false;

  /// Bumped on every release so a build that finishes late is discarded.
  int _generation = 0;

  /// Returns the composite for the stroke in progress on [layers], scheduling a
  /// build when there is none yet, or null when the painter must draw every
  /// layer itself (no single-layer stroke, or the composite is still building).
  StrokeLayerComposite? resolve(List<LayerProvider> layers) {
    final LayerProvider? active = _soleDrawingLayer(layers);
    final StrokeLayerComposite? current = _current;
    if (active != null && current != null && current.matches(layers, active)) {
      return current;
    }
    if (current != null || active == null) {
      release();
    }
    if (active != null && !_building) {
      unawaited(_build(List<LayerProvider>.of(layers), active));
    }
    return null;
  }

  /// Drops the current composite and invalidates any build in flight.
  void release() {
    _generation++;
    _building = false;
    _current?.dispose();
    _current = null;
  }

  /// The one layer currently drawing, or null when none or several are.
  static LayerProvider? _soleDrawingLayer(List<LayerProvider> layers) {
    LayerProvider? found;
    for (final LayerProvider layer in layers) {
      if (layer.isUserDrawing) {
        if (found != null) {
          return null;
        }
        found = layer;
      }
    }
    return found;
  }

  /// Flattens each side of [active] in [layers] and installs the composite,
  /// unless a [release] invalidated this build while it was rendering.
  Future<void> _build(List<LayerProvider> layers, LayerProvider active) async {
    _building = true;
    final int generation = _generation;
    final int activeIndex = layers.indexOf(active);
    // The list is top-first: lower indices are drawn above the active layer.
    final List<LayerProvider> above = layers.sublist(0, activeIndex);
    final List<LayerProvider> below = layers.sublist(activeIndex + 1);
    final ui.Image? aboveImage = await _flatten(above, active.size);
    final ui.Image? belowImage = await _flatten(below, active.size);
    if (generation != _generation) {
      aboveImage?.dispose();
      belowImage?.dispose();
      return;
    }
    _building = false;
    _current = StrokeLayerComposite(
      activeLayer: active,
      layers: layers,
      canvasSize: active.size,
      aboveImage: aboveImage,
      belowImage: belowImage,
      aboveLayers: aboveImage == null ? const <LayerProvider>{} : above.toSet(),
      belowLayers: belowImage == null ? const <LayerProvider>{} : below.toSet(),
    );
    onReady();
  }

  /// Flattens the visible layers of [group] (top-first) from their display
  /// caches, or returns null when the group is not worth or not safe to flatten.
  static Future<ui.Image?> _flatten(List<LayerProvider> group, Size canvasSize) async {
    final List<LayerProvider> visible = group.where((LayerProvider layer) => layer.isVisible).toList();
    if (visible.length < AppLimits.strokeCompositeMinLayers) {
      return null;
    }
    double scale = AppMath.zero.toDouble();
    for (final LayerProvider layer in visible) {
      if (layer.blendMode != ui.BlendMode.srcOver || !layer.hasDisplayCache) {
        return null;
      }
      scale = max(scale, layer.displayCacheScale);
    }
    final int width = max(AppMath.one, (canvasSize.width * scale).round());
    final int height = max(AppMath.one, (canvasSize.height * scale).round());
    return renderCanvasImage(
      width: width,
      height: height,
      draw: (ui.Canvas canvas) {
        canvas.scale(width / canvasSize.width, height / canvasSize.height);
        for (final LayerProvider layer in visible.reversed) {
          layer.drawDisplayCache(canvas, filterQuality: FilterQuality.medium);
        }
      },
    );
  }
}
