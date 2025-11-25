import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/panels/tools/flood_fill.dart';
import 'package:fpaint/providers/layer_provider.dart';

class FillService {
  /// Performs a flood fill with a solid color.
  Future<UserActionDrawing> createFloodFillSolidAction({
    required final LayerProvider selectedLayer,
    required final Size canvasSize,
    required final Offset position,
    required final Color fillColor,
    required final int tolerance,
    required final Path? clipPath,
  }) async {
    final Region region = await getRegionPathFromLayerImage(
      selectedLayer: selectedLayer,
      canvasSize: canvasSize,
      position: position,
      tolerance: tolerance,
    );

    final ui.Path path = region.path.shift(
      Offset(region.left.toDouble(), region.top.toDouble()),
    );

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
    required final LayerProvider selectedLayer,
    required final Size canvasSize,
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

    final Region region = await getRegionPathFromLayerImage(
      selectedLayer: selectedLayer,
      canvasSize: canvasSize,
      position: floodFillStartPoint,
      tolerance: tolerance,
    );

    final ui.Path path = region.path.shift(
      Offset(region.left.toDouble(), region.top.toDouble()),
    );

    final ui.Rect bounds = path.getBounds();

    final Gradient gradient;
    if (fillModel.mode == FillMode.radial) {
      // For radial gradients, the center is the location of the first gradient handle
      final ui.Offset centerPoint = toCanvas(fillModel.gradientPoints.first.offset);

      gradient = RadialGradient(
        colors: fillModel.gradientPoints.map((final GradientPoint point) => point.color).toList(),
        center: Alignment(
          ((centerPoint.dx - bounds.left) / bounds.width) * 2 - 1,
          ((centerPoint.dy - bounds.top) / bounds.height) * 2 - 1,
        ),
        radius: (fillModel.gradientPoints.last.offset - fillModel.gradientPoints.first.offset).distance / bounds.width,
      );
    } else {
      gradient = LinearGradient(
        colors: fillModel.gradientPoints.map((final GradientPoint point) => point.color).toList(),
        begin: Alignment(
          (toCanvas(fillModel.gradientPoints.first.offset).dx / bounds.width) * 2 - 1,
          (toCanvas(fillModel.gradientPoints.first.offset).dy / bounds.height) * 2 - 1,
        ),
        end: Alignment(
          (toCanvas(fillModel.gradientPoints.last.offset).dx / bounds.width) * 2 - 1,
          (toCanvas(fillModel.gradientPoints.last.offset).dy / bounds.height) * 2 - 1,
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
  Future<Region> getRegionPathFromLayerImage({
    required final LayerProvider selectedLayer,
    required final Size canvasSize,
    required final ui.Offset position,
    required final int tolerance,
  }) async {
    final ui.Image img = selectedLayer.toImageForStorage(canvasSize);

    // Perform flood fill at the clicked position
    final Region region = await extractRegionByColorEdgeAndOffset(
      image: img,
      x: position.dx.toInt(),
      y: position.dy.toInt(),
      tolerance: tolerance,
    );
    return region;
  }
}
