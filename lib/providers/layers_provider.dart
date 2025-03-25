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

  static LayersProvider of(
    final BuildContext context, {
    final bool listen = false,
  }) =>
      Provider.of<LayersProvider>(context, listen: listen);

  void update() {
    notifyListeners();
  }

  Size _size = const Size(800, 600);
  Size get size => _size;
  set size(final Size size) {
    _size = size;
    _list.forEach((final LayerProvider layer) => layer.size = size);
  }

  ///-------------------------------------------
  /// Default canvas size
  double get width => this.size.width;
  double get height => this.size.height;

  ///-------------------------------------------
  /// canvasResizeLockAspectRatio
  bool _resizeLockAspectRatio = true;
  bool get canvasResizeLockAspectRatio => _resizeLockAspectRatio;

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
  double get scale => _scale;
  set scale(final double value) {
    if (_scale != value) {
      _scale = value.clamp(10 / 100, 1000 / 100);
    }
  }

  ui.Image? cachedImage;

  //-------------------------------------------
  // Canvas Resize position
  CanvasResizePosition _canvasResizePosition = CanvasResizePosition.center;

  CanvasResizePosition get canvasResizePosition => _canvasResizePosition;
  set canvasResizePosition(final CanvasResizePosition value) {
    _canvasResizePosition = value;
    notifyListeners();
  } // center

  void canvasResize(
    final int width,
    final int height,
    final CanvasResizePosition position,
  ) {
    final Size oldSize = size;
    final Size newSize = Size(width.toDouble(), height.toDouble());
    size = newSize;

    if (width < oldSize.width || height < oldSize.height) {
      final double scale = min(width / oldSize.width, height / oldSize.height);
      this.scale = scale;
    }

    final Offset offset = anchorTranslate(
      position,
      oldSize,
      newSize,
    );
    this.offsetContent(offset);
    update();
  }

  LayerProvider addWhiteBackgroundLayer() {
    final LayerProvider firstLayer = newLayer('Background');
    firstLayer.backgroundColor = Colors.white;
    _list.add(firstLayer);
    return firstLayer;
  }

  final List<LayerProvider> _list = <LayerProvider>[];

  void clear() {
    _list.clear();
  }

  int get length => _list.length;
  bool get isEmpty => _list.isEmpty;
  bool get isNotEmpty => _list.isNotEmpty;
  bool get hasChanged =>
      _list.any((final LayerProvider layer) => layer.hasChanged);

  int _selectedLayerIndex = 0;
  int get selectedLayerIndex => _selectedLayerIndex;
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

  LayerProvider get selectedLayer => this.get(this.selectedLayerIndex);

  void layersToggleVisibility(final LayerProvider layer) {
    layer.isVisible = !layer.isVisible;
    notifyListeners();
  }

  void clearHasChanged() {
    for (final LayerProvider layer in _list) {
      layer.hasChanged = false;
    }
  }

  bool isIndexInRange(final int indexLayer) =>
      indexLayer >= 0 && indexLayer < _list.length;
  int getLayerIndex(final LayerProvider layer) {
    return _list.indexOf(layer);
  }

  LayerProvider get(final int index) {
    ensureLayerAtIndex(index);
    return _list[index];
  }

  LayerProvider newLayer(final String name) {
    return LayerProvider(
      name: name,
      size: _size,
      onThumnailChanged: () => notifyListeners(),
    );
  }

  void ensureLayerAtIndex(final int index) {
    while (_list.length <= index) {
      _list.add(newLayer('Layer ${_list.length + 1}'));
    }
  }

  LayerProvider? getByName(final String name) {
    return _list
        .findFirstMatch((final LayerProvider layer) => layer.name == name);
  }

  LayerProvider addTop([final String? name]) => this.insertAt(0, name);

  LayerProvider addBottom([final String? name]) =>
      this.insertAt(this.length, name);

  void insert(final int index, final LayerProvider layerToInsert) {
    if (isIndexInRange(index)) {
      _list.insert(index, layerToInsert);
    } else {
      _list.add(layerToInsert);
    }
  }

  LayerProvider insertAt(final int index, [String? name]) {
    name ??= 'Layer${this.length}';
    final LayerProvider layer = newLayer(name);
    this.insert(index, layer);
    this.selectedLayerIndex = this.getLayerIndex(layer);
    update();
    return layer;
  }

  bool remove(final LayerProvider layer) {
    final bool wasRemoved = _list.remove(layer);
    this.selectedLayerIndex =
        (this.selectedLayerIndex > 0 ? this.selectedLayerIndex - 1 : 0);
    return wasRemoved;
  }

  void removeByIndex(final int index) {
    if (isIndexInRange(index)) {
      _list.removeAt(index);
    }
  }

  void mergeLayers(final int indexFrom, final int indexTo) {
    if (indexFrom == indexTo) {
      // nothing to merge
      return;
    }

    final UndoProvider undoProvider = UndoProvider();

    final int currentSelectedIndex = this.selectedLayerIndex;
    final LayerProvider layerFrom = this.get(indexFrom);

    final LayerProvider layerTo = this.get(indexTo);

    final List<UserActionDrawing> actionsToAppend =
        List<UserActionDrawing>.from(layerFrom.actionStack);

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

  List<LayerProvider> get list => _list;

  void offsetContent(final Offset offset) {
    for (final LayerProvider layer in _list) {
      layer.offset(offset);
    }
  }

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
  List<ColorUsage> topColors = <ColorUsage>[
    ColorUsage(Colors.white, 1),
    ColorUsage(Colors.black, 1),
  ];

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
      (final ColorUsage a, final ColorUsage b) =>
          b.percentage.compareTo(a.percentage),
    );
    topColors = topColors.take(20).toList();
    return topColors;
  }

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

  Future<Uint8List> capturePainterToImageBytes() async {
    final ui.Image image = await capturePainterToImage();
    // Convert the image to byte data (e.g., PNG)
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return byteData!.buffer.asUint8List();
  }

  Future<Color?> getColorAtOffset(final Offset offset) async {
    final ui.Image image = await capturePainterToImage();

    // Ensure coordinates are within bounds
    final int x = offset.dx.toInt();
    final int y = offset.dy.toInt();
    if (x < 0 || y < 0 || x >= image.width || y >= image.height) {
      return null; // Return null for out-of-bounds coordinates
    }

    // Convert the image to ByteData in the correct format
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawUnmodified);
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
  }
}
