import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/canvas_resize.dart'; // Added for CanvasResizePosition
import 'package:fpaint/providers/layers_provider.dart';

// Mock LayerProvider if its methods are too complex or have external deps for these tests.
// For now, we'll use real LayerProvider instances, assuming their basic state changes are testable.

void main() {
  late LayersProvider layersProvider;

  setUp(() {
    // LayersProvider is a singleton, so we need to ensure a clean state for each test.
    // This is tricky. The singleton pattern in LayersProvider means it retains state across tests.
    // For true unit tests, this should be refactored or a reset method provided.
    // Workaround: Access the instance and clear/reset its state manually.
    layersProvider = LayersProvider(); // Gets the singleton instance

    // Manually reset state to mimic a fresh instance as much as possible
    layersProvider.clear(); // Clear all layers first

    // Reset properties to their initial default values as defined in LayersProvider
    layersProvider.size = const Size(800, 600); // Default size
    layersProvider.scale = 1.0; // Default scale
    layersProvider.canvasResizeLockAspectRatio = true; // Default
    layersProvider.canvasResizePosition = CanvasResizePosition.center; // Default

    // Add the initial background layer (constructor also does this, clear() removes it)
    layersProvider.addWhiteBackgroundLayer();
    layersProvider.selectedLayerIndex = 0; // Select the background layer

    // Clear any 'changed' flags from previous tests
    layersProvider.clearHasChanged();
    // Note: UndoProvider state is not easily reset here if it's internal to LayersProvider's methods.
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

  group('Layer Operations: Selecting', () {
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

    // Direct opacity, blend mode, name changes are on LayerProvider, not LayersProvider.
    // LayersProvider would trigger updates if these change on selectedLayer.
    test('Modifying selectedLayer name is reflected (test LayerProvider itself)', () {
      final LayerProvider layer = layersProvider.selectedLayer;
      layer.name = 'New Name';
      // This doesn't automatically notify LayersProvider unless LayerProvider.name setter calls a callback
      // that LayersProvider listens to. Assuming LayerProvider.onThumnailChanged or similar might be it.
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

    // mergeAll and mergeVisible are not implemented in the provided LayersProvider code.
    // duplicate is also not implemented.
  });

  group('Canvas Resizing', () {
    test('canvasResize updates size and offsets content', () {
      final LayerProvider layer = layersProvider.selectedLayer;
      // Add a dummy action to check its offset later
      final UserActionDrawing action = UserActionDrawing(
        action: ActionType.brush,
        positions: <Offset>[const Offset(10, 10), const Offset(20, 20)],
      );
      layer.appendDrawingAction(action);

      layersProvider.size = const Size(100, 100);
      layersProvider.canvasResize(200, 200, CanvasResizePosition.center);

      expect(layersProvider.size, const Size(200, 200));
      // Offset calculation: dx=(200-100)/2=50, dy=(200-100)/2=50
      // The action's points should be offset by (50,50)
      expect(layer.actionStack.first.positions.first, const Offset(10 + 50, 10 + 50));
    });
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

    test('offsetContent updates positions in all layers', () {
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
      layersProvider.offsetContent(offset);

      expect(layer1.actionStack.first.positions.first, const Offset(10 + 5, 10 - 5));
      expect(layer2.actionStack.first.positions.first, const Offset(20 + 5, 20 - 5));
    });
  });
}
