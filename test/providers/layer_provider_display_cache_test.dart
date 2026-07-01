import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/layer_provider.dart';

const int _canvasWidth = 64;
const int _canvasHeight = 48;
const Size _canvasSize = Size(64, 48);
const double _displayScale = 0.5;
const double _patchSide = 20;

LayerProvider _layer({
  final Size size = _canvasSize,
  final void Function() onThumbnailChanged = _noop,
}) => LayerProvider(name: 'L', size: size, onThumbnailChanged: onThumbnailChanged);

void _noop() {}

Future<ui.Image> _solid(
  final Color color, {
  final int width = _canvasWidth,
  final int height = _canvasHeight,
}) => renderCanvasImage(
  width: width,
  height: height,
  draw: (final ui.Canvas canvas) =>
      canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = color),
);

UserActionDrawing _imageAction(final ui.Image image) => UserActionDrawing(
  action: ActionType.image,
  positions: <Offset>[Offset.zero, Offset(image.width.toDouble(), image.height.toDouble())],
  image: image,
);

UserActionDrawing _textAction() => UserActionDrawing(
  action: ActionType.text,
  positions: const <Offset>[Offset(4, 4)],
  textObject: TextObject(
    text: 'fPaint',
    position: const Offset(4, 4),
    color: const Color(0xFF012B08),
    size: 12,
  ),
);

/// Renders [layer] for display at [scale] into a throwaway target and returns
/// how many times a cache rebuild was requested during the paint.
Future<int> _renderForDisplay(final LayerProvider layer, final double scale) async {
  int rebuilds = 0;
  final ui.Image out = await renderCanvasImage(
    width: _canvasWidth,
    height: _canvasHeight,
    draw: (final ui.Canvas canvas) => layer.renderLayerForDisplay(canvas, scale, () => rebuilds++),
  );
  out.dispose();
  return rebuilds;
}

/// Alpha of a fully opaque channel byte.
const int _fullyOpaqueAlpha = 255;

/// Renders [layer] for display at [scale] and returns the minimum alpha byte
/// across all pixels — used to detect a transparent seam.
Future<int> _minDisplayAlpha(final LayerProvider layer, final double scale) async {
  final ui.Image out = await renderCanvasImage(
    width: _canvasWidth,
    height: _canvasHeight,
    draw: (final ui.Canvas canvas) => layer.renderLayerForDisplay(canvas, scale, () {}),
  );
  final ByteData? bytes = await out.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  out.dispose();
  int minAlpha = _fullyOpaqueAlpha;
  for (int i = 3; i < bytes!.lengthInBytes; i += 4) {
    final int alpha = bytes.getUint8(i);
    if (alpha < minAlpha) {
      minAlpha = alpha;
    }
  }
  return minAlpha;
}

