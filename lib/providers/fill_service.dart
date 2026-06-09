// ignore: fcheck_one_class_per_file
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/halftone_fill.dart';
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

/// Immutable raster payload used for repeated flood-fill queries via signature-based caching.
///
/// **Immutability Contract:** Callers must treat [pixels] as read-only after construction.
/// Mutations to the byte buffer will corrupt the cache. The cache layer validates correctness
/// via [cachedWandSourceSignature], but this relies on pixels remaining unchanged.
class FillImageData {
  const FillImageData({
    required this.pixels,
    required this.width,
    required this.height,
  });

  /// Raster bytes in RGBA format. Must not be modified after construction.
  final Uint8List pixels;

  /// Width of the raster in pixels.
  final int width;

  /// Height of the raster in pixels.
  final int height;
}

/// Builds fill actions from image-based flood-fill regions.
class FillService {
  /// Returns an empty fill action used when flood fill cannot resolve a region.
  UserActionDrawing _buildEmptyFloodFillAction() {
    return UserActionDrawing(
      action: ActionType.fill,
      positions: const <ui.Offset>[],
    );
  }

  /// Performs a flood fill with a solid color.
  Future<UserActionDrawing> createFloodFillSolidAction({
    required final ui.Image sourceImage,
    required final Offset position,
    required final Color fillColor,
    final Color? halftoneDotColor,
    final double? halftoneMaxDotSizeFactor,
    required final int tolerance,
    required final Path? clipPath,
    final Path? regionPathOverride,
  }) async {
    final ui.Path path = await _resolveFloodFillPath(
      sourceImage: sourceImage,
      position: position,
      tolerance: tolerance,
      regionPathOverride: regionPathOverride,
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
      halftoneFill: halftoneDotColor == null
          ? null
          : HalftoneFill(
              backgroundColor: AppColors.transparent,
              dotColor: halftoneDotColor,
              maxDotSizeFactor: halftoneMaxDotSizeFactor ?? AppVisual.full,
            ),
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
    final Path? regionPathOverride,
  }) async {
    if (!_hasUsableGradientConfiguration(fillModel)) {
      return _buildEmptyFloodFillAction();
    }

    // For radial gradients, start flood fill at the first gradient handle position
    // For linear gradients, start at the center between handles
    final ui.Offset floodFillStartPoint = fillModel.mode == FillMode.radial
        ? toCanvas(fillModel.gradientPoints.first.offset)
        : toCanvas(fillModel.centerPoint);

    final ui.Path path = await _resolveFloodFillPath(
      sourceImage: sourceImage,
      position: floodFillStartPoint,
      tolerance: tolerance,
      regionPathOverride: regionPathOverride,
    );

    final ui.Rect bounds = path.getBounds();

    // Guard against empty region (e.g. tap outside canvas or on invalid coordinates)
    if (bounds.isEmpty || bounds.width == 0 || bounds.height == 0) {
      return _buildEmptyFloodFillAction();
    }

    // Use the authoritative gradient stop colors and positions from the model.
    // Both lists may have more than two entries for multi-stop gradients.
    final Gradient gradient = _buildFloodFillGradient(
      bounds: bounds,
      fillModel: fillModel,
      toCanvas: toCanvas,
    );

    return UserActionDrawing(
      action: ActionType.region,
      path: path,
      positions: <ui.Offset>[
        bounds.topLeft,
        bounds.bottomRight,
      ],
      gradient: gradient,
      halftoneFill: fillModel.halftoneEnabled
          ? HalftoneFill(
              backgroundColor: fillModel.gradientStopColors.first,
              dotColor: fillModel.gradientStopColors.last,
              maxDotSizeFactor: fillModel.halftoneMaxDotSizeFactor,
            )
          : null,
      clipPath: clipPath,
    );
  }

  /// Resolves the geometry to fill, either from an explicit override path or
  /// from the raster flood-fill region sampled at [position].
  Future<ui.Path> _resolveFloodFillPath({
    required final ui.Image sourceImage,
    required final Offset position,
    required final int tolerance,
    required final Path? regionPathOverride,
  }) async {
    if (regionPathOverride != null) {
      return Path.from(regionPathOverride);
    }

    final FillRegion region = await getRegionPathFromImage(
      image: sourceImage,
      position: position,
      tolerance: tolerance,
    );

    return region.path.shift(region.offset);
  }

