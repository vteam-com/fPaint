import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/models/selection_effect.dart';

/// Snapshot of the active effect preview state needed for rendering/commit.
class SelectionEffectPreviewState {
  const SelectionEffectPreviewState({
    required this.effect,
    required this.sourceImage,
    required this.pixelScale,
    required this.selectionPath,
    required this.bounds,
    required this.strength,
    required this.size,
    required this.coversEntireLayer,
  });

  /// The effect being previewed.
  final SelectionEffect effect;

  /// The image the effect reads from — the proxy during live preview, or the
  /// full-resolution source on commit.
  final ui.Image sourceImage;

  /// Scale of [sourceImage] relative to the full-resolution source.
  final double pixelScale;

  /// The selection the result is masked back to.
  final Path selectionPath;

  /// Canvas-space bounds of [selectionPath].
  final Rect bounds;

  /// Effect strength, in the effect's own units.
  final double strength;

  /// Effect size, in the effect's own units.
  final double size;

  /// Whether the target covers the whole layer, which makes masking a no-op.
  final bool coversEntireLayer;
}