/// Folds an opaque patch covering [patchBounds] into a fully opaque layer's
/// display cache (built at [scale]) and returns the minimum alpha of the
/// re-rendered display. A fully opaque layer + opaque patch must stay opaque
/// everywhere; any value below [_fullyOpaqueAlpha] is a transparent seam.
Future<int> _foldedPatchMinDisplayAlpha(final Rect patchBounds, final double scale) async {
  final LayerProvider layer = _layer();
  layer.actionStack.add(_imageAction(await _solid(const Color(0xFF00AA00))));
  await layer.buildDisplayCache(scale);
  final ui.Image patch = await _solid(
    const Color(0xFFFF0000),
    width: patchBounds.width.toInt(),
    height: patchBounds.height.toInt(),
  );
  await layer.updateDisplayCacheWithPatch(patchImage: patch, patchBounds: patchBounds);
  patch.dispose();
  return _minDisplayAlpha(layer, scale);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LayerDisplayCache', () {
    test('supportsIncrementalPixelBrushCache reflects opacity and blend mode', () {
      final LayerProvider layer = _layer();
      expect(layer.supportsIncrementalPixelBrushCache, isTrue);

      layer.opacity = 0.5;
      expect(layer.supportsIncrementalPixelBrushCache, isFalse);

      layer.opacity = 1.0;
      layer.blendMode = ui.BlendMode.multiply;
      expect(layer.supportsIncrementalPixelBrushCache, isFalse);
    });

    test('a sufficient display cache is drawn without requesting a rebuild', () async {
      final LayerProvider layer = _layer();
      layer.actionStack.add(_imageAction(await _solid(const Color(0xFF00FF00))));

      await layer.buildDisplayCache(_displayScale);

      expect(await _renderForDisplay(layer, _displayScale), 0);
    });

    test('a missing cache renders full-res and requests one rebuild', () async {
      final LayerProvider layer = _layer();
      layer.actionStack.add(_imageAction(await _solid(const Color(0xFF0000FF))));

      expect(await _renderForDisplay(layer, _displayScale), 1);
    });

    test('a text layer is excluded from the display cache and never requests a rebuild', () async {
      final LayerProvider layer = _layer();
      layer.actionStack.add(_textAction());

      // Text must rasterize through the live (font-loaded) paint pass, not a
      // downscaled projection built off the main paint — otherwise glyphs can
      // render as empty boxes. So a text layer always renders full-res and never
      // asks for a display-cache rebuild (unlike the image layer above).
      expect(await _renderForDisplay(layer, _displayScale), 0);

      // Even if a cache was somehow built, it must not be drawn for text.
      await layer.buildDisplayCache(_displayScale);
      expect(await _renderForDisplay(layer, _displayScale), 0);
    });

    test('invalidateDisplayCache forces a rebuild on the next display render', () async {
      final LayerProvider layer = _layer();
      layer.actionStack.add(_imageAction(await _solid(const Color(0xFF00FF00))));
      await layer.buildDisplayCache(_displayScale);

      layer.invalidateDisplayCache();

      expect(await _renderForDisplay(layer, _displayScale), 1);
    });

    test('updateDisplayCacheWithPatch folds a patch into an existing cache', () async {
      final LayerProvider layer = _layer();
      layer.actionStack.add(_imageAction(await _solid(const Color(0xFF00FF00))));
      await layer.buildDisplayCache(_displayScale);

      final ui.Image patch = await _solid(
        const Color(0xFFFF0000),
        width: _patchSide.toInt(),
        height: _patchSide.toInt(),
      );
      await layer.updateDisplayCacheWithPatch(
        patchImage: patch,
        patchBounds: const Rect.fromLTWH(0, 0, _patchSide, _patchSide),
      );
      patch.dispose();

      // The cache is still present and sufficient, so no rebuild is requested.
      expect(await _renderForDisplay(layer, _displayScale), 0);
    });

    test('folding a patch never leaves a transparent seam around the patch bounds', () async {
      // Regression guard for the "white rectangle around the blur/smudge stroke":
      // updateDisplayCacheWithPatch erases (anti-aliased clear) then redraws the
      // patch. When the patch bounds scaled into the display cache landed off
      // pixel boundaries, the clear feathered ~1px wider than the redraw covered,
      // leaving a transparent ring the canvas backdrop showed through as white.
      //
      // The seam magnitude depends on the sub-pixel fraction of the scaled edges,
      // so sweep several scales and offsets: an opaque layer + opaque patch must
      // stay fully opaque (no alpha < 255) in every case.
      const List<Rect> boundsCases = <Rect>[
        Rect.fromLTWH(11, 11, 22, 16),
        Rect.fromLTWH(7, 5, 19, 21),
        Rect.fromLTWH(9, 13, 25, 17),
        Rect.fromLTWH(3, 7, 30, 27),
        Rect.fromLTWH(5, 9, 21, 23),
      ];
      const List<double> scaleCases = <double>[0.5, 0.375, 0.6, 0.7];

      for (final double scale in scaleCases) {
        for (final Rect bounds in boundsCases) {
          expect(
            await _foldedPatchMinDisplayAlpha(bounds, scale),
            _fullyOpaqueAlpha,
            reason: 'transparent seam for bounds=$bounds scale=$scale',
          );
        }
      }
    });

    test('a committed smudge/blur patch replaces its region (src), not composites (srcOver)', () async {
      // The patch holds the final content for its region, so smudge/blurBrush
      // renders it with BlendMode.src (replace) — including alpha, so a fully
      // transparent patch punches through instead of letting the layer below
      // show. srcOver (the old behaviour, which required a separate `cut`) would
      // leave the opaque base visible; src replaces cleanly and needs no cut,
      // which is what removes the fractional-scale white-rectangle seam.
      final LayerProvider layer = _layer();
      layer.actionStack.add(_imageAction(await _solid(const Color(0xFF00AA00))));
      final ui.Image transparentPatch = await _solid(const Color(0x00000000), width: 20, height: 20);
      layer.actionStack.add(
        UserActionDrawing(
          action: ActionType.blurBrush,
          positions: const <Offset>[Offset(10, 10), Offset(30, 30)],
          image: transparentPatch,
        ),
      );

      final ui.Image out = await renderCanvasImage(
        width: _canvasWidth,
        height: _canvasHeight,
        draw: (final ui.Canvas canvas) => layer.renderLayer(canvas),
      );
      final ByteData? bytes = await out.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      out.dispose();
      // Centre of the patch (20, 20) must be transparent — src replaced the base.
      final int centreAlpha = bytes!.getUint8((((20 * _canvasWidth) + 20) * 4) + 3);
      expect(centreAlpha, 0, reason: 'src patch must replace its region, including transparency');
    });

    test('updateDisplayCacheWithPatch is a no-op when there is no cache yet', () async {
      final LayerProvider layer = _layer();
      final ui.Image patch = await _solid(
        const Color(0xFFFF0000),
        width: _patchSide.toInt(),
        height: _patchSide.toInt(),
      );

      await layer.updateDisplayCacheWithPatch(
        patchImage: patch,
        patchBounds: const Rect.fromLTWH(0, 0, _patchSide, _patchSide),
      );
      patch.dispose();

      // With no cache built, the next display render still asks for a rebuild.
      layer.actionStack.add(_imageAction(await _solid(const Color(0xFF00FF00))));
      expect(await _renderForDisplay(layer, _displayScale), 1);
    });

    test('ensureCachePrimed is idempotent and re-primes after invalidation', () async {
      final LayerProvider layer = _layer();
      layer.actionStack.add(_imageAction(await _solid(const Color(0xFF00FF00))));

      await layer.ensureCachePrimed();
      await layer.ensureCachePrimed(); // no-op: already primed
      layer.invalidateFullResCache();
      await layer.ensureCachePrimed(); // re-primes

      expect(layer.size, _canvasSize);
    });

    test('buildDisplayCache caps the projection scale for very large canvases', () async {
      // longestSide (3000) * requiredScale (1.0) exceeds the display-cache side
      // budget, so the builder must clamp instead of caching at full res.
      final LayerProvider layer = _layer(size: const Size(3000, 2000));
      layer.actionStack.add(_imageAction(await _solid(const Color(0xFF00FF00))));

      await layer.buildDisplayCache(1.0);

      // The capped cache is treated as sufficient for the (unreachable) 1.0
      // request, so no perpetual rebuild is requested.
      int rebuilds = 0;
      final ui.Image out = await renderCanvasImage(
        width: _canvasWidth,
        height: _canvasHeight,
        draw: (final ui.Canvas canvas) => layer.renderLayerForDisplay(canvas, 1.0, () => rebuilds++),
      );
      out.dispose();
      expect(rebuilds, 0);
    });

    test('refreshThumbnailFromDisplayCache rebuilds the panel thumbnail from the cache', () async {
      bool thumbnailChanged = false;
      final LayerProvider layer = _layer(onThumbnailChanged: () => thumbnailChanged = true);
      layer.actionStack.add(_imageAction(await _solid(const Color(0xFF00FF00))));
      await layer.buildDisplayCache(_displayScale);

      layer.refreshThumbnailFromDisplayCache();
      // Debounced by AppDefaults.debounceDuration (1s); wait past it and let the
      // async thumbnail render settle.
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      expect(thumbnailChanged, isTrue);
    });

    test('refreshThumbnailFromDisplayCache is a no-op without a display cache', () async {
      bool thumbnailChanged = false;
      final LayerProvider layer = _layer(onThumbnailChanged: () => thumbnailChanged = true);

      layer.refreshThumbnailFromDisplayCache();
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      expect(thumbnailChanged, isFalse);
    });
  });
}
