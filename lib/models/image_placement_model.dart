import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/models/visible_model.dart';

/// Holds the state for an image being interactively placed on the canvas
/// before committing it as a drawing action.
class ImagePlacementModel extends VisibleModel {
  /// The image being placed.
  ui.Image? image;

  /// The top-left position of the image in canvas coordinates.
  Offset position = Offset.zero;

  /// Uniform scale factor applied to the image.
  double scale = 1.0;

  /// Rotation angle in radians.
  double rotation = 0.0;

  /// The width of the image in canvas coordinates after scaling.
  double get displayWidth => (image?.width.toDouble() ?? 0) * scale;

  /// The height of the image in canvas coordinates after scaling.
  double get displayHeight => (image?.height.toDouble() ?? 0) * scale;

  /// The bounding rectangle of the placed image in canvas coordinates.
  Rect get bounds => Rect.fromLTWH(
    position.dx,
    position.dy,
    displayWidth,
    displayHeight,
  );

  /// The center of the image in canvas coordinates.
  Offset get center => bounds.center;

  /// Begins placement of [imageToPlace] at the given [initialPosition].
  void start({
    required final ui.Image imageToPlace,
    required final Offset initialPosition,
  }) {
    image = imageToPlace;
    position = initialPosition;
    scale = 1.0;
    rotation = 0.0;
    isVisible = true;
  }

  @override
  void clear() {
    super.clear();
    image = null;
    position = Offset.zero;
    scale = 1.0;
    rotation = 0.0;
  }
}
