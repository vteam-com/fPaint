// Imports

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fpaint/models/layers.dart';
import 'package:provider/provider.dart';

// Exports
export 'package:fpaint/models/layers.dart';

const int topLeft = 0;
const int top = 1;
const int topRight = 2;
const int left = 3;
const int center = 4;
const int right = 5;
const int bottomLeft = 6;
const int bottom = 7;
const int bottomRight = 8;

class AppModel extends ChangeNotifier {
  /// Gets the [AppModel] instance from the provided [BuildContext].
  ///
  /// If [listen] is true, the returned [AppModel] instance will notify listeners
  /// when its state changes. Otherwise, the returned instance will not notify
  /// listeners.
  static AppModel get(
    final BuildContext context, {
    final bool listen = false,
  }) =>
      Provider.of<AppModel>(context, listen: listen);

  String loadedFileName = '';

  Size canvasSize = const Size(800, 600); // Default canvas size
  late Layers layers = Layers(canvasSize);

  double get width => canvasSize.width * scale;
  double get height => canvasSize.height * scale;
  Size get canvasSizeScaled => Size(width, height);

  // Selected Tool
  Tools _selectedTool = Tools.draw;

  Tools get selectedTool => _selectedTool;

  //-------------------------------------------
  bool _canvasResizeLockAspectRatio = true;

  bool get canvasResizeLockAspectRatio => _canvasResizeLockAspectRatio;

  set canvasResizeLockAspectRatio(bool value) {
    _canvasResizeLockAspectRatio = value;
    update();
  }

  //-------------------------------------------
  // Canvas Resize position
  int _canvasResizePosition = 4; // Center

  int get canvasResizePosition => _canvasResizePosition;

  set canvasResizePosition(int value) {
    _canvasResizePosition = value;
    update();
  } // center

  void resizeCanvas(final int newWidth, final int newHeight) {
    final Size oldSize = canvasSize;
    canvasSize = Size(newWidth.toDouble(), newHeight.toDouble());

    // Scale layers only when shrinking
    if (newWidth < oldSize.width || newHeight < oldSize.height) {
      final double scaleX = newWidth / oldSize.width;
      final double scaleY = newHeight / oldSize.height;
      final double scale = min(scaleX, scaleY);
      layers.scale(scale);
    }

    // Calculate the offset adjustment based on resize position
    Offset offset = Offset.zero;

    final double dx = (newWidth - oldSize.width).toDouble();
    final double dy = (newHeight - oldSize.height).toDouble();

    switch (_canvasResizePosition) {
      case topLeft:
        offset = Offset.zero;
        break;
      case top:
        offset = Offset(dx / 2, 0);
        break;
      case topRight:
        offset = Offset(dx, 0);
        break;
      case left:
        offset = Offset(0, dy / 2);
        break;
      case center:
        offset = Offset(dx / 2, dy / 2);
        break;
      case right:
        offset = Offset(dx, dy / 2);
        break;
      case bottomLeft:
        offset = Offset(0, dy);
        break;
      case bottom:
        offset = Offset(dx / 2, dy);
        break;
      case bottomRight:
        offset = Offset(dx, dy);
        break;
    }
    layers.offset(offset);
    update();
  }

  set selectedTool(Tools value) {
    _selectedTool = value;
    update();
  }

  /// Stores the starting position of a pan gesture for drawing operations.
  UserAction? currentUserAction;
  Offset? userActionStartingOffset;

  // Color for Stroke
  Color _colorForStroke = Colors.black;

  Color get brushColor => _colorForStroke;

  // Scale
  double _scale = 1;
  double get scale => _scale;

  // SidePanel Expanded/Collapsed
  bool _isSidePanelExpanded = true;

  bool get isSidePanelExpanded => _isSidePanelExpanded;

  set isSidePanelExpanded(bool value) {
    _isSidePanelExpanded = value;
    update();
  }

  /// Sets the scale of the canvas.
  ///
  /// The scale value is clamped between 10% and 400% to ensure a valid range.
  /// Calling this method will notify any listeners of the [AppModel] that the scale has changed.
  set scale(final double value) {
    _scale = value.clamp(10 / 100, 400 / 100);
    update();
  }

  set brushColor(Color value) {
    _colorForStroke = value;
    update();
  }

  // Color for Fill
  Color _colorForFill = Colors.lightBlue;

  /// The color used to fill the canvas.
  Color get fillColor => _colorForFill;

  set fillColor(Color value) {
    _colorForFill = value;
    update();
  }

  // Line Weight
  double _lineWeight = 5;
  double get brusSize => _lineWeight;
  set brusSize(double value) {
    _lineWeight = value;
    update();
  }

  // Brush Style
  BrushStyle _brush = BrushStyle.solid;
  BrushStyle get brushStyle => _brush;
  set brushStyle(BrushStyle value) {
    _brush = value;
    update();
  }

