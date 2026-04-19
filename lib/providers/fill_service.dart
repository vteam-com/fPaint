// ignore: fcheck_one_class_per_file
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/flood_fill.dart';

/// Describes a flood-filled region path and its offset relative to the source.
class FillRegion {
  FillRegion({
    required this.path,
    required this.offset,
  });

  final Path path;
  final Offset offset;
}

/// Builds fill actions from image-based flood-fill regions.
class FillService {
  /// Performs a flood fill with a solid color.
  Future<UserActionDrawing> createFloodFillSolidAction({
    required final ui.Image sourceImage,
    required final Offset position,
    required final Color fillColor,
    required final int tolerance,
    required final Path? clipPath,
  }) async {
    final FillRegion region = await getRegionPathFromImage(
      image: sourceImage,
      position: position,
      tolerance: tolerance,
    );

    final ui.Path path = region.path.shift(region.offset);

    final ui.Rect bounds = path.getBounds();

    return UserActionDrawing(
      action: ActionType.region,
      path: path,
      positions: <ui.Offset>[
        bounds.topLeft,
        bounds.bottomRight,
      ],
      fillColor: fillColor,
      clipPath: clipPath,
    );
  }

  /// Performs a flood fill with a gradient.
  Future<UserActionDrawing> createFloodFillGradientAction({
    required final ui.Image sourceImage,
    required final FillModel fillModel,
    required final int tolerance,
    required final Path? clipPath,
    required final Offset Function(Offset) toCanvas,
  }) async {
    // For radial gradients, start flood fill at the first gradient handle position
    // For linear gradients, start at the center between handles
    final ui.Offset floodFillStartPoint = fillModel.mode == FillMode.radial
        ? toCanvas(fillModel.gradientPoints.first.offset)
        : toCanvas(fillModel.centerPoint);

    final FillRegion region = await getRegionPathFromImage(
      image: sourceImage,
      position: floodFillStartPoint,
      tolerance: tolerance,
    );

    final ui.Path path = region.path.shift(region.offset);

    final ui.Rect bounds = path.getBounds();

    // Guard against empty region (e.g. tap outside canvas or on invalid coordinates)
    if (bounds.isEmpty || bounds.width == 0 || bounds.height == 0) {
      return UserActionDrawing(
        action: ActionType.fill,
        positions: const <ui.Offset>[],
      );
    }

    final Gradient gradient;
    if (fillModel.mode == FillMode.radial) {
      // For radial gradients, the center is the location of the first gradient handle
      final ui.Offset centerPoint = toCanvas(fillModel.gradientPoints.first.offset);

      gradient = RadialGradient(
        colors: fillModel.gradientPoints.map((final GradientPoint point) => point.color).toList(),
        center: Alignment(
          ((centerPoint.dx - bounds.left) / bounds.width) * AppMath.pair - 1,
          ((centerPoint.dy - bounds.top) / bounds.height) * AppMath.pair - 1,
        ),
        radius: (fillModel.gradientPoints.last.offset - fillModel.gradientPoints.first.offset).distance / bounds.width,
      );
    } else {
      gradient = LinearGradient(
        colors: fillModel.gradientPoints.map((final GradientPoint point) => point.color).toList(),
        begin: Alignment(
          (toCanvas(fillModel.gradientPoints.first.offset).dx / bounds.width) * AppMath.pair - 1,
          (toCanvas(fillModel.gradientPoints.first.offset).dy / bounds.height) * AppMath.pair - 1,
        ),
        end: Alignment(
          (toCanvas(fillModel.gradientPoints.last.offset).dx / bounds.width) * AppMath.pair - 1,
          (toCanvas(fillModel.gradientPoints.last.offset).dy / bounds.height) * AppMath.pair - 1,
        ),
      );
    }

    return UserActionDrawing(
      action: ActionType.region,
      path: path,
      positions: <ui.Offset>[
        bounds.topLeft,
        bounds.bottomRight,
      ],
      gradient: gradient,
      clipPath: clipPath,
    );
  }

  /// Gets the region path from a layer image.
  Future<FillRegion> getRegionPathFromImage({
    required final ui.Image image,
    required final ui.Offset position,
    required final int tolerance,
  }) async {
    // Guard against NaN or infinite coordinates
    if (position.dx.isNaN || position.dy.isNaN || position.dx.isInfinite || position.dy.isInfinite) {
      return FillRegion(path: ui.Path(), offset: ui.Offset.zero);
    }

    final int x = position.dx.toInt();
    final int y = position.dy.toInt();

    // Guard against out-of-bounds or invalid coordinates
    if (x < 0 || y < 0 || x >= image.width || y >= image.height) {
      return FillRegion(path: ui.Path(), offset: ui.Offset.zero);
    }

    // Perform flood fill at the clicked position
    final Region region = await extractRegionByColorEdgeAndOffset(
      image: image,
      x: x,
      y: y,
      tolerance: tolerance,
    );
    return FillRegion(
      path: region.path,
      offset: region.offset,
    );
  }
}
