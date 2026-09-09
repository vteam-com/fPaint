// ignore: fcheck_one_class_per_file
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/halftone_fill.dart';
import 'package:fpaint/models/hatch_pattern.dart';
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
/// via `WandSelectionManager`'s cached signature, but this relies on pixels remaining unchanged.
class FillImageData {
  const FillImageData({
    required this.pixels,
    required this.width,
    required this.height,
    this.canvasScaleX = AppVisual.full,
    this.canvasScaleY = AppVisual.full,
  });

  /// Raster bytes in RGBA format. Must not be modified after construction.
  final Uint8List pixels;

  /// Width of the raster in pixels.
  final int width;

  /// Height of the raster in pixels.
  final int height;

  /// Raster-to-canvas scale on the horizontal axis.
  final double canvasScaleX;

  /// Raster-to-canvas scale on the vertical axis.
  final double canvasScaleY;
}

/// Builds fill actions from image-based flood-fill regions.
class FillService {
  /// Returns an empty fill action used when flood fill cannot resolve a region.
  UserActionDrawing _buildEmptyFloodFillAction() {
    return NonRenderingAction(action: ActionType.fill);
  }

  /// Performs a flood fill with a solid color. Pass [imageData] (cached RGBA
  /// bytes) to skip the readback during live previews, or [sourceImage] otherwise.
  Future<UserActionDrawing> createFloodFillSolidAction({
    required Offset position,
    required Color fillColor,
    ui.Image? sourceImage,
    FillImageData? imageData,
    Color? halftoneDotColor,
    double? halftoneMaxDotSizeFactor,
    HatchPattern? hatchPattern,
    required int tolerance,
    required Path? clipPath,
    Path? regionPathOverride,
  }) async {
    final ui.Path path = await _resolveFloodFillPath(
      sourceImage: sourceImage,
      imageData: imageData,
      position: position,
      tolerance: tolerance,
      regionPathOverride: regionPathOverride,
    );

    return buildSolidFillActionForPath(
      path: path,
      fillColor: fillColor,
      halftoneDotColor: halftoneDotColor,
      halftoneMaxDotSizeFactor: halftoneMaxDotSizeFactor,
      hatchPattern: hatchPattern,
      clipPath: clipPath,
    );
  }

  /// Builds a solid fill action for an already-resolved region [path], skipping
  /// the flood-fill readback — cheap enough to call live while dragging.
  /// [hatchPattern] draws the region as hatch lines in [fillColor] when set.
  UserActionDrawing buildSolidFillActionForPath({
    required ui.Path path,
    required Color fillColor,
    Color? halftoneDotColor,
    double? halftoneMaxDotSizeFactor,
    HatchPattern? hatchPattern,
    required Path? clipPath,
  }) {
    final ui.Rect bounds = path.getBounds();

    return RegionAction(
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
      hatchPattern: hatchPattern,
      clipPath: clipPath,
    );
  }

  /// The canvas-space point at which a gradient flood fill is seeded, derived
  /// from the current handles: the first handle for radial, the midpoint between
  /// handles for linear.
  Offset gradientFloodFillStartPoint(
    FillModel fillModel,
    Offset Function(Offset) toCanvas,
  ) {
    return fillModel.mode == FillMode.radial
        ? toCanvas(fillModel.gradientPoints.first.offset)
        : toCanvas(fillModel.centerPoint);
  }

  /// Performs a flood fill with a gradient. Pass [imageData] (cached RGBA bytes)
  /// to skip the readback during live previews, or [sourceImage] otherwise.
  Future<UserActionDrawing> createFloodFillGradientAction({
    required FillModel fillModel,
    required int tolerance,
    required Path? clipPath,
    required Offset Function(Offset) toCanvas,
    ui.Image? sourceImage,
    FillImageData? imageData,
    Path? regionPathOverride,
  }) async {
    if (!_hasUsableGradientConfiguration(fillModel)) {
      return _buildEmptyFloodFillAction();
    }

    final ui.Path path = await _resolveFloodFillPath(
      sourceImage: sourceImage,
      imageData: imageData,
      position: gradientFloodFillStartPoint(fillModel, toCanvas),
      tolerance: tolerance,
      regionPathOverride: regionPathOverride,
    );

    return buildGradientFillActionForPath(
      path: path,
      fillModel: fillModel,
      toCanvas: toCanvas,
      clipPath: clipPath,
    );
  }