  // Tolerance
  int _tolarance = 50; // Mid point 0..100
  int get tolerance => _tolarance;
  set tolerance(int value) {
    _tolarance = max(1, min(100, value));
    update();
  }

  int _selectedLayerIndex = 0;
  int get selectedLayerIndex => _selectedLayerIndex;

  /// Sets the index of the currently selected layer.
  ///
  /// If the provided `index` is within the range of the `layers` list, this method will:
  /// - Update the `id` property of each layer to reflect its position in the list (from bottom to top).
  /// - Set the `isSelected` property of the layer at the provided `index` to `true`.
  /// - Set the `_selectedLayerIndex` private field to the provided `index`.
  /// - Call the `update()` method to notify any listeners of the change.
  ///
  /// If the provided `index` is not within the range of the `layers` list, this method will do nothing.
  set selectedLayerIndex(final int index) {
    if (layers.isIndexInRange(index)) {
      for (int i = 0; i < layers.length; i++) {
        final Layer layer = layers.get(i);
        layer.id = (layers.length - i).toString();
        layer.isSelected = i == index;
      }
      _selectedLayerIndex = index;
      layers.get(_selectedLayerIndex).isSelected = true;
      update();
    }
  }

  Layer get selectedLayer => layers.get(selectedLayerIndex);
  bool get isCurrentSelectionReadyForAction => selectedLayer.isVisible;
  Layer addLayerTop([String? name]) {
    return insertLayer(0, name);
  }

  Layer addLayerBottom([String? name]) {
    return insertLayer(layers.length, name);
  }

  /// Inserts a new [Layer] at the specified [index] in the [layers] list.
  ///
  /// If [name] is not provided, a default name will be generated in the format `'Layer{layers.length}'`.
  ///
  /// This method will:
  /// - Create a new [Layer] instance with the provided or generated name.
  /// - Insert the new layer at the specified [index] in the [layers] list.
  /// - Set the [selectedLayerIndex] to the index of the newly inserted layer.
  /// - Call the [update()] method to notify any listeners of the change.
  ///
  /// Returns the newly inserted [Layer] instance.
  Layer insertLayer(final int index, [String? name]) {
    name ??= 'Layer${layers.length}';
    final Layer newLayer = Layer(name: name);
    layers.insert(index, newLayer);
    selectedLayerIndex = layers.getLayerIndex(newLayer);
    update();
    return newLayer;
  }

  void removeLayer(final Layer layer) {
    layers.remove(layer);
    selectedLayerIndex = (selectedLayerIndex > 0 ? selectedLayerIndex - 1 : 0);
  }

  bool isVisible(final int layerIndex) {
    if (layers.isIndexInRange(layerIndex)) {
      return layers.get(layerIndex).isVisible;
    }
    return false;
  }

  void addUserAction({
    required UserAction action,
  }) {
    selectedLayer.addUserAction(action);
    update();
  }

  void updateLastUserAction({
    required final Offset end,
    Tools? type,
    Color? colorFill,
    Color? colorStroke,
    Offset? start,
  }) {
    if (start != null &&
        type != null &&
        colorFill != null &&
        colorStroke != null) {
      if (_isWithinCanvas(start) && _isWithinCanvas(end)) {
        selectedLayer.addUserAction(
          UserAction(
            positions: [start, end],
            tool: type,
            fillColor: colorFill,
            brushColor: colorStroke,
            brushSize: this.brusSize,
          ),
        );
      }
    } else {
      selectedLayer.lastActionUpdatePositionEnd(end: end);
    }
    update();
  }

  /// Notifies all listeners that the model has been updated.
  /// This method should be called whenever the state of the model changes
  /// to ensure that any UI components observing the model are updated.
  void update() {
    notifyListeners();
  }

  /// Checks if the given [Offset] point is within the bounds of the canvas.
  ///
  /// The canvas is defined by the [canvasSize] property, which represents the
  /// width and height of the canvas. This method returns `true` if the point's
  /// x and y coordinates are between 0 and the canvas width/height, respectively.
  /// This is used to ensure that user actions (e.g. drawing) are performed
  /// within the bounds of the canvas.
  bool _isWithinCanvas(Offset point) {
    return point.dx >= 0 &&
        point.dx <= canvasSize.width &&
        point.dy >= 0 &&
        point.dy <= canvasSize.height;
  }

  /// Toggles the visibility of the specified [Layer].
  ///
  /// This method updates the `isVisible` property of the given [Layer] to the
  /// opposite of its current value, and then calls the `update()` method to
  /// notify any observers of the change.
  void toggleLayerVisibility(final Layer layer) {
    layer.isVisible = !layer.isVisible;
    update();
  }

  void undo() {
    selectedLayer.undo();
    update();
  }

  void redo() {
    selectedLayer.redo();
    update();
  }
}
