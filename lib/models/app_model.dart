// Imports
import 'package:flutter/material.dart';
import 'package:fpaint/models/layers.dart';

// Exports
export 'package:fpaint/models/layers.dart';

class AppModel extends ChangeNotifier {
  String loadedFileName = '';

  Size canvasSize = const Size(800, 600); // Default canvas size
  late Layers layers = Layers(canvasSize);

  // Color for Stroke
  Color _colorForStroke = Colors.black;

  Color get colorForStroke => _colorForStroke;

  // Scale
  double _scale = 1;
  double get scale => _scale;

  /// Sets the scale of the canvas.
  ///
  /// The scale value is clamped between 10% and 400% to ensure a valid range.
  /// Calling this method will notify any listeners of the [AppModel] that the scale has changed.
  set scale(final double value) {
    _scale = value.clamp(10 / 100, 400 / 100);
    notifyListeners();
  }

  set colorForStroke(Color value) {
    _colorForStroke = value;
    notifyListeners();
  }

  // Color for Fill
  Color _colorForFill = Colors.lightBlue;

  Color get colorForFill => _colorForFill;

  set colorForFill(Color value) {
    _colorForFill = value;
    notifyListeners();
  }

  // Line Weight
  double _lineWeight = 5;
  double get lineWeight => _lineWeight;
  set lineWeight(double value) {
    _lineWeight = value;
    notifyListeners();
  }

  // Brush Style
  BrushStyle _brush = BrushStyle.solid;
  BrushStyle get brush => _brush;
  set brush(BrushStyle value) {
    _brush = value;
    notifyListeners();
  }

  int _currentLayerIndex = 0;
  int get currentLayerIndex => _currentLayerIndex;

  void setActiveLayer(final int layerIndex) {
    if (layers.isIndexInRange(layerIndex)) {
      _currentLayerIndex = layerIndex;
      notifyListeners();
    }
  }

  Layer get currentLayer => layers.get(currentLayerIndex);

  Layer addLayerTop([String? name]) {
    return insertLayer(0, name);
  }

  Layer addLayerBottom([String? name]) {
    return insertLayer(layers.length, name);
  }

  Layer insertLayer(final int index, [String? name]) {
    name ??= 'Layer${layers.length}';
    final Layer newLayer = Layer(name: name);
    layers.insert(index, newLayer);
    setActiveLayer(layers.getLayerIndex(newLayer));
    return newLayer;
  }

  void removeLayer(int index) {
    if (layers.isIndexInRange(index)) {
      layers.remove(index);
      setActiveLayer(currentLayerIndex > 0 ? currentLayerIndex - 1 : 0);
    }
  }

  bool isVisible(final int layerIndex) {
    if (layers.isIndexInRange(layerIndex)) {
      return layers.get(layerIndex).isVisible;
    }
    return false;
  }

  void addShape({
    UserAction? shape,
    Tools? type,
    Color? colorFill,
    Color? colorStroke,
    Offset? start,
    Offset? end,
  }) {
    if (shape != null) {
      if (_isWithinCanvas(shape.start) && _isWithinCanvas(shape.end)) {
        currentLayer.actionStack.add(shape);
      }
    } else if (start != null &&
        end != null &&
        type != null &&
        colorFill != null &&
        colorStroke != null) {
      if (_isWithinCanvas(start) && _isWithinCanvas(end)) {
        currentLayer.actionStack.add(
          UserAction(
            start: start,
            end: end,
            type: type,
            colorFill: colorFill,
            colorOutline: colorStroke,
            brushSize: this.lineWeight,
          ),
        );
      }
    }
    notifyListeners();
  }

  void updateLastShape(Offset end) {
    if (currentLayer.actionStack.isNotEmpty && _isWithinCanvas(end)) {
      currentLayer.actionStack.last.end = end;
      notifyListeners();
    }
  }

  bool _isWithinCanvas(Offset point) {
    return point.dx >= 0 &&
        point.dx <= canvasSize.width &&
        point.dy >= 0 &&
        point.dy <= canvasSize.height;
  }

  void toggleLayerVisibility(final int layerIndex) {
    if (layerIndex >= 0 && layerIndex < layers.length) {
      layers.get(layerIndex).isVisible = !layers.get(layerIndex).isVisible;
      notifyListeners();
    }
  }

  void undo() {
    if (currentLayer.actionStack.isNotEmpty) {
      currentLayer.redoStack.add(currentLayer.actionStack.removeLast());
      notifyListeners();
    }
  }

  void redo() {
    if (currentLayer.redoStack.isNotEmpty) {
      currentLayer.actionStack.add(currentLayer.redoStack.removeLast());
      notifyListeners();
    }
  }
}
