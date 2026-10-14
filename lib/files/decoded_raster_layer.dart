import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;

/// One raster layer decoded from a layered file, ready to rebuild on canvas.
///
/// Shared by every reader that decodes pixels with `package:image` (TIFF, PSD)
/// so they all apply layers the same way.
class DecodedRasterLayer {
  /// Creates a decoded layer.
  const DecodedRasterLayer({
    required this.image,
    required this.name,
    required this.offset,
    required this.opacity,
    required this.blendMode,
    required this.visible,
    this.locked = false,
    this.selected = false,
  });

  /// The layer's own straight-alpha pixels, sized to its bounds (not the canvas).
  final img.Image image;

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
}
