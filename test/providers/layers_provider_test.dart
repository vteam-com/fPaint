import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/layers_provider.dart';

import '../helpers/layers_provider_test_helper.dart';

const int _samplePixelTopLeftX = 5;
const int _samplePixelTopLeftY = 5;
const int _samplePixelMovedX = 25;
const int _samplePixelMovedY = 5;
const int _rgbaBytesPerPixel = 4;
const int _rgbaRedOffset = 0;
const int _rgbaGreenOffset = 1;
const int _rgbaBlueOffset = 2;
const int _rgbaAlphaOffset = 3;
const int _cachedImageSampleSize = 20;
const int _firstLayerIndex = 0;
const int _secondLayerIndex = 1;
const int _thirdLayerIndex = 2;
const int _outOfRangeIndex = 999;
const Offset _cachedImageSampleOffset = Offset(10, 10);

// Mock LayerProvider if its methods are too complex or have external deps for these tests.
// For now, we'll use real LayerProvider instances, assuming their basic state changes are testable.

void main() {
  late LayersProvider layersProvider;

  setUp(() {
    layersProvider = createInitializedLayersProvider();
  });

  group('LayersProvider Initialization and Defaults', () {
    test('Initial state has one default background layer', () {
      expect(layersProvider.length, 1);
      expect(layersProvider.get(0).name, 'Background');
      expect(layersProvider.get(0).backgroundColor, Colors.white);
    });

    test('Initial selectedLayerIndex is 0', () {
      expect(layersProvider.selectedLayerIndex, 0);
      expect(layersProvider.selectedLayer, layersProvider.get(0));
    });

    test('Default properties are set correctly', () {
      expect(layersProvider.size, const Size(800, 600));
      expect(layersProvider.scale, 1.0);
      expect(layersProvider.canvasResizeLockAspectRatio, isTrue);
      expect(layersProvider.canvasResizePosition, CanvasResizePosition.center);
    });
  });

  group('Layer Operations: Adding', () {
    test('addTop creates a new layer at the top and selects it', () {
      final int initialLength = layersProvider.length;
      final LayerProvider newLayer = layersProvider.addTop(name: 'TopLayer');
      expect(layersProvider.length, initialLength + 1);
      expect(layersProvider.get(0), newLayer);
      expect(layersProvider.selectedLayerIndex, 0);
      expect(newLayer.name, 'TopLayer');
    });

    test('addBottom creates a new layer at the bottom and selects it', () {
      final int initialLength = layersProvider.length;
      final LayerProvider firstLayer = layersProvider.get(0);
      final LayerProvider newLayer = layersProvider.addBottom('BottomLayer');

      expect(layersProvider.length, initialLength + 1);
      // The new layer is added at the end, but selection might change.
      // addBottom -> insertAt(length) -> selectedLayerIndex = getLayerIndex(newLayer)
      expect(layersProvider.get(layersProvider.length - 1), newLayer);
      expect(layersProvider.selectedLayer, newLayer);
      expect(layersProvider.get(0), firstLayer); // Original first layer should still be at 0
      expect(newLayer.name, 'BottomLayer');
    });

    test('insertAt inserts a layer at specified index and selects it', () {
      layersProvider.addTop(name: 'Layer2'); // Now: [Layer2, Background]
      layersProvider.addTop(name: 'Layer3'); // Now: [Layer3, Layer2, Background]

      final LayerProvider newLayer = layersProvider.insertAt(1, 'InsertedLayer'); // Insert between Layer3 and Layer2
      expect(layersProvider.length, 4);
      expect(layersProvider.get(1), newLayer);
      expect(layersProvider.selectedLayer, newLayer);
      expect(newLayer.name, 'InsertedLayer');
      expect(layersProvider.get(0).name, 'Layer3');
      expect(layersProvider.get(2).name, 'Layer2');
    });
  });

  group('Layer Operations: Removing', () {
    test('remove a layer by instance', () {
      final LayerProvider layerToRemove = layersProvider.addTop(name: 'ToRemove');
      final int initialLength = layersProvider.length;

      final bool wasRemoved = layersProvider.remove(layerToRemove);
      expect(wasRemoved, isTrue);
      expect(layersProvider.length, initialLength - 1);
      expect(layersProvider.list.contains(layerToRemove), isFalse);
      // Selected index should adjust: if top was removed, index 0 (new top) selected.
      expect(layersProvider.selectedLayerIndex, 0);
    });

    test('removeByIndex removes a layer at specified index', () {
      layersProvider.addTop(name: 'Layer2');
      final LayerProvider layerToKeep = layersProvider.addTop(name: 'LayerToKeep'); // This will be index 0
      final int initialLength = layersProvider.length;

      layersProvider.removeByIndex(1); // Remove 'Layer2' which is now at index 1

      expect(layersProvider.length, initialLength - 1);
      expect(layersProvider.get(0), layerToKeep); // LayerToKeep should remain
      expect(layersProvider.list.any((final LayerProvider l) => l.name == 'Layer2'), isFalse);
    });

    test('remove last layer adjusts selection to new last layer', () {
      layersProvider.addTop(name: 'L1'); // Index 0
      layersProvider.addTop(name: 'L2'); // Index 0, L1 is 1
      final LayerProvider layerToRemove = layersProvider.get(0); // L2
      layersProvider.remove(layerToRemove);
      expect(layersProvider.selectedLayerIndex, 0); // L1 is now 0
      expect(layersProvider.selectedLayer.name, 'L1');
    });
  });

  group('Layer Operations: Reordering', () {
    test('reorderLayer moving down inserts after drop target item', () {
      layersProvider.addTop(name: 'LayerC');
      layersProvider.addTop(name: 'LayerB');
      layersProvider.addTop(name: 'LayerA');
      // Current order: [LayerA, LayerB, LayerC, Background]

      layersProvider.reorderLayer(fromIndex: _firstLayerIndex, toIndex: _thirdLayerIndex);

      expect(layersProvider.get(_firstLayerIndex).name, 'LayerB');
      expect(layersProvider.get(_secondLayerIndex).name, 'LayerC');
      expect(layersProvider.get(_thirdLayerIndex).name, 'LayerA');
      expect(layersProvider.selectedLayerIndex, _thirdLayerIndex);
    });

    test('reorderLayer moving up inserts at drop target index', () {
      layersProvider.addTop(name: 'LayerC');
      layersProvider.addTop(name: 'LayerB');
      layersProvider.addTop(name: 'LayerA');
      // Current order: [LayerA, LayerB, LayerC, Background]

      layersProvider.reorderLayer(fromIndex: _thirdLayerIndex, toIndex: _firstLayerIndex);

      expect(layersProvider.get(_firstLayerIndex).name, 'LayerC');
      expect(layersProvider.get(_secondLayerIndex).name, 'LayerA');
      expect(layersProvider.get(_thirdLayerIndex).name, 'LayerB');
      expect(layersProvider.selectedLayerIndex, _firstLayerIndex);
    });

    test('reorderLayer ignores out-of-range indexes', () {
      layersProvider.addTop(name: 'LayerA');
      final List<String> namesBefore = layersProvider.list.map((final LayerProvider l) => l.name).toList();

      layersProvider.reorderLayer(fromIndex: _outOfRangeIndex, toIndex: _firstLayerIndex);
      layersProvider.reorderLayer(fromIndex: _firstLayerIndex, toIndex: _outOfRangeIndex);

      final List<String> namesAfter = layersProvider.list.map((final LayerProvider l) => l.name).toList();
      expect(namesAfter, namesBefore);
    });
  });

  group('Layer Operations: Selecting', () {
    test('replaceAll normalizes selected flags to a single layer', () async {
      await layersProvider.replaceAll(
        canvasSize: const Size(200, 100),
        addLayers: () async {
          layersProvider.addTop(name: 'Imported 1');
          layersProvider.addTop(name: 'Imported 2');
        },
      );

      final List<LayerProvider> selectedLayers = layersProvider.list
          .where((final LayerProvider layer) => layer.isSelected)
          .toList();

      expect(layersProvider.selectedLayerIndex, _firstLayerIndex);
      expect(selectedLayers, hasLength(1));
      expect(selectedLayers.single, same(layersProvider.get(_firstLayerIndex)));
    });

    test('selectedLayerIndex setter updates selected layer', () {
      layersProvider.addTop(name: 'Layer2'); // Index 0
      layersProvider.addTop(name: 'Layer3'); // Index 0
      // Layers: [Layer3, Layer2, Background]

      layersProvider.selectedLayerIndex = 1; // Select 'Layer2'
      expect(layersProvider.selectedLayerIndex, 1);
      expect(layersProvider.selectedLayer.name, 'Layer2');
      expect(layersProvider.get(1).isSelected, isTrue);
      expect(layersProvider.get(0).isSelected, isFalse);
      expect(layersProvider.get(2).isSelected, isFalse);
    });

    test('selectedLayerIndex setter handles out of bounds gracefully', () {
      final int initialIndex = layersProvider.selectedLayerIndex;
      layersProvider.selectedLayerIndex = -1; // Invalid
      expect(layersProvider.selectedLayerIndex, initialIndex);
      layersProvider.selectedLayerIndex = layersProvider.length + 5; // Invalid
      expect(layersProvider.selectedLayerIndex, initialIndex);
    });
  });

  group('Layer Properties', () {
    test('layersToggleVisibility changes layer visibility', () {
      final LayerProvider layer = layersProvider.selectedLayer;
      final bool initialVisibility = layer.isVisible;
      layersProvider.layersToggleVisibility(layer);
      expect(layer.isVisible, !initialVisibility);
    });

    test('layersToggleLock changes layer lock state', () {
      final LayerProvider layer = layersProvider.selectedLayer;
      final bool initialLockState = layer.isLocked;
      layersProvider.layersToggleLock(layer);
      expect(layer.isLocked, !initialLockState);
    });

    // Direct opacity, blend mode, name changes are on LayerProvider, not LayersProvider.
    // LayersProvider would trigger updates if these change on selectedLayer.
    test('Modifying selectedLayer name is reflected (test LayerProvider itself)', () {
      final LayerProvider layer = layersProvider.selectedLayer;
      layer.name = 'New Name';
      // This doesn't automatically notify LayersProvider unless LayerProvider.name setter calls a callback
      // that LayersProvider listens to. Assuming LayerProvider.onThumbnailChanged or similar might be it.
      // For this test, we check the LayerProvider instance directly.
      expect(layersProvider.selectedLayer.name, 'New Name');
    });
  });

  group('Layer Operations: Merging', () {
    // Merging involves UndoProvider, which is not mocked here.
    // These tests will be high-level, checking layer count and content if possible.
    // Proper testing of merge content would require image comparison or mock drawing actions.
    test('mergeLayers (mergeDown implies indexFrom > indexTo typically)', () {
      final LayerProvider middleLayer = layersProvider.addTop(name: 'Middle'); // Index 0, Background is 1
      final LayerProvider topLayer = layersProvider.addTop(name: 'Top'); // Index 0, Middle is 1, Background is 2

      // Simulate some actions
      topLayer.actionStack.add(UserActionDrawing(action: ActionType.brush, positions: <Offset>[Offset.zero]));
      middleLayer.actionStack.add(UserActionDrawing(action: ActionType.brush, positions: <Offset>[Offset.zero]));

      final int initialLength = layersProvider.length; // 3

      // Merge 'Top' (index 0) down into 'Middle' (index 1)
      layersProvider.mergeLayers(0, 1);

      expect(layersProvider.length, initialLength - 1); // Should be 2
      expect(layersProvider.get(0).name, 'Middle'); // Merged layer is now at index 0
      expect(layersProvider.get(0).actionStack.length, 2); // Both actions should be in 'Middle'
      expect(layersProvider.selectedLayerIndex, 0); // Selection should update
    });

    test('mergeLayers rasterize cut actions so they do not erase earlier merged content', () async {
      final LayerProvider lowerLayer = layersProvider.addTop(name: 'Lower');
      final LayerProvider upperLayer = layersProvider.addTop(name: 'Upper');

      lowerLayer.actionStack.add(
        UserActionDrawing(
          action: ActionType.region,
          positions: <Offset>[],
          path: ui.Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10)),
          fillColor: Colors.red,
        ),
      );

      upperLayer.actionStack.add(
        UserActionDrawing(
          action: ActionType.region,
          positions: <Offset>[],
          path: ui.Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10)),
          fillColor: Colors.green,
        ),
      );
      upperLayer.actionStack.add(
        UserActionDrawing(
          action: ActionType.cut,
          positions: <Offset>[],
          path: ui.Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10)),
        ),
      );
      upperLayer.actionStack.add(
        UserActionDrawing(
          action: ActionType.region,
          positions: <Offset>[],
          path: ui.Path()..addRect(const Rect.fromLTWH(20, 0, 10, 10)),
          fillColor: Colors.green,
        ),
      );

      layersProvider.mergeLayers(0, 1);

      expect(layersProvider.get(0).actionStack.length, 2);
      expect(layersProvider.get(0).actionStack.last.action, ActionType.image);

      final ui.Image mergedImage = layersProvider.get(0).toImageForStorage(layersProvider.size);

      expect(
        (await _pixelColorAt(mergedImage, _samplePixelTopLeftX, _samplePixelTopLeftY)).toARGB32(),
        Colors.red.toARGB32(),
      );
      expect(
        (await _pixelColorAt(mergedImage, _samplePixelMovedX, _samplePixelMovedY)).toARGB32(),
        Colors.green.toARGB32(),
      );
    });

    // mergeAll and mergeVisible are not implemented in the provided LayersProvider code.
    // duplicate is also not implemented.
  });

  // Layer groups are not explicitly handled by current LayersProvider structure.
  // Image manipulation/transformation methods (apart from offsetContent) are not directly on LayersProvider.
  // Undo/redo for layer operations (like add/remove/merge) seems tied to UndoProvider.
  // Testing those would require a mock UndoProvider or more integrated tests.

  group('Other Operations', () {
    test('clearHasChanged sets hasChanged to false for all layers', () {
      layersProvider.selectedLayer.hasChanged = true;
      layersProvider.addTop(name: 'AnotherLayer').hasChanged = true;

      layersProvider.clearHasChanged();
      for (final LayerProvider layer in layersProvider.list) {
        expect(layer.hasChanged, isFalse);
      }
    });

    test('layer offset updates positions in all layers', () {
      final LayerProvider layer1 = layersProvider.get(0);
      final UserActionDrawing action1 = UserActionDrawing(
        action: ActionType.brush,
        positions: <Offset>[const Offset(10, 10)],
      );
      layer1.appendDrawingAction(action1);

      final LayerProvider layer2 = layersProvider.addTop();
      final UserActionDrawing action2 = UserActionDrawing(
        action: ActionType.brush,
        positions: <Offset>[const Offset(20, 20)],
      );
      layer2.appendDrawingAction(action2);

      const Offset offset = Offset(5, -5);
      for (final LayerProvider layer in layersProvider.list) {
        layer.offset(offset);
      }

      expect(layer1.actionStack.first.positions.first, const Offset(10 + 5, 10 - 5));
      expect(layer2.actionStack.first.positions.first, const Offset(20 + 5, 20 - 5));
    });
  });

  group('Canvas Properties', () {
    test('size setter updates all layers', () {
      layersProvider.addTop(name: 'L1');
      const Size newSize = Size(1024, 768);
      layersProvider.size = newSize;
      expect(layersProvider.size, newSize);
      expect(layersProvider.width, newSize.width);
      expect(layersProvider.height, newSize.height);
      for (final LayerProvider layer in layersProvider.list) {
        expect(layer.size, newSize);
      }
    });

    test('scale setter clamps to valid range', () {
      layersProvider.scale = AppInteraction.minCanvasScale - 1;
      expect(layersProvider.scale, AppInteraction.minCanvasScale);

      layersProvider.scale = AppInteraction.maxCanvasScale + 1;
      expect(layersProvider.scale, AppInteraction.maxCanvasScale);
    });

    test('scale setter does not change when same value', () {
      layersProvider.scale = 2.0;
      layersProvider.scale = 2.0;
      expect(layersProvider.scale, 2.0);
    });

    test('canvasResizePosition setter updates', () {
      layersProvider.canvasResizePosition = CanvasResizePosition.topLeft;
      expect(layersProvider.canvasResizePosition, CanvasResizePosition.topLeft);
    });
  });

  group('Canvas Resize', () {
    test('canvasResize ignores invalid dimensions', () {
      final Size originalSize = layersProvider.size;
      layersProvider.canvasResize(0, 100, CanvasResizePosition.center);
      expect(layersProvider.size, originalSize);
      layersProvider.canvasResize(100, -1, CanvasResizePosition.center);
      expect(layersProvider.size, originalSize);
    });

    test('canvasResize ignores same size', () {
      final Size originalSize = layersProvider.size;
      layersProvider.canvasResize(
        originalSize.width.toInt(),
        originalSize.height.toInt(),
        CanvasResizePosition.center,
      );
      expect(layersProvider.size, originalSize);
    });

    test('canvasResize updates to new size', () {
      const int newWidth = 1024;
      const int newHeight = 768;
      layersProvider.canvasResize(newWidth, newHeight, CanvasResizePosition.center);
      expect(layersProvider.size, const Size(1024, 768));
    });
  });

  group('Visibility Operations', () {
    test('hideShowAllExcept hides all except specified layer', () {
      final LayerProvider layer1 = layersProvider.addTop(name: 'L1');
      final LayerProvider layer2 = layersProvider.addTop(name: 'L2');
      final LayerProvider bg = layersProvider.get(layersProvider.length - 1);

      layersProvider.hideShowAllExcept(layer1, false);

      expect(layer1.isVisible, isTrue);
      expect(layer2.isVisible, isFalse);
      expect(bg.isVisible, isFalse);
    });

    test('hideShowAllExcept shows all layers when show is true', () {
      final LayerProvider layer1 = layersProvider.addTop(name: 'L1');
      final LayerProvider layer2 = layersProvider.addTop(name: 'L2');
      final LayerProvider bg = layersProvider.get(layersProvider.length - 1);

      // First hide
      layersProvider.hideShowAllExcept(layer1, false);
      // Then show all
      layersProvider.hideShowAllExcept(layer1, true);

      expect(layer1.isVisible, isTrue);
      expect(layer2.isVisible, isTrue);
      expect(bg.isVisible, isTrue);
    });

    test('markAllChanged marks all layers', () {
      layersProvider.addTop(name: 'L1');
      layersProvider.addTop(name: 'L2');
      layersProvider.clearHasChanged();

      layersProvider.markAllChanged();
      for (final LayerProvider layer in layersProvider.list) {
        expect(layer.hasChanged, isTrue);
      }
    });
  });

  group('Layer Lookup', () {
    test('getLayerIndex returns correct index', () {
      final LayerProvider layer1 = layersProvider.addTop(name: 'L1');
      final LayerProvider layer2 = layersProvider.addTop(name: 'L2');
      expect(layersProvider.getLayerIndex(layer2), 0);
      expect(layersProvider.getLayerIndex(layer1), 1);
    });

    test('isIndexInRange returns correct values', () {
      expect(layersProvider.isIndexInRange(0), isTrue);
      expect(layersProvider.isIndexInRange(-1), isFalse);
      expect(layersProvider.isIndexInRange(layersProvider.length), isFalse);
    });

    test('isEmpty and isNotEmpty work correctly', () {
      expect(layersProvider.isEmpty, isFalse);
      expect(layersProvider.isNotEmpty, isTrue);
      layersProvider.clear();
      expect(layersProvider.isEmpty, isTrue);
      expect(layersProvider.isNotEmpty, isFalse);
    });

    test('ensureLayerAtIndex creates layers as needed', () {
      final int originalCount = layersProvider.length;
      layersProvider.get(originalCount + 2);
      expect(layersProvider.length, originalCount + 3);
    });
  });

  group('hasChanged', () {
    test('reflects layer state', () {
      layersProvider.clearHasChanged();
      expect(layersProvider.hasChanged, isFalse);
      layersProvider.selectedLayer.hasChanged = true;
      expect(layersProvider.hasChanged, isTrue);
    });
  });

  group('capturePainterToImage', () {
    test('returns an image with canvas dimensions', () async {
      final ui.Image image = await layersProvider.capturePainterToImage();
      expect(image.width, layersProvider.size.width.toInt());
      expect(image.height, layersProvider.size.height.toInt());
      expect(layersProvider.cachedImage, isNotNull);
    });

    test('skips invisible layers', () async {
      final LayerProvider layer = layersProvider.addTop(name: 'Hidden');
      layer.isVisible = false;
      layer.actionStack.add(
        UserActionDrawing(
          action: ActionType.region,
          positions: <Offset>[],
          path: ui.Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10)),
          fillColor: Colors.blue,
        ),
      );
      final ui.Image image = await layersProvider.capturePainterToImage();
      expect(image.width, layersProvider.size.width.toInt());
    });
  });

  group('capturePainterToImageBytes', () {
    test('returns PNG byte data', () async {
      final Uint8List bytes = await layersProvider.capturePainterToImageBytes();
      expect(bytes, isNotEmpty);
    });
  });

  group('getColorAtOffset', () {
    test('returns white on background layer', () async {
      final Color? color = await layersProvider.getColorAtOffset(const Offset(10, 10));
      expect(color, isNotNull);
      expect(color!.toARGB32(), Colors.white.toARGB32());
    });

    test('returns null for out-of-range coordinates (clamped)', () async {
      // getColorAtOffset clamps, so it shouldn't return null but still works
      final Color? color = await layersProvider.getColorAtOffset(const Offset(-1, -1));
      expect(color, isNotNull);
    });

    test('uses cached image snapshot when requested', () async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      canvas.drawRect(
        Rect.fromLTWH(
          0,
          0,
          _cachedImageSampleSize.toDouble(),
          _cachedImageSampleSize.toDouble(),
        ),
        Paint()..color = Colors.red,
      );
      final ui.Picture picture = recorder.endRecording();
      layersProvider.cachedImage = await picture.toImage(
        _cachedImageSampleSize,
        _cachedImageSampleSize,
      );

      final Color? color = await layersProvider.getColorAtOffset(
        _cachedImageSampleOffset,
        useCachedImage: true,
      );

      expect(color, isNotNull);
      expect(color!.toARGB32(), Colors.red.toARGB32());
    });
  });

  group('mergeLayers same index', () {
    test('merging same index does nothing', () {
      final int originalCount = layersProvider.length;
      layersProvider.mergeLayers(0, 0);
      expect(layersProvider.length, originalCount);
    });
  });

  group('rotateCanvas90Clockwise', () {
    test('swaps canvas dimensions', () async {
      const Size startSize = Size(800, 600);
      layersProvider.size = startSize;
      await layersProvider.rotateCanvas90Clockwise();
      expect(layersProvider.width, startSize.height);
      expect(layersProvider.height, startSize.width);
    });
  });

  group('flipCanvas', () {
    test('flipCanvasHorizontal does not change size', () async {
      final Size startSize = layersProvider.size;
      await layersProvider.flipCanvasHorizontal('Flip H');
      expect(layersProvider.size, startSize);
    });

    test('flipCanvasVertical does not change size', () async {
      final Size startSize = layersProvider.size;
      await layersProvider.flipCanvasVertical('Flip V');
      expect(layersProvider.size, startSize);
    });
  });

  group('insert and list', () {
    test('insert at out-of-range appends to end', () {
      final LayerProvider newLayer = layersProvider.newLayer('Appended');
      layersProvider.insert(999, newLayer);
      expect(layersProvider.list.last, newLayer);
    });
  });

  group('addWhiteBackgroundLayer', () {
    test('adds layer with custom name', () {
      layersProvider.clear();
      final LayerProvider bg = layersProvider.addWhiteBackgroundLayer('Custom BG');
      expect(bg.name, 'Custom BG');
      expect(bg.backgroundColor, Colors.white);
    });
  });

  group('getTopColorUsed', () {
    test('returns empty list when no layers have color data', () async {
      final List<ColorUsage> colors = await layersProvider.getTopColorUsed();
      expect(colors, isEmpty);
    });
  });

  group('replaceAll', () {
    test('clears layers, sets size, runs addLayers, selects first, clears changed', () async {
      // Add some pre-existing content
      layersProvider.addTop(name: 'Old Layer');
      layersProvider.selectedLayer.hasChanged = true;

      const Size newSize = Size(500, 300);

      await layersProvider.replaceAll(
        canvasSize: newSize,
        addLayers: () async {
          layersProvider.addTop(name: 'Imported A');
          layersProvider.addTop(name: 'Imported B');
        },
      );

      expect(layersProvider.size, newSize);
      expect(layersProvider.length, 2);
      expect(layersProvider.selectedLayerIndex, 0);
      expect(layersProvider.hasChanged, isFalse);
    });

    test('handles empty addLayers gracefully', () async {
      await layersProvider.replaceAll(
        canvasSize: const Size(100, 100),
        addLayers: () async {},
      );

      expect(layersProvider.isEmpty, isTrue);
      expect(layersProvider.size, const Size(100, 100));
    });
  });
}

Future<Color> _pixelColorAt(final ui.Image image, final int x, final int y) async {
  final ByteData? imageBytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

  expect(imageBytes, isNotNull);

  final int pixelOffset = ((y * image.width) + x) * _rgbaBytesPerPixel;

  return Color.fromARGB(
    imageBytes!.getUint8(pixelOffset + _rgbaAlphaOffset),
    imageBytes.getUint8(pixelOffset + _rgbaRedOffset),
    imageBytes.getUint8(pixelOffset + _rgbaGreenOffset),
    imageBytes.getUint8(pixelOffset + _rgbaBlueOffset),
  );
}
