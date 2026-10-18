import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/files/decoded_layer_pixels.dart';

/// One raster layer decoded from a layered file, ready to rebuild on canvas.
///
/// Shared by every layered reader (ORA, TIFF, PSD) so they all apply layers
/// the same way.
class DecodedRasterLayer {
  /// Creates a decoded layer.
  const DecodedRasterLayer({
    required this.pixels,
    required this.name,
    required this.offset,
    required this.opacity,
    required this.blendMode,
    required this.visible,
    this.locked = false,
    this.selected = false,
    this.parentGroupName = '',
    this.preserveAlpha = true,
  });

  /// The layer's own pixels, sized to its bounds (not the canvas), or null
  /// for an empty layer.
  final DecodedLayerPixels? pixels;

  /// Layer name shown in the layers panel.
  final String name;

  /// Top-left position of [image] on the canvas.
  final Offset offset;

  /// Layer opacity in the 0..1 range.
  final double opacity;

  /// Blend mode used to composite the layer.
  final ui.BlendMode blendMode;

  /// Whether the layer is visible.
  final bool visible;

  /// Whether the layer is locked against edits.
  final bool locked;

  /// Whether the file marked this layer as the selected one.
  final bool selected;

  /// Name of the group the layer belonged to, or empty when ungrouped.
  final String parentGroupName;

  /// Whether painting on the layer keeps its existing alpha.
  final bool preserveAlpha;
}
