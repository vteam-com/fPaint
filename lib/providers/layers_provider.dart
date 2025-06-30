// Imports
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/list_helper.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:fpaint/panels/canvas_panel.dart';
import 'package:fpaint/providers/layer_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:provider/provider.dart';

// Exports
export 'package:fpaint/providers/layer_provider.dart';

/// Manages a collection of [LayerProvider] objects, providing methods to interact with and manipulate the layers.
///
/// The [LayersProvider] class is responsible for maintaining the list of layers, providing methods to add, remove, and
/// access individual layers. It also includes utility methods for performing common operations on the layers,
/// such as clearing the layer list, checking for changes, and managing the visibility of layers.
///
/// The class also provides methods for performing transformations on the layers, such as offsetting and scaling
/// the layers, as well as a method to get the top color usage across all layers.
class LayersProvider extends ChangeNotifier {
  factory LayersProvider() {
    return _instance;
  }

  LayersProvider._internal() {
    addWhiteBackgroundLayer();
    clearHasChanged();
  }
  static final LayersProvider _instance = LayersProvider._internal();

  /// Retrieves the [LayersProvider] instance from the given [BuildContext].
  ///
  /// The [listen] parameter determines whether the widget should rebuild when the
  /// [LayersProvider]'s state changes.
  static LayersProvider of(
    final BuildContext context, {
    final bool listen = false,
  }) => Provider.of<LayersProvider>(context, listen: listen);

  /// Notifies listeners that the layers have been updated.
  void update() {
    notifyListeners();
  }

  Size _size = const Size(1024, 768);

  /// Gets the size of the canvas.
  Size get size => _size;

  /// Sets the size of the canvas.
  set size(final Size size) {
    _size = size;
    _list.forEach((final LayerProvider layer) => layer.size = size);
    notifyListeners(); // Add this line
  }

  ///-------------------------------------------
  /// Default canvas size

  /// Gets the width of the canvas.
  double get width => this.size.width;

  /// Gets the height of the canvas.
  double get height => this.size.height;

  ///-------------------------------------------
  /// canvasResizeLockAspectRatio
  bool _resizeLockAspectRatio = true;

  /// Gets whether the canvas resize lock aspect ratio is enabled.
  bool get canvasResizeLockAspectRatio => _resizeLockAspectRatio;

  /// Sets whether the canvas resize lock aspect ratio is enabled.
  set canvasResizeLockAspectRatio(final bool value) {
    _resizeLockAspectRatio = value;
    notifyListeners();
  }

  ///-------------------------------------------
  /// Scale
  /// Sets the scale of the canvas.
  ///
  /// The scale value is clamped between 10% and 400% to ensure a valid range.
  /// Calling this method will notify any listeners of the [AppProvider] that the scale has changed.
  double _scale = 1;

  /// Gets the scale of the canvas.
  double get scale => _scale;

  /// Sets the scale of the canvas.
  set scale(final double value) {
    if (_scale != value) {
      _scale = value.clamp(10 / 100, 1000 / 100);
    }
  }

  /// The cached image of the canvas.
  ui.Image? cachedImage;

  //-------------------------------------------
  // Canvas Resize position
  CanvasResizePosition _canvasResizePosition = CanvasResizePosition.center;

  /// Gets the canvas resize position.
  CanvasResizePosition get canvasResizePosition => _canvasResizePosition;

  /// Sets the canvas resize position.
  set canvasResizePosition(final CanvasResizePosition value) {
    _canvasResizePosition = value;
    notifyListeners();
  } // center

