import 'package:flutter/material.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:fpaint/providers/layers_provider.dart';

const Size _defaultTestCanvasSize = Size(800, 600);
const double _defaultTestCanvasScale = 1.0;

/// Creates a clean [LayersProvider] instance configured with the common test defaults.
LayersProvider createInitializedLayersProvider({
  final Size size = _defaultTestCanvasSize,
}) {
  final LayersProvider layersProvider = LayersProvider();
  layersProvider.clear();
  layersProvider.size = size;
  layersProvider.scale = _defaultTestCanvasScale;
  layersProvider.canvasResizeLockAspectRatio = true;
  layersProvider.canvasResizePosition = CanvasResizePosition.center;
  layersProvider.addWhiteBackgroundLayer();
  layersProvider.selectedLayerIndex = 0;
  layersProvider.clearHasChanged();
  return layersProvider;
}
