import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/providers/selection_effect_preview_state.dart';

/// Pure image operations behind the selection-effect preview.
///
/// Split out of the provider because none of this needs app state: it maps
/// images and geometry to new images. Keeping it standalone makes the effect
/// pipeline unit-testable without building an [AppProvider], and keeps the
/// provider responsible only for session lifecycle (Single Responsibility).
class SelectionEffectRenderer {
  const SelectionEffectRenderer();

  /// Clips [image] back to [selectionPath] so an effect applied over the
  /// selection's bounding box only shows inside the selection itself.
  Future<ui.Image> maskToSelection(
    ui.Image image, {
    required Path selectionPath,
    required Rect bounds,
    required double pixelScale,
  }) {
    Path localSelectionPath = selectionPath.shift(
      Offset(-bounds.left, -bounds.top),
    );
    if (pixelScale != AppEffects.defaultPixelScale) {
      localSelectionPath = localSelectionPath.transform(
        (Matrix4.identity()..scaleByDouble(pixelScale, pixelScale, 1.0, 1.0)).storage,
      );
    }

    return renderCanvasImage(
      width: image.width,
      height: image.height,
      draw: (ui.Canvas canvas) {
        canvas.save();
        canvas.clipPath(localSelectionPath, doAntiAlias: true);
        canvas.drawImage(image, Offset.zero, ui.Paint());
        canvas.restore();
      },
    );
  }

  /// Applies [state]'s effect and re-masks it to the original selection.
  ///
  /// The caller owns the returned image. [state.sourceImage] is never disposed
  /// here, since the preview retains it across renders.
  Future<ui.Image> buildMaskedImage(SelectionEffectPreviewState state) async {
    final ui.Image processedImage = await state.effect.apply(
      state.sourceImage,
      strength: state.strength,
      size: state.size,
      pixelScale: state.pixelScale,
    );

    // A whole-layer effect's mask is the full-canvas rect, so clipping to it is
    // a no-op that would cost another full-resolution texture and render pass.
    if (state.coversEntireLayer) {
      if (identical(processedImage, state.sourceImage)) {
        // Zero-strength no-op: hand back a copy so the caller can take
        // ownership without freeing the retained source.
        return renderCanvasImage(
          width: processedImage.width,
          height: processedImage.height,
          draw: (ui.Canvas canvas) => canvas.drawImage(processedImage, Offset.zero, ui.Paint()),
        );
      }
      return processedImage;
    }

    final ui.Image maskedImage = await maskToSelection(
      processedImage,
      selectionPath: state.selectionPath,
      bounds: state.bounds,
      pixelScale: state.pixelScale,
    );

    // A zero-strength effect returns its source unchanged; disposing that would
    // destroy the preview's retained source image.
    if (!identical(processedImage, state.sourceImage)) {
      processedImage.dispose();
    }

    return maskedImage;
  }

  /// Builds the downscaled image that live preview renders from.
  ///
  /// Returns [source] itself (scale 1.0) when it already fits the preview
  /// budget, so callers must not dispose the result independently.
  Future<({ui.Image image, double scale})> buildPreviewProxy(ui.Image source) async {
    final int longestSide = source.width > source.height ? source.width : source.height;
    if (longestSide <= AppLimits.effectPreviewMaxDimension) {
      return (image: source, scale: AppEffects.defaultPixelScale);
    }

    final double scale = AppLimits.effectPreviewMaxDimension / longestSide;
    final int proxyWidth = (source.width * scale).round().clamp(AppMath.one, source.width);
    final int proxyHeight = (source.height * scale).round().clamp(AppMath.one, source.height);

    final ui.Image proxy = await renderCanvasImage(
      width: proxyWidth,
      height: proxyHeight,
      draw: (ui.Canvas canvas) {
        canvas.drawImageRect(
          source,
          Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
          Rect.fromLTWH(0, 0, proxyWidth.toDouble(), proxyHeight.toDouble()),
          ui.Paint()..filterQuality = FilterQuality.medium,
        );
      },
    );
    return (image: proxy, scale: scale);
  }
}
