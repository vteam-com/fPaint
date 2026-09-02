import 'dart:ui' as ui;

import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/visible_model.dart';

/// Stores the active special-effect preview state for a selection.
class EffectPreviewModel extends VisibleModel {
  /// The selected effect currently being previewed.
  SelectionEffect? effect;

  /// Original clipped pixels captured from the active selection.
  ui.Image? sourceImage;

  /// Downscaled copy of [sourceImage] used for live preview rendering.
  ///
  /// Live preview at full resolution allocates a render target per slider tick,
  /// which exhausts VRAM on very large canvases. Commits still use [sourceImage].
  ui.Image? proxyImage;

  /// Ratio of [proxyImage] size to [sourceImage] size (1.0 when not downscaled).
  double proxyScale = AppEffects.defaultPixelScale;

  /// Latest processed image produced for live preview.
  ui.Image? previewImage;

  /// Selection path used when committing the effect.
  ui.Path? erasePath;

  /// Selection bounds in canvas coordinates.
  ui.Rect? bounds;

  /// Whether the effect targets the whole layer rather than a selection.
  bool coversEntireLayer = false;

  /// Current intensity used for the live preview.
  double strength = AppEffects.defaultIntensity;

  /// Current size setting used for effects that expose a size control.
  double size = AppEffects.minSize;

  /// Starts preview state for [selectedEffect] over [selectionBounds].
  void start({
    required SelectionEffect selectedEffect,
    required ui.Image selectionImage,
    required ui.Path selectionPath,
    required ui.Rect selectionBounds,
    required double initialStrength,
    required double initialSize,
    ui.Image? selectionProxyImage,
    double selectionProxyScale = AppEffects.defaultPixelScale,
    bool selectionCoversEntireLayer = false,
  }) {
    _disposeImages();
    effect = selectedEffect;
    sourceImage = selectionImage;
    proxyImage = selectionProxyImage ?? selectionImage;
    proxyScale = selectionProxyScale;
    coversEntireLayer = selectionCoversEntireLayer;
    previewImage = null;
    erasePath = selectionPath;
    bounds = selectionBounds;
    strength = initialStrength;
    size = initialSize;
    isVisible = true;
  }

  @override
  void clear() {
    _disposeImages();
    effect = null;
    erasePath = null;
    bounds = null;
    coversEntireLayer = false;
    strength = AppEffects.defaultIntensity;
    size = AppEffects.minSize;
    super.clear();
  }

  /// Releases the GPU textures this model owns.
  void _disposeImages() {
    // The proxy can alias the source when no downscale was needed.
    if (!identical(proxyImage, sourceImage)) {
      proxyImage?.dispose();
    }
    sourceImage?.dispose();
    previewImage?.dispose();
    sourceImage = null;
    proxyImage = null;
    previewImage = null;
    proxyScale = AppEffects.defaultPixelScale;
  }
}