  /// Resizes the canvas and repositions content according to the anchor.
  void canvasResize(
    final int newWidth,
    final int newHeight,
    final CanvasResizePosition position,
  ) {
    final UndoProvider undoProvider = UndoProvider();

    final Size oldSize = this.size;
    final double oldViewScale = this.scale;
    final Size newCurrentSize = Size(newWidth.toDouble(), newHeight.toDouble());

    undoProvider.executeAction(
      name: 'Resize Canvas',
      forward: () {
        // 1. Calculate the offset using old and new size
        final Offset forwardOffset = anchorTranslate(
          position,
          oldSize,
          newCurrentSize,
        );

        // 2. Apply the offset ONCE to all content
        for (final LayerProvider layer in _list) {
          layer.offset(forwardOffset);
        }

        // 3. Now update the canvas size
        this.size = newCurrentSize;

        // 4. (Optional) Adjust view scale if canvas became smaller
        if (newWidth < oldSize.width || newHeight < oldSize.height) {
          double calculatedScale = 1.0;
          if (oldSize.width != 0 && oldSize.height != 0) {
            calculatedScale = min(newWidth / oldSize.width, newHeight / oldSize.height);
          } else if (oldSize.width != 0) {
            calculatedScale = newWidth / oldSize.width;
          } else if (oldSize.height != 0) {
            calculatedScale = newHeight / oldSize.height;
          }
          this.scale = calculatedScale;
        }

        this.update();
      },
      backward: () {
        // Calculate and apply reverse content offset BEFORE changing size back
        final Offset backwardOffset = anchorTranslate(
          position,
          newCurrentSize,
          oldSize,
        );
        for (final LayerProvider layer in _list) {
          for (final UserActionDrawing action in layer.actionStack) {
            for (int i = 0; i < action.positions.length; i++) {
              action.positions[i] = action.positions[i] + backwardOffset;
            }
          }
        }

        // Revert to old size
        this.size = oldSize;
        this.scale = oldViewScale;

        this.update();
      },
    );
  }

  /// Adds a white background layer to the canvas.
  LayerProvider addWhiteBackgroundLayer() {
    final LayerProvider firstLayer = newLayer('Background');
    firstLayer.backgroundColor = Colors.white;
    _list.add(firstLayer);
    return firstLayer;
  }

  final List<LayerProvider> _list = <LayerProvider>[];

  /// Clears all layers from the canvas.
  void clear() {
    _list.clear();
  }

  /// Gets the number of layers in the canvas.
  int get length => _list.length;

  /// Gets whether the canvas is empty.
  bool get isEmpty => _list.isEmpty;

  /// Gets whether the canvas is not empty.
  bool get isNotEmpty => _list.isNotEmpty;

  /// Gets whether any of the layers have changed.
  bool get hasChanged => _list.any((final LayerProvider layer) => layer.hasChanged);

  int _selectedLayerIndex = 0;

  /// Gets the index of the selected layer.
  int get selectedLayerIndex => _selectedLayerIndex;

  /// Sets the index of the selected layer.
  set selectedLayerIndex(final int index) {
    if (this.isIndexInRange(index)) {
      for (int i = 0; i < this.length; i++) {
        final LayerProvider layer = this.get(i);
        layer.id = (this.length - i).toString();
        layer.isSelected = i == index;
      }
      _selectedLayerIndex = index;
      this.get(_selectedLayerIndex).isSelected = true;
      notifyListeners();
    }
  }

  /// Gets the selected layer.
  LayerProvider get selectedLayer => this.get(this.selectedLayerIndex);

  /// Toggles the visibility of a layer.
  void layersToggleVisibility(final LayerProvider layer) {
    layer.isVisible = !layer.isVisible;
    notifyListeners();
  }

  /// Clears the hasChanged flag for all layers.
  void clearHasChanged() {
    for (final LayerProvider layer in _list) {
      layer.hasChanged = false;
    }
  }

  /// Checks if the given index is within the range of the layer list.
  bool isIndexInRange(final int indexLayer) => indexLayer >= 0 && indexLayer < _list.length;

  /// Gets the index of the given layer.
  int getLayerIndex(final LayerProvider layer) {
    return _list.indexOf(layer);
  }

  /// Gets the layer at the given index.
  LayerProvider get(final int index) {
    ensureLayerAtIndex(index);
    return _list[index];
  }

  /// Creates a new layer with the given name.
  LayerProvider newLayer(final String name) {
    return LayerProvider(
      name: name,
      size: _size,
      onThumnailChanged: () => notifyListeners(),
    );
  }

  /// Ensures that a layer exists at the given index.
  void ensureLayerAtIndex(final int index) {
    while (_list.length <= index) {
      _list.add(newLayer('Layer ${_list.length + 1}'));
    }
  }

  /// Gets a layer by its name.
  LayerProvider? getByName(final String name) {
    return _list.findFirstMatch((final LayerProvider layer) => layer.name == name);
  }

