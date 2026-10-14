import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:material_ui/material_ui.dart';

const Size _canvasSize = Size(4, 4);

/// Returns a fresh two-layer stack (top-first: Top(0), Background(1)).
LayersProvider _twoLayerStack() {
  final LayersProvider layers = LayersProvider();
  layers.clear();
  layers.size = _canvasSize;
  layers.addWhiteBackgroundLayer('Background');
  layers.addTop(name: 'Top').backgroundColor = Colors.red;
  return layers;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('selectLayerIfPresent', () {
    test('selects a layer that is part of the stack', () {
      final LayersProvider layers = _twoLayerStack();
      final LayerProvider background = layers.get(1);

      layers.selectLayerIfPresent(background);

      expect(layers.selectedLayer, same(background));
    });

    test('is a no-op for null or a detached layer', () {
      final LayersProvider layers = _twoLayerStack();
      layers.selectedLayerIndex = 1;

      layers.selectLayerIfPresent(null);
      expect(layers.selectedLayerIndex, 1);

      final LayerProvider detached = layers.newLayer('Detached');
      layers.selectLayerIfPresent(detached);
      expect(layers.selectedLayerIndex, 1);
    });
  });

  group('captureCompositeForExport', () {
    test('renders when changed and reuses the cached composite when clean', () async {
      final LayersProvider layers = _twoLayerStack();

      final ui.Image rendered = await layers.captureCompositeForExport();
      expect(rendered.width, _canvasSize.width.toInt());
      expect(layers.cachedImage, same(rendered));

      layers.clearHasChanged();
      final ui.Image reused = await layers.captureCompositeForExport();
      expect(reused, same(rendered));
    });
  });
}
