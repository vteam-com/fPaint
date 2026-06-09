import 'dart:math';
import 'dart:ui' as ui;

import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/layer_provider.dart';

/// Export-oriented raster helpers for [LayerProvider].
extension LayerProviderStorageExport on LayerProvider {
  /// Estimates conservative content bounds for export and storage snapshots.
  ///
  /// The returned rectangle is guaranteed to stay within the canvas. When the
  /// layer has no visible content, this falls back to a minimal transparent
  /// export rect so save paths do not need to rasterize the full canvas.
  ui.Rect estimateContentBoundsForStorage() {
    final ui.Rect canvasRect = ui.Offset.zero & size;
    if (backgroundColor != null) {
      return canvasRect;
    }

    ui.Rect? estimatedBounds;
    for (final UserActionDrawing userAction in actionStack) {
      final ui.Rect? actionBounds = _estimateActionBoundsForStorage(userAction);
      if (actionBounds == null || actionBounds.isEmpty) {
        continue;
      }

      estimatedBounds = estimatedBounds == null ? actionBounds : estimatedBounds.expandToInclude(actionBounds);
    }

    if (estimatedBounds == null) {
      return _minimumStorageBounds();
    }

    final ui.Rect clippedBounds = estimatedBounds.intersect(canvasRect);
    if (clippedBounds.isEmpty) {
      return _minimumStorageBounds();
    }

    return _normalizeStorageBounds(clippedBounds);
  }

  /// Renders the layer directly into [bounds] for cropped export snapshots.
  ui.Image toImageForStorageBounds(final ui.Rect bounds) {
    final ui.Rect normalizedBounds = _normalizeStorageBounds(bounds);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder)..translate(-normalizedBounds.left, -normalizedBounds.top);

    renderLayer(canvas);

    final ui.Picture picture = recorder.endRecording();
    return picture.toImageSync(
      max(normalizedBounds.width.ceil(), AppMath.one),
      max(normalizedBounds.height.ceil(), AppMath.one),
    );
  }

  /// Returns a conservative export-bounds estimate for [userAction].
  ui.Rect? _estimateActionBoundsForStorage(final UserActionDrawing userAction) {
    switch (userAction.action) {
      case ActionType.pencil:
      case ActionType.brush:
      case ActionType.eraser:
      case ActionType.line:
        final MyBrush? brush = userAction.brush;
        if (brush == null) {
          return null;
        }
        return _estimateBoundsFromPositions(
          positions: userAction.positions,
          outset: _estimateStrokeOutset(brush),
        );

      case ActionType.circle:
      case ActionType.rectangle:
        final MyBrush? brush = userAction.brush;
        if (brush == null || userAction.positions.isEmpty) {
          return null;
        }
        final ui.Offset start = userAction.positions.first;
        final ui.Offset end = userAction.positions.length > AppMath.one
            ? userAction.positions.last
            : userAction.positions.first;
        return ui.Rect.fromPoints(start, end).inflate(_estimateStrokeOutset(brush));

      case ActionType.region:
      case ActionType.cut:
        return userAction.path?.getBounds();

      case ActionType.image:
      case ActionType.smudge:
      case ActionType.blurBrush:
        final ui.Image? image = userAction.image;
        if (image == null || userAction.positions.isEmpty) {
          return null;
        }
        final ui.Offset origin = userAction.positions.first;
        return ui.Rect.fromLTWH(
          origin.dx,
          origin.dy,
          image.width.toDouble(),
          image.height.toDouble(),
        );

      case ActionType.text:
        return userAction.textObject?.getBounds();

      case ActionType.fill:
      case ActionType.selector:
        return null;
    }
  }

  /// Returns the bounds of [positions], inflated by [outset] for stroke width.
  ui.Rect? _estimateBoundsFromPositions({
    required final List<ui.Offset> positions,
    required final double outset,
  }) {
    if (positions.isEmpty) {
      return null;
    }

    double minX = positions.first.dx;
    double minY = positions.first.dy;
    double maxX = positions.first.dx;
    double maxY = positions.first.dy;

    for (final ui.Offset position in positions.skip(AppMath.one)) {
      minX = min(minX, position.dx);
      minY = min(minY, position.dy);
      maxX = max(maxX, position.dx);
      maxY = max(maxY, position.dy);
    }

    return ui.Rect.fromLTRB(minX, minY, maxX, maxY).inflate(outset);
  }

  /// Estimates the maximum painted distance from a stroke path for [brush].
  double _estimateStrokeOutset(final MyBrush brush) {
    switch (brush.style) {
      case BrushStyle.slash:
        return brush.size * AppStroke.dashWidthFactor * AppVisual.half;
      case BrushStyle.solid:
      case BrushStyle.dash:
      case BrushStyle.dotted:
      case BrushStyle.dashDot:
        return brush.size * AppVisual.half;
    }
  }

  /// Rounds [bounds] outward to integer pixel edges for raster export.
  ui.Rect _normalizeStorageBounds(final ui.Rect bounds) {
    return ui.Rect.fromLTRB(
      bounds.left.floorToDouble(),
      bounds.top.floorToDouble(),
      bounds.right.ceilToDouble(),
      bounds.bottom.ceilToDouble(),
    );
  }

  /// Returns a minimal transparent export rect for empty layers.
  ui.Rect _minimumStorageBounds() {
    return ui.Rect.fromLTWH(
      AppMath.zero.toDouble(),
      AppMath.zero.toDouble(),
      AppVisual.full,
      AppVisual.full,
    );
  }
}