  /// Adds a layer to the top of the canvas.
  LayerProvider addTop({final String? name}) => this.insertAt(0, name);

  /// Adds a layer to the bottom of the canvas.
  LayerProvider addBottom([final String? name]) => this.insertAt(this.length, name);

  /// Inserts a layer at the given index.
  void insert(final int index, final LayerProvider layerToInsert) {
    if (isIndexInRange(index)) {
      _list.insert(index, layerToInsert);
    } else {
      _list.add(layerToInsert);
    }
  }

  /// Inserts a new layer at the given index.
  LayerProvider insertAt(final int index, [String? name]) {
    name ??= 'Layer${this.length}';
    final LayerProvider layer = newLayer(name);
    this.insert(index, layer);
    this.selectedLayerIndex = this.getLayerIndex(layer);
    update();
    return layer;
  }

  /// Removes a layer from the canvas.
  bool remove(final LayerProvider layer) {
    final bool wasRemoved = _list.remove(layer);
    this.selectedLayerIndex = (this.selectedLayerIndex > 0 ? this.selectedLayerIndex - 1 : 0);
    return wasRemoved;
  }

  /// Removes a layer from the canvas by its index.
  void removeByIndex(final int index) {
    if (isIndexInRange(index)) {
      _list.removeAt(index);
    }
  }

  /// Merges two layers together.
  void mergeLayers(final int indexFrom, final int indexTo) {
    if (indexFrom == indexTo) {
      // nothing to merge
      return;
    }

    final UndoProvider undoProvider = UndoProvider();

    final int currentSelectedIndex = this.selectedLayerIndex;
    final LayerProvider layerFrom = this.get(indexFrom);

    final LayerProvider layerTo = this.get(indexTo);

    final List<UserActionDrawing> actionsToAppend = List<UserActionDrawing>.from(layerFrom.actionStack);

    final int numberOfActionAdded = actionsToAppend.length;

    undoProvider.executeAction(
      name: 'Merge Layer',
      forward: () {
        // Step 1 - Merge 2 layers
        layerTo.actionStack.addAll(actionsToAppend);
        layerTo.hasChanged = true;

        // Step 2 - Remove Layer
        this.remove(layerFrom);

        layerTo.clearCache();
      },
      backward: () {
        // Step 1 - restore the delete layer that was merged
        this.insert(currentSelectedIndex, layerFrom);

        // Step 2 -
        for (int i = 0; i < numberOfActionAdded; i++) {
          layerTo.actionStack.removeLast();
        }
        // Step 3 - restore original selected layer
        this.selectedLayerIndex = currentSelectedIndex;

        layerFrom.clearCache();
        layerFrom.hasChanged = true;

        layerTo.clearCache();
        layerTo.hasChanged = true;
      },
    );
  }

  /// Gets the list of layers.
  List<LayerProvider> get list => _list;

  /// Offsets the content of all layers by the given offset.
  void offsetContent(final Offset offset) {
    for (final LayerProvider layer in _list) {
      layer.offset(offset);
    }
  }

  /// Hides or shows all layers except the given layer.
  void hideShowAllExcept(final LayerProvider exceptLayer, final bool show) {
    for (final LayerProvider layer in _list) {
      if (layer == exceptLayer) {
        layer.isVisible = true;
      } else {
        layer.isVisible = show;
      }
    }
  }

  //-------------------------
  // Top Colors used
  /// The list of top colors used in the canvas.
  List<ColorUsage> topColors = <ColorUsage>[
    ColorUsage(Colors.white, 1),
    ColorUsage(Colors.black, 1),
  ];

  /// Evaluates the top colors used in the canvas.
  void evaluatTopColor() {
    this.getTopColorUsed().then((final List<ColorUsage> topColorsFound) {
      topColors = topColorsFound;
    });
  }

