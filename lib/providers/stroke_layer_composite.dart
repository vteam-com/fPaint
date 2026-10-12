import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/viewport_transform_helper.dart';
import 'package:fpaint/providers/layer_provider.dart';

/// The compositing state of one layer, compared to detect a stale composite.
typedef _LayerCompositeKey = ({bool isVisible, double opacity, ui.BlendMode blendMode});

/// Display-resolution flattenings of the layers above and below the layer
/// being painted, valid for the duration of one single-layer stroke.
///
/// While a stroke is in progress only the painted layer changes, yet the
/// painter would otherwise re-composite every visible layer per pointer move.
/// Standing one pre-flattened image in for each side cuts that to three blits
/// regardless of layer count (the Procreate/Krita "below/above" cache).
///
/// A side is flattened only when every visible layer in it is a plain
/// `srcOver` layer with a display cache: `srcOver` is associative, so the
/// flattened group composites exactly like its layers drawn one by one. Any
/// other blend mode, or a text layer (which never has a display cache), leaves
/// that side on the normal per-layer path.
class StrokeLayerComposite {
  /// Snapshots [layers] (top-first) for staleness checks; takes ownership of
  /// the two group images.
  StrokeLayerComposite({
    required this.activeLayer,
    required List<LayerProvider> layers,
    required this._canvasSize,
    required this._aboveImage,
    required this._belowImage,
    required this._aboveLayers,
    required this._belowLayers,
  }) : _layers = layers,
       _keys = layers.map(_keyOf).toList();

  /// The layer being painted; always drawn live.
  final LayerProvider activeLayer;

  final List<LayerProvider> _layers;
  final List<_LayerCompositeKey> _keys;
  final Size _canvasSize;
  final ui.Image? _aboveImage;
  final ui.Image? _belowImage;
  final Set<LayerProvider> _aboveLayers;
  final Set<LayerProvider> _belowLayers;

  static _LayerCompositeKey _keyOf(LayerProvider layer) =>
      (isVisible: layer.isVisible, opacity: layer.opacity, blendMode: layer.blendMode);

  /// Whether this composite still describes [layers] painted on [active].
  bool matches(List<LayerProvider> layers, LayerProvider active) {
    if (!identical(active, activeLayer) || layers.length != _layers.length) {
      return false;
    }
    for (int index = 0; index < layers.length; index++) {
      if (!identical(layers[index], _layers[index]) || _keyOf(layers[index]) != _keys[index]) {
        return false;
      }
    }
    return true;
  }

  /// The flattened image standing in for [layer], or null when [layer] must be
  /// drawn on its own.
  ui.Image? groupImageFor(LayerProvider layer) {
    if (_aboveLayers.contains(layer)) {
      return _aboveImage;
    }
    if (_belowLayers.contains(layer)) {
      return _belowImage;
    }
    return null;
  }

  /// Composites a flattened [group] image onto the untransformed viewport
  /// [canvas]. Opacity is already baked into the group.
  void paintGroup(
    Canvas canvas,
    ui.Image group, {
    required ViewportTransform viewport,
    required Rect visibleCanvasBounds,
    required FilterQuality filterQuality,
  }) {
    canvas.save();
    canvas.transform(viewport.matrix.storage);
    canvas.clipRect(visibleCanvasBounds, doAntiAlias: false);
    canvas.drawImageRect(
      group,
      Rect.fromLTWH(0, 0, group.width.toDouble(), group.height.toDouble()),
      Offset.zero & _canvasSize,
      Paint()..filterQuality = filterQuality,
    );
    canvas.restore();
  }

  /// Releases the flattened group images.
  void dispose() {
    _aboveImage?.dispose();
    _belowImage?.dispose();
  }
}
