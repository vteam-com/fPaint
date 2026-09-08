import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/providers/fill_service.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/wand_selection_manager_cache.dart';
import 'package:fpaint/providers/wand_source_sampler.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/layers_provider_test_helper.dart';

/// A cache that records what the sampler stores and can be primed with a hit.
class _RecordingCache implements WandSourceCache {
  FillImageData? primed;
  int? primedSignature;
  int lookups = 0;
  int stores = 0;
  int? lastStoredSignature;
  int? lastStoredWidth;
  int? lastStoredHeight;

  @override
  FillImageData? cachedImageData(int signature) {
    lookups++;
    return signature == primedSignature ? primed : null;
  }

  @override
  void storeCache({
    required int signature,
    required Uint8List pixels,
    required int width,
    required int height,
    double canvasScaleX = AppVisual.full,
    double canvasScaleY = AppVisual.full,
  }) {
    stores++;
    lastStoredSignature = signature;
    lastStoredWidth = width;
    lastStoredHeight = height;
  }
}

void main() {
  group('WandSourceSampler.sourceSignature', () {
    test('is stable for an unchanged layer stack', () {
      final LayersProvider layers = createInitializedLayersProvider();
      final WandSourceSampler sampler = WandSourceSampler(_RecordingCache());

      expect(
        sampler.sourceSignature(layers, sampleAllLayers: false),
        sampler.sourceSignature(layers, sampleAllLayers: false),
      );
    });

    test('differs between single-layer and all-layer sampling', () {
      final LayersProvider layers = createInitializedLayersProvider();
      final WandSourceSampler sampler = WandSourceSampler(_RecordingCache());

      expect(
        sampler.sourceSignature(layers, sampleAllLayers: false),
        isNot(sampler.sourceSignature(layers, sampleAllLayers: true)),
      );
    });

    test('changes when the canvas is resized', () {
      final LayersProvider layers = createInitializedLayersProvider();
      final WandSourceSampler sampler = WandSourceSampler(_RecordingCache());
      final int before = sampler.sourceSignature(layers, sampleAllLayers: false);

      layers.size = const Size(400, 300);

      expect(sampler.sourceSignature(layers, sampleAllLayers: false), isNot(before));
    });

    // Regression: renderLayer bakes opacity and blend mode into the sampled
    // pixels and paints backgroundColor beneath the action stack, but none of
    // the three were hashed, so the wand and paint bucket sampled stale pixels
    // after any compositing change. Each is checked in BOTH sampling modes —
    // isVisible used to be covered only under all-layer sampling.
    for (final bool sampleAllLayers in <bool>[false, true]) {
      final String mode = sampleAllLayers ? 'all-layer' : 'single-layer';

      test('changes when layer opacity changes under $mode sampling', () {
        final LayersProvider layers = createInitializedLayersProvider();
        final WandSourceSampler sampler = WandSourceSampler(_RecordingCache());
        final int before = sampler.sourceSignature(layers, sampleAllLayers: sampleAllLayers);

        layers.selectedLayer.opacity = 0.3;

        expect(sampler.sourceSignature(layers, sampleAllLayers: sampleAllLayers), isNot(before));
      });

      test('changes when layer blend mode changes under $mode sampling', () {
        final LayersProvider layers = createInitializedLayersProvider();
        final WandSourceSampler sampler = WandSourceSampler(_RecordingCache());
        final int before = sampler.sourceSignature(layers, sampleAllLayers: sampleAllLayers);

        layers.selectedLayer.blendMode = BlendMode.multiply;

        expect(sampler.sourceSignature(layers, sampleAllLayers: sampleAllLayers), isNot(before));
      });

      test('changes when layer background color changes under $mode sampling', () {
        final LayersProvider layers = createInitializedLayersProvider();
        final WandSourceSampler sampler = WandSourceSampler(_RecordingCache());
        final int before = sampler.sourceSignature(layers, sampleAllLayers: sampleAllLayers);

        layers.selectedLayer.backgroundColor = Colors.red;

        expect(sampler.sourceSignature(layers, sampleAllLayers: sampleAllLayers), isNot(before));
      });

      test('changes when layer visibility changes under $mode sampling', () {
        final LayersProvider layers = createInitializedLayersProvider();
        final WandSourceSampler sampler = WandSourceSampler(_RecordingCache());
        final int before = sampler.sourceSignature(layers, sampleAllLayers: sampleAllLayers);

        layers.selectedLayer.isVisible = false;

        expect(sampler.sourceSignature(layers, sampleAllLayers: sampleAllLayers), isNot(before));
      });
    }

    test('changes when a layer is added under all-layer sampling', () {
      final LayersProvider layers = createInitializedLayersProvider();
      final WandSourceSampler sampler = WandSourceSampler(_RecordingCache());
      final int before = sampler.sourceSignature(layers, sampleAllLayers: true);

      layers.addTop(name: 'Extra');

      expect(sampler.sourceSignature(layers, sampleAllLayers: true), isNot(before));
    });

    test('is stable across calls under all-layer sampling', () {
      // Regression: the per-layer digests were passed to Object.hash as a List,
      // which hashes by identity, so every call produced a new signature and the
      // all-layers source cache never hit.
      final LayersProvider layers = createInitializedLayersProvider();
      layers.addTop(name: 'Extra');
      final WandSourceSampler sampler = WandSourceSampler(_RecordingCache());

      expect(
        sampler.sourceSignature(layers, sampleAllLayers: true),
        sampler.sourceSignature(layers, sampleAllLayers: true),
      );
    });

    test('changes when a layer visibility toggles under all-layer sampling', () {
      final LayersProvider layers = createInitializedLayersProvider();
      layers.addTop(name: 'Extra');
      final WandSourceSampler sampler = WandSourceSampler(_RecordingCache());
      final int before = sampler.sourceSignature(layers, sampleAllLayers: true);

      layers.layersToggleVisibility(layers.get(0));

      expect(sampler.sourceSignature(layers, sampleAllLayers: true), isNot(before));
    });
  });

  group('WandSourceSampler.sample', () {
    test('rasterizes and stores under the matching signature', () async {
      final LayersProvider layers = createInitializedLayersProvider(size: const Size(64, 48));
      final _RecordingCache cache = _RecordingCache();
      final WandSourceSampler sampler = WandSourceSampler(cache);

      final FillImageData? data = await sampler.sample(layers, sampleAllLayers: false);

      expect(data, isNotNull);
      expect(cache.stores, 1);
      expect(
        cache.lastStoredSignature,
        sampler.sourceSignature(layers, sampleAllLayers: false),
      );
      expect(data!.width, 64);
      expect(data.height, 48);
      expect(data.canvasScaleX, closeTo(1.0, 0.001));
      expect(data.pixels, isNotEmpty);
    });

    test('returns the cached data without re-rasterizing on a hit', () async {
      final LayersProvider layers = createInitializedLayersProvider(size: const Size(32, 32));
      final _RecordingCache cache = _RecordingCache();
      final WandSourceSampler sampler = WandSourceSampler(cache);
      final FillImageData primed = FillImageData(
        pixels: Uint8List(4),
        width: 1,
        height: 1,
        canvasScaleX: 1,
        canvasScaleY: 1,
      );
      cache
        ..primed = primed
        ..primedSignature = sampler.sourceSignature(layers, sampleAllLayers: false);

      final FillImageData? data = await sampler.sample(layers, sampleAllLayers: false);

      expect(identical(data, primed), isTrue);
      expect(cache.stores, 0, reason: 'a cache hit must not re-rasterize');
    });

    test('downscales a canvas larger than the sampling budget', () async {
      const int oversized = AppLimits.floodFillSourceMaxDimension * 2;
      final LayersProvider layers = createInitializedLayersProvider(
        size: Size(oversized.toDouble(), oversized / 2),
      );
      final _RecordingCache cache = _RecordingCache();
      final WandSourceSampler sampler = WandSourceSampler(cache);

      final FillImageData? data = await sampler.sample(layers, sampleAllLayers: false);

      expect(data, isNotNull);
      expect(data!.width, AppLimits.floodFillSourceMaxDimension);
      expect(data.height, oversized ~/ 4);
      // The scale maps canvas coordinates onto the reduced raster.
      expect(data.canvasScaleX, closeTo(0.5, 0.01));
      expect(data.canvasScaleY, closeTo(0.5, 0.01));
    });

    test('samples every visible layer when asked for all layers', () async {
      final LayersProvider layers = createInitializedLayersProvider(size: const Size(32, 32));
      layers.addTop(name: 'Extra');
      final _RecordingCache cache = _RecordingCache();
      final WandSourceSampler sampler = WandSourceSampler(cache);
      final int signature = sampler.sourceSignature(layers, sampleAllLayers: true);

      final FillImageData? data = await sampler.sample(layers, sampleAllLayers: true);

      expect(data, isNotNull);
      expect(cache.lastStoredSignature, signature);
    });
  });
}