  /// Retrieves the top most used colors across all layers.
  ///
  /// This method iterates through all layers, collects the top color usage for each layer,
  /// and then aggregates the results to find the overall top 10 most used colors. The
  /// percentage for each color is calculated based on the total number of layers.
  ///
  /// Returns:
  ///   A list of [ColorUsage] objects representing the top 10 most used colors.
  Future<List<ColorUsage>> getTopColorUsed() async {
    List<ColorUsage> topColors = <ColorUsage>[];
    final int totalLayers = _list.length;

    for (final LayerProvider layer in _list) {
      if (layer.isVisible) {
        for (final ColorUsage colorUsed in layer.topColorsUsed) {
          final ColorUsage existingColor = topColors.firstWhere(
            (final ColorUsage c) => c.color == colorUsed.color,
            orElse: () => colorUsed,
          );
          if (existingColor == colorUsed) {
            topColors.add(colorUsed);
          } else {
            existingColor.percentage += colorUsed.percentage / totalLayers;
          }
        }
      }
    }

    topColors.sort(
      (final ColorUsage a, final ColorUsage b) => b.percentage.compareTo(a.percentage),
    );
    topColors = topColors.take(20).toList();
    return topColors;
  }

  /// Captures the canvas panel to an image.
  Future<ui.Image> capturePainterToImage() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    // Draw the custom painter on the canvas
    final CanvasPanelPainter painter = CanvasPanelPainter(this);

    painter.paint(canvas, this.size);

    // End the recording and get the picture
    final ui.Picture picture = recorder.endRecording();

    // Convert the picture to an image
    this.cachedImage = await picture.toImage(
      this.size.width.toInt(),
      this.size.height.toInt(),
    );

    return this.cachedImage!;
  }

  /// Rotates the entire canvas and all its layers 90 degrees clockwise.
  Future<void> rotateCanvas90Clockwise() async {
    final UndoProvider undoProvider = UndoProvider();
    final Size oldSize = Size(width, height);
    final Size newSize = Size(height, width); // Swapped dimensions

    // Need to capture the state of all layers for undo.
    // This is tricky because layer.rotate90Clockwise modifies actions in place.
    // For a true undo, we'd need to implement rotate90CounterClockwise or store/restore actionStacks.
    // For now, the backward action will rotate 3 more times to get back to original.

    await undoProvider.executeAction(
      name: 'Rotate Canvas 90° CW',
      forward: () async {
        for (final LayerProvider layer in _list) {
          await layer.rotate90Clockwise(oldSize);
          layer.size = newSize; // Update individual layer's understanding of canvas size
        }
        this.size = newSize; // Update LayersProvider's canvas size
        this.update();
      },
      backward: () async {
        // Rotate 3 times to get back to the original orientation.
        // Each rotation needs the "current" old size before that specific rotation.
        Size currentOldSize = newSize; // Size before the first CCW rotation
        Size nextSize = oldSize;       // Size after the first CCW rotation

        for (int i = 0; i < 3; i++) {
          for (final LayerProvider layer in _list) {
            // Effectively rotating counter-clockwise by passing the "new" size as old,
            // because rotate90Clockwise expects the size *before* its CW rotation.
            await layer.rotate90Clockwise(currentOldSize);
            layer.size = nextSize;
          }
          this.size = nextSize;

          // Prepare for next rotation
          currentOldSize = this.size;
          nextSize = Size(currentOldSize.height, currentOldSize.width);
        }
        this.update();
      },
    );
  }

  /// Captures the canvas panel to an image and returns the image bytes.
  Future<Uint8List> capturePainterToImageBytes() async {
    final ui.Image image = await capturePainterToImage();
    // Convert the image to byte data (e.g., PNG)
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return byteData!.buffer.asUint8List();
  }

  /// Gets the color at the given offset.
  Future<Color?> getColorAtOffset(final Offset offset) async {
    try {
      final ui.Image image = await capturePainterToImage();

      // Ensure coordinates are within bounds
      final int x = offset.dx.clamp(0, image.width - 1).toInt();
      final int y = offset.dy.clamp(0, image.height - 1).toInt();

      // Convert the image to ByteData in the correct format
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

      if (byteData == null) {
        return null;
      }

      // Calculate pixel index (4 bytes per pixel: RGBA)
      final int pixelIndex = (y * image.width + x) * 4;

      // Extract RGBA values
      final int r = byteData.getUint8(pixelIndex);
      final int g = byteData.getUint8(pixelIndex + 1);
      final int b = byteData.getUint8(pixelIndex + 2);
      final int a = byteData.getUint8(pixelIndex + 3);

      return Color.fromARGB(a, r, g, b);
    } catch (error) {
      return null;
    }
  }
}
