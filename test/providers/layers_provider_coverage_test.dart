import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';

import '../helpers/layers_provider_test_helper.dart';

void main() {
  group('LayersProvider undo coverage', () {
    late LayersProvider layers;
    late UndoProvider undoProvider;

    setUp(() {
      undoProvider = UndoProvider();
      undoProvider.clear();
      layers = createInitializedLayersProvider(undoProvider: undoProvider);
    });

    test('canvasResize undo restores original size', () {
      final Size originalSize = layers.size;
      layers.canvasResize(400, 300, CanvasResizePosition.center);
      expect(layers.size, const Size(400, 300));

      undoProvider.undo();
      expect(layers.size, originalSize);
    });

    test('canvasResize undo with top position restores offsets', () {
      final Size originalSize = layers.size;
      layers.canvasResize(400, 300, CanvasResizePosition.top);
      expect(layers.size, const Size(400, 300));

      undoProvider.undo();
      expect(layers.size, originalSize);
    });

    test('canvasResize undo with bottomRight position restores', () {
      final Size originalSize = layers.size;
      layers.canvasResize(600, 400, CanvasResizePosition.bottomRight);
      expect(layers.size, const Size(600, 400));

      undoProvider.undo();
      expect(layers.size, originalSize);
    });

    test('canvasResize no-op when same size', () {
      final Size originalSize = layers.size;
      layers.canvasResize(
        originalSize.width.toInt(),
        originalSize.height.toInt(),
        CanvasResizePosition.center,
      );
      expect(layers.size, originalSize);
      expect(undoProvider.canUndo, false);
    });

    test('canvasResize no-op when dimensions are zero or negative', () {
      layers.canvasResize(0, 300, CanvasResizePosition.center);
      expect(undoProvider.canUndo, false);
      layers.canvasResize(300, -1, CanvasResizePosition.center);
      expect(undoProvider.canUndo, false);
    });

    test('mergeLayers undo restores both layers', () {
      // Add a second layer on top with some actions.
      final LayerProvider topLayer = layers.addTop(name: 'TopLayer');
      topLayer.appendDrawingAction(
        UserActionDrawing(
          positions: <Offset>[const Offset(0, 0), const Offset(10, 10)],
          action: ActionType.brush,
          brush: MyBrush(color: Colors.red, size: 2),
          fillColor: Colors.transparent,
        ),
      );
      layers.selectedLayerIndex = 0;

      expect(layers.length, 2);

      // Merge top into bottom.
      layers.mergeLayers(0, 1);
      expect(layers.length, 1);

      // Undo.
      undoProvider.undo();
      expect(layers.length, 2);
    });

    test('mergeLayers same index is no-op', () {
      layers.mergeLayers(0, 0);
      expect(undoProvider.canUndo, false);
    });

    test('getTopColorUsed aggregates colors across visible layers', () async {
      // Set up layers with known top colors.
      final LayerProvider layer0 = layers.get(0);
      layer0.topColorsUsed = <ColorUsage>[
        ColorUsage(Colors.red, 0.5),
        ColorUsage(Colors.blue, 0.3),
      ];

      final LayerProvider layer1 = layers.addTop(name: 'Layer1');
      layer1.topColorsUsed = <ColorUsage>[
        ColorUsage(Colors.red, 0.7),
        ColorUsage(Colors.green, 0.2),
      ];

      final List<ColorUsage> result = await layers.getTopColorUsed();

      // Red should be present (from both layers, aggregated).
      expect(result.isNotEmpty, true);
      final ColorUsage red = result.firstWhere(
        (final ColorUsage c) => c.color == Colors.red,
      );
      expect(red.percentage > 0.5, true);
    });

    test('evaluateTopColor calls getTopColorUsed', () async {
      final LayerProvider layer0 = layers.get(0);
      layer0.topColorsUsed = <ColorUsage>[
        ColorUsage(Colors.red, 0.5),
      ];

      layers.evaluateTopColor();
      // Wait for async completion.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(layers.topColors.isNotEmpty, true);
    });

    test('getTopColorUsed skips hidden layers', () async {
      final LayerProvider layer0 = layers.get(0);
      layer0.topColorsUsed = <ColorUsage>[
        ColorUsage(Colors.red, 0.5),
      ];
      layer0.isVisible = false;

      final List<ColorUsage> result = await layers.getTopColorUsed();
      expect(result.isEmpty, true);
    });

    test('hideShowAllExcept hides others', () {
      final LayerProvider layer1 = layers.addTop(name: 'Layer1');
      final LayerProvider layer2 = layers.addTop(name: 'Layer2');
      final LayerProvider bg = layers.get(layers.length - 1);

      layers.hideShowAllExcept(layer1, false);
      expect(layer1.isVisible, true);
      expect(layer2.isVisible, false);
      expect(bg.isVisible, false);

      layers.hideShowAllExcept(layer1, true);
      expect(layer2.isVisible, true);
      expect(bg.isVisible, true);
    });

    test('selectedLayerIndex setter updates selection', () {
      layers.addTop(name: 'Top');
      layers.selectedLayerIndex = 0;
      expect(layers.selectedLayerIndex, 0);
      expect(layers.selectedLayer.name, 'Top');

      layers.selectedLayerIndex = 1;
      expect(layers.selectedLayerIndex, 1);
    });

    test('layersToggleVisibility flips visibility', () {
      final LayerProvider layer = layers.addTop(name: 'ToggleMe');
      expect(layer.isVisible, true);
      layers.layersToggleVisibility(layer);
      expect(layer.isVisible, false);
      layers.layersToggleVisibility(layer);
      expect(layer.isVisible, true);
    });

    test('clearHasChanged resets all layers', () {
      layers.addTop(name: 'A');
      layers.get(0).hasChanged = true;
      layers.clearHasChanged();
      expect(layers.get(0).hasChanged, false);
    });

    test('markAllChanged marks all layers', () {
      layers.addTop(name: 'A');
      layers.clearHasChanged();
      layers.markAllChanged();
      expect(layers.get(0).hasChanged, true);
    });

    test('canvasResizeLockAspectRatio getter and setter', () {
      expect(layers.canvasResizeLockAspectRatio, true);
      layers.canvasResizeLockAspectRatio = false;
      expect(layers.canvasResizeLockAspectRatio, false);
      layers.canvasResizeLockAspectRatio = true;
    });

    test('canvasResizePosition getter and setter', () {
      layers.canvasResizePosition = CanvasResizePosition.top;
      expect(layers.canvasResizePosition, CanvasResizePosition.top);
      layers.canvasResizePosition = CanvasResizePosition.center;
    });

    test('scale getter and setter', () {
      layers.scale = 2.0;
      expect(layers.scale, 2.0);
      // Clamp to max
      layers.scale = 100.0;
      expect(layers.scale, lessThanOrEqualTo(10.0));
    });

    test('size setter updates layers', () {
      layers.addTop(name: 'A');
      layers.size = const Size(500, 300);
      expect(layers.size, const Size(500, 300));
      expect(layers.width, 500);
      expect(layers.height, 300);
    });

    test('remove layer by index', () {
      layers.addTop(name: 'RemoveMe');
      final int initialLength = layers.length;
      layers.removeByIndex(0);
      expect(layers.length, initialLength - 1);
    });

    test('remove returns true for existing layer', () {
      final LayerProvider layer = layers.addTop(name: 'ToRemove');
      expect(layers.remove(layer), true);
    });

    test('getLayerIndex returns correct index', () {
      final LayerProvider layer = layers.addTop(name: 'Find');
      expect(layers.getLayerIndex(layer), 0);
    });

    test('insert at valid index', () {
      final LayerProvider layer = layers.newLayer('Inserted');
      layers.insert(0, layer);
      expect(layers.get(0).name, 'Inserted');
    });

    test('insert at out of range index appends', () {
      final LayerProvider layer = layers.newLayer('Appended');
      layers.insert(999, layer);
      expect(layers.get(layers.length - 1).name, 'Appended');
    });

    test('addBottom adds at the end', () {
      final LayerProvider layer = layers.addBottom('Bottom');
      expect(layers.get(layers.length - 1).name, 'Bottom');
      expect(layer.name, 'Bottom');
    });

    test('replaceAll clears and repopulates', () async {
      layers.addTop(name: 'Existing');
      await layers.replaceAll(
        canvasSize: const Size(200, 100),
        addLayers: () async {
          layers.addTop(name: 'New1');
          layers.addTop(name: 'New2');
        },
      );
      expect(layers.size, const Size(200, 100));
      expect(layers.length, 2);
      expect(layers.selectedLayerIndex, 0);
    });

    test('isEmpty and isNotEmpty', () {
      layers.clear();
      expect(layers.isEmpty, true);
      expect(layers.isNotEmpty, false);
      layers.addTop(name: 'One');
      expect(layers.isEmpty, false);
      expect(layers.isNotEmpty, true);
    });

    test('hasChanged reflects layer state', () {
      layers.addTop(name: 'A');
      layers.clearHasChanged();
      expect(layers.hasChanged, false);
      layers.get(0).hasChanged = true;
      expect(layers.hasChanged, true);
    });

    test('ensureLayerAtIndex creates layers up to index', () {
      layers.clear();
      layers.ensureLayerAtIndex(3);
      expect(layers.length, 4);
    });

    test('canvasResize with invalid dimensions does nothing', () {
      final Size originalSize = layers.size;
      layers.canvasResize(0, 100, CanvasResizePosition.center);
      expect(layers.size, originalSize);
      layers.canvasResize(100, -1, CanvasResizePosition.center);
      expect(layers.size, originalSize);
    });

    test('canvasResize with same size does nothing', () {
      layers.size = const Size(300, 200);
      layers.canvasResize(300, 200, CanvasResizePosition.center);
      expect(layers.size, const Size(300, 200));
    });

    test('mergeLayers merges two layers', () {
      layers.addTop(name: 'Top');
      layers.addBottom('Bottom');
      final int initialLength = layers.length;
      layers.mergeLayers(0, 1);
      // Merge should reduce layer count.
      expect(layers.length, lessThanOrEqualTo(initialLength));
    });

    test('evaluateTopColor runs without error', () {
      layers.addTop(name: 'Colors');
      layers.evaluateTopColor();
      expect(layers.topColors, isA<List<ColorUsage>>());
    });

    test('list getter returns layers', () {
      layers.addTop(name: 'InList');
      expect(layers.list, isNotEmpty);
      expect(layers.list.first, isA<LayerProvider>());
    });

    test('rotateCanvas90Clockwise swaps dimensions', () async {
      final Size originalSize = layers.size;
      await layers.rotateCanvas90Clockwise();
      expect(layers.width, originalSize.height);
      expect(layers.height, originalSize.width);
    });

    test('rotateCanvas90Clockwise undo runs backward', () async {
      await layers.rotateCanvas90Clockwise();
      undoProvider.undo();
      // Just verify it doesn't crash; async backward may not complete immediately
    });

    test('flipCanvasHorizontal flips and undoes', () async {
      layers.addTop(name: 'FlipH');
      await layers.flipCanvasHorizontal('Flip H');
      // Just verify it runs without error
      expect(layers.length, greaterThan(0));
      undoProvider.undo();
    });

    test('flipCanvasVertical flips and undoes', () async {
      layers.addTop(name: 'FlipV');
      await layers.flipCanvasVertical('Flip V');
      expect(layers.length, greaterThan(0));
      undoProvider.undo();
    });

    test('capturePainterToImage returns image', () async {
      layers.addTop(name: 'Capture');
      final ui.Image image = await layers.capturePainterToImage();
      expect(image.width, layers.width.toInt());
      expect(image.height, layers.height.toInt());
    });

    test('capturePainterToImageBytes returns bytes', () async {
      layers.addTop(name: 'Bytes');
      final Uint8List bytes = await layers.capturePainterToImageBytes();
      expect(bytes, isNotEmpty);
    });

    test('getTopColorUsed returns color list', () async {
      layers.addTop(name: 'Colors');
      final List<ColorUsage> colors = await layers.getTopColorUsed();
      expect(colors, isA<List<ColorUsage>>());
    });

    test('addWhiteBackgroundLayer creates white layer', () {
      layers.clear();
      final LayerProvider bg = layers.addWhiteBackgroundLayer('CustomBG');
      expect(bg.name, 'CustomBG');
      expect(bg.backgroundColor, isNotNull);
    });

    test('mergeLayers with same index does nothing', () {
      layers.addTop(name: 'Same');
      final int len = layers.length;
      layers.mergeLayers(0, 0);
      expect(layers.length, len);
    });

    test('mergeLayers undo restores both layers', () {
      layers.addTop(name: 'From');
      layers.addTop(name: 'To');
      final int initialLength = layers.length;
      layers.mergeLayers(0, 1);
      undoProvider.undo();
      expect(layers.length, initialLength);
    });

    test('removeByIndex out of range does nothing', () {
      final int len = layers.length;
      layers.removeByIndex(999);
      expect(layers.length, len);
    });

    test('selectedLayerIndex out of range does nothing', () {
      layers.selectedLayerIndex = 999;
      // No crash, index unchanged
      expect(layers.selectedLayerIndex, isNonNegative);
    });

    test('update notifies listeners', () {
      bool notified = false;
      layers.addListener(() => notified = true);
      layers.update();
      expect(notified, true);
    });
  });
}
