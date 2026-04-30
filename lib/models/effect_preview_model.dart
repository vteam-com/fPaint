import 'dart:ui' as ui;

import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/visible_model.dart';

/// Stores the active special-effect preview state for a selection.
class EffectPreviewModel extends VisibleModel {
  /// The selected effect currently being previewed.
  SelectionEffect? effect;

  /// Original clipped pixels captured from the active selection.
  ui.Image? sourceImage;

  /// Latest processed image produced for live preview.
  ui.Image? previewImage;

  /// Selection path used when committing the effect.
  ui.Path? erasePath;

  /// Selection bounds in canvas coordinates.
  ui.Rect? bounds;

  /// Current intensity used for the live preview.
  double strength = AppEffects.defaultIntensity;

  /// Starts preview state for [selectedEffect] over [selectionBounds].
  void start({
    required final SelectionEffect selectedEffect,
    required final ui.Image selectionImage,
    required final ui.Path selectionPath,
    required final ui.Rect selectionBounds,
    required final double initialStrength,
  }) {
    effect = selectedEffect;
    sourceImage = selectionImage;
    previewImage = null;
    erasePath = selectionPath;
    bounds = selectionBounds;
    strength = initialStrength;
    isVisible = true;
  }

  @override
  void clear() {
    effect = null;
    sourceImage = null;
    previewImage = null;
    erasePath = null;
    bounds = null;
    strength = AppEffects.defaultIntensity;
    super.clear();
  }
}