  /// Builds the gradient geometry used by smooth and halftone flood fills.
  Gradient _buildFloodFillGradient({
    required final ui.Rect bounds,
    required final FillModel fillModel,
    required final Offset Function(Offset) toCanvas,
  }) {
    // Snapshot stop data so previously recorded fills do not change when the
    // shared fill model is edited for a later action.
    final List<Color> gradientColors = List<Color>.of(fillModel.gradientStopColors, growable: false);
    final List<double> gradientStops = List<double>.of(fillModel.gradientStopPositions, growable: false);

    if (fillModel.mode == FillMode.radial) {
      final ui.Offset centerPoint = toCanvas(fillModel.gradientPoints.first.offset);

      return RadialGradient(
        colors: gradientColors,
        stops: gradientStops,
        center: _pointToBoundsAlignment(bounds: bounds, point: centerPoint),
        radius: (fillModel.gradientPoints.last.offset - fillModel.gradientPoints.first.offset).distance / bounds.width,
      );
    }

    final ui.Offset beginPoint = toCanvas(fillModel.gradientPoints.first.offset);
    final ui.Offset endPoint = toCanvas(fillModel.gradientPoints.last.offset);

    return LinearGradient(
      colors: gradientColors,
      stops: gradientStops,
      begin: _pointToBoundsAlignment(bounds: bounds, point: beginPoint),
      end: _pointToBoundsAlignment(bounds: bounds, point: endPoint),
    );
  }

  /// Returns whether [fillModel] has enough gradient data for flood fill.
  bool _hasUsableGradientConfiguration(final FillModel fillModel) {
    final int pointCount = fillModel.gradientPoints.length;
    final int colorCount = fillModel.gradientStopColors.length;
    final int stopCount = fillModel.gradientStopPositions.length;
    return pointCount >= AppMath.two && colorCount >= FillModel.gradientStopMin && stopCount == colorCount;
  }

  /// Converts an absolute [point] inside [bounds] into a gradient alignment.
  Alignment _pointToBoundsAlignment({
    required final ui.Rect bounds,
    required final ui.Offset point,
  }) {
    return Alignment(
      ((point.dx - bounds.left) / bounds.width) * AppMath.pair - AppVisual.full,
      ((point.dy - bounds.top) / bounds.height) * AppMath.pair - AppVisual.full,
    );
  }

  /// Gets the region path from a layer image.
  Future<FillRegion> getRegionPathFromImage({
    final ui.Image? image,
    required final ui.Offset position,
    required final int tolerance,
    final FillImageData? imageData,
  }) async {
    // Guard against NaN or infinite coordinates
    if (position.dx.isNaN || position.dy.isNaN || position.dx.isInfinite || position.dy.isInfinite) {
      return FillRegion(path: ui.Path(), offset: ui.Offset.zero);
    }

    final int x = position.dx.toInt();
    final int y = position.dy.toInt();

    final FillImageData? source = imageData ?? await _buildFillImageData(image);
    if (source == null) {
      return FillRegion(path: ui.Path(), offset: ui.Offset.zero);
    }

    // Guard against out-of-bounds or invalid coordinates
    if (x < AppMath.zero || y < AppMath.zero || x >= source.width || y >= source.height) {
      return FillRegion(path: ui.Path(), offset: ui.Offset.zero);
    }

    // Perform flood fill at the clicked position
    final Region region = await extractRegionByColorEdgeAndOffsetFromPixels(
      pixels: source.pixels,
      width: source.width,
      height: source.height,
      x: x,
      y: y,
      tolerance: tolerance,
    );
    return FillRegion(
      path: region.path,
      offset: region.offset,
    );
  }

  /// Builds a reusable flood-fill raster payload from [image].
  Future<FillImageData?> _buildFillImageData(final ui.Image? image) async {
    if (image == null) {
      return null;
    }

    final Uint8List? pixels = await convertImageToUint8List(image);
    if (pixels == null) {
      return null;
    }

    return FillImageData(
      pixels: pixels,
      width: image.width,
      height: image.height,
    );
  }
}
