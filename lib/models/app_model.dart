// Imports

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fpaint/models/canvas_model.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:provider/provider.dart';

// Exports
export 'package:fpaint/models/layers.dart';

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

  CanvasModel canvasModel = CanvasModel();
  late Layers layers = Layers(canvasModel.canvasSize);

  double get width => canvasModel.canvasSize.width * canvasModel.scale;
  double get height => canvasModel.canvasSize.height * canvasModel.scale;
  Size get canvasSizeScaled => Size(width, height);

  // Selected Tool
  Tools _selectedTool = Tools.draw;

  Tools get selectedTool => _selectedTool;

  //-------------------------------------------
  bool get canvasResizeLockAspectRatio =>
      canvasModel.canvasResizeLockAspectRatio;
  set canvasResizeLockAspectRatio(bool value) {
    canvasModel.canvasResizeLockAspectRatio = value;
    update();
  }

  //-------------------------------------------
  // Canvas Resize position

  int get canvasResizePosition => canvasModel.resizePosition;
  set canvasResizePosition(int value) {
    canvasModel.resizePosition = value;
    update();
  } // center

  void resizeCanvas(final int newWidth, final int newHeight) {
    final Size oldSize = canvasModel.canvasSize;
    final Size newSize = Size(newWidth.toDouble(), newHeight.toDouble());
    canvasModel.canvasSize = newSize;

    // Scale layers only when shrinking
    if (newWidth < oldSize.width || newHeight < oldSize.height) {
      final double scaleX = newWidth / oldSize.width;
      final double scaleY = newHeight / oldSize.height;
      final double scale = min(scaleX, scaleY);
      layers.scale(scale);
    }

    // Calculate the offset adjustment based on resize position
    Offset offset = CanvasResizePosition.anchorTranslate(
      canvasModel.resizePosition,
      oldSize,
      newSize,
    );
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
    canvasModel.scale = value.clamp(10 / 100, 400 / 100);
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
      selectedLayer.addUserAction(
        UserAction(
          positions: [start, end],
          tool: type,
          fillColor: colorFill,
          brushColor: colorStroke,
          brushSize: this.brusSize,
        ),
      );
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
