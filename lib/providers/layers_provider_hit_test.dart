part of 'layers_provider.dart';

/// Region-bounded rendering behind the layer hit-test and region captures.
///
/// Kept as a part-file extension, like [LayersProviderCanvasGeometry], so the
/// stack owner stays under fCheck's per-class LOC limit.
extension LayersProviderHitTest on LayersProvider {
  /// Renders [layersBottomFirst] over [region] (canvas coordinates) into a
  /// region-sized image.
  ///
  /// The canvas is clipped to [region] and the region is passed as each
  /// layer's composite bounds. Without that, a recorder canvas has an unbounded
  /// cull rect, so every layer that falls off its cached-raster fast path
  /// (always the case once the display-res projection replaces the full-res
  /// cache) opens a *full-canvas* `saveLayer` — hundreds of MB per layer on a
  /// large document even when only one pixel is read back.
  Future<ui.Image> _renderLayersInRegion(ui.Rect region, Iterable<LayerProvider> layersBottomFirst) {
    return renderCanvasImage(
      width: region.width.toInt(),
      height: region.height.toInt(),
      draw: (ui.Canvas canvas) {
        canvas.translate(-region.left, -region.top);
        canvas.clipRect(region);
        for (final LayerProvider layer in layersBottomFirst) {
          layer.renderLayer(canvas, compositeBounds: region);
        }
      },
    );
  }

  /// Composites every visible layer below [index] (exclusive) over [region] and
  /// returns the resulting pixel, or null when it cannot be read.
  ///
  /// The stack is ordered top-first, so "below [index]" is indices after it.
  /// Passing [length] composites nothing and yields the empty pixel.
  Future<Color?> _compositePixelBelow(int index, ui.Rect region) async {
    final ui.Image sample = await this._renderLayersInRegion(region, this._visibleLayersBottomFirst(from: index));
    try {
      final ByteData? byteData = await sample.toByteData(format: ui.ImageByteFormat.rawRgba);
      return byteData == null ? null : _colorAtPixelIndex(byteData, 0);
    } finally {
      sample.dispose();
    }
  }

  /// The visible layers at [from] and below it, bottom-first (compositing
  /// order). [from] defaults to the top of the stack, i.e. every visible layer.
  List<LayerProvider> _visibleLayersBottomFirst({int from = AppMath.zero}) {
    return <LayerProvider>[
      for (int i = length - 1; i >= from; i--)
        if (get(i).isVisible) get(i),
    ];
  }

  /// The one-pixel canvas rect containing canvas [offset].
  ui.Rect _pixelRectAt(Offset offset) {
    return ui.Rect.fromLTWH(
      offset.dx.floorToDouble(),
      offset.dy.floorToDouble(),
      AppMath.one.toDouble(),
      AppMath.one.toDouble(),
    );
  }

  /// Resolves [pickPixelAt] for the one-pixel canvas rect [pixel] with a
  /// single render and a single readback.
  ///
  /// Each visible layer's contribution at [pixel] is recorded once as a
  /// picture. Column `c` of a `(visible + 1)`-pixel strip then composites the
  /// bottom `c` of those pictures, so column 0 is the empty canvas and the last
  /// column is the full composite. The topmost layer whose column differs from
  /// the one before it owns the pixel. Rendering and reading back one composite
  /// per layer instead cost a GPU round trip each, which kept the picker loupe
  /// from appearing for seconds on many-layer documents.
  Future<LayerPixelPick> _pickPixelInOnePass(ui.Rect pixel) async {
    final List<LayerProvider> layersBottomFirst = this._visibleLayersBottomFirst();
    final List<ui.Picture> contributions = <ui.Picture>[
      for (final LayerProvider layer in layersBottomFirst) _recordLayerAtPixel(layer, pixel),
    ];
    try {
      final ui.Image strip = await renderCanvasImage(
        width: contributions.length + AppMath.one,
        height: AppMath.one,
        draw: (ui.Canvas canvas) {
          for (int column = AppMath.one; column <= contributions.length; column++) {
            canvas.save();
            canvas.translate(column.toDouble(), AppMath.zero.toDouble());
            canvas.clipRect(ui.Offset.zero & pixel.size);
            for (int below = AppMath.zero; below < column; below++) {
              canvas.drawPicture(contributions[below]);
            }
            canvas.restore();
          }
        },
      );
      final ByteData? bytes;
      try {
        bytes = await strip.toByteData(format: ui.ImageByteFormat.rawRgba);
      } finally {
        strip.dispose();
      }
      if (bytes == null) {
        return (owningLayer: null, color: null);
      }

      LayerProvider? owningLayer;
      Color previous = _colorAtPixelIndex(bytes, AppMath.zero);
      for (int column = AppMath.one; column <= contributions.length; column++) {
        final Color current = _colorAtPixelIndex(bytes, column * AppMath.bytesPerPixel);
        if (current != previous) {
          owningLayer = layersBottomFirst[column - AppMath.one];
        }
        previous = current;
      }
      return (owningLayer: owningLayer, color: previous);
    } finally {
      for (final ui.Picture contribution in contributions) {
        contribution.dispose();
      }
    }
  }

  /// Records [layer] (with its blend mode and opacity) clipped to [pixel],
  /// shifted so the pixel lands at the origin.
  ui.Picture _recordLayerAtPixel(LayerProvider layer, ui.Rect pixel) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.translate(-pixel.left, -pixel.top);
    canvas.clipRect(pixel);
    layer.renderLayer(canvas, compositeBounds: pixel);
    return recorder.endRecording();
  }
}