  /// Builds a gradient fill action for an already-resolved region [path],
  /// skipping the flood-fill readback — cheap enough to call live while dragging.
  /// Returns an empty (path-less) action when the region or config is unusable.
  UserActionDrawing buildGradientFillActionForPath({
    required ui.Path path,
    required FillModel fillModel,
    required Offset Function(Offset) toCanvas,
    required Path? clipPath,
  }) {
    if (!_hasUsableGradientConfiguration(fillModel)) {
      return _buildEmptyFloodFillAction();
    }

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

    return RegionAction(
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
  /// from the raster flood-fill region sampled at [position]. Prefers
  /// [imageData] (cached RGBA bytes — no readback) over [sourceImage].
  Future<ui.Path> _resolveFloodFillPath({
    ui.Image? sourceImage,
    FillImageData? imageData,
    required Offset position,
    required int tolerance,
    required Path? regionPathOverride,
  }) async {
    if (regionPathOverride != null) {
      return Path.from(regionPathOverride);
    }

    final FillRegion region = await getRegionPathFromImage(
      image: sourceImage,
      imageData: imageData,
      position: position,
      tolerance: tolerance,
    );

    return region.path.shift(region.offset);
  }

  /// Builds the gradient geometry used by smooth and halftone flood fills.
  Gradient _buildFloodFillGradient({
    required ui.Rect bounds,
    required FillModel fillModel,
    required Offset Function(Offset) toCanvas,
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
  bool _hasUsableGradientConfiguration(FillModel fillModel) {
    final int pointCount = fillModel.gradientPoints.length;
    final int colorCount = fillModel.gradientStopColors.length;
    final int stopCount = fillModel.gradientStopPositions.length;
    return pointCount >= AppMath.two && colorCount >= FillModel.gradientStopMin && stopCount == colorCount;
  }

  /// Converts an absolute [point] inside [bounds] into a gradient alignment.
  Alignment _pointToBoundsAlignment({
    required ui.Rect bounds,
    required ui.Offset point,
  }) {
    return Alignment(
      ((point.dx - bounds.left) / bounds.width) * AppMath.pair - AppVisual.full,
      ((point.dy - bounds.top) / bounds.height) * AppMath.pair - AppVisual.full,
    );
  }

  /// Gets the region path from a layer image.
  Future<FillRegion> getRegionPathFromImage({
    ui.Image? image,
    required ui.Offset position,
    required int tolerance,
    FillImageData? imageData,
  }) async {
    // Guard against NaN or infinite coordinates
    if (position.dx.isNaN || position.dy.isNaN || position.dx.isInfinite || position.dy.isInfinite) {
      return FillRegion(path: ui.Path(), offset: ui.Offset.zero);
    }

    final FillImageData? source = imageData ?? await _buildFillImageData(image);
    if (source == null) {
      return FillRegion(path: ui.Path(), offset: ui.Offset.zero);
    }

    final int x = (position.dx * source.canvasScaleX).toInt();
    final int y = (position.dy * source.canvasScaleY).toInt();

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
    if (source.canvasScaleX == AppVisual.full && source.canvasScaleY == AppVisual.full) {
      return FillRegion(path: region.path, offset: region.offset);
    }

    final ui.Path canvasPath = region.path.transform(
      (Matrix4.identity()..scaleByDouble(
            AppVisual.full / source.canvasScaleX,
            AppVisual.full / source.canvasScaleY,
            AppVisual.full,
            AppVisual.full,
          ))
          .storage,
    );
    return FillRegion(
      path: canvasPath,
      offset: ui.Offset(
        region.offset.dx / source.canvasScaleX,
        region.offset.dy / source.canvasScaleY,
      ),
    );
  }

  /// Builds a reusable flood-fill raster payload from [image].
  Future<FillImageData?> _buildFillImageData(ui.Image? image) async {
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
