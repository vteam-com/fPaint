// Imports
import 'package:flutter/material.dart';
import 'package:fpaint/models/layers.dart';

// Exports
export 'package:fpaint/models/layers.dart';

class AppModel extends ChangeNotifier {
  Layers layers = Layers();
  Size canvasSize = const Size(800, 600); // Default canvas size
  Offset offset = Offset(0, 0);

  int _currentLayerIndex = 0;
  int get currentLayerIndex => _currentLayerIndex;

  void setActiveLayer(final int layerIndex) {
    if (layers.isIndexInRange(layerIndex)) {
      _currentLayerIndex = layerIndex;
      notifyListeners();
    }
  }

  PaintLayer get currentLayer => layers.get(currentLayerIndex);

  void addLayer() {
    layers.add(PaintLayer(name: 'Layer${layers.length + 1}'));
    setActiveLayer(layers.length - 1);
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
    Shape? shape,
    Offset? start,
    Offset? end,
    ShapeType? type,
    Color? color,
  }) {
    if (shape != null) {
      if (_isWithinCanvas(shape.start) && _isWithinCanvas(shape.end)) {
        currentLayer.shapes.add(shape);
      }
    } else if (start != null && end != null && type != null && color != null) {
      if (_isWithinCanvas(start) && _isWithinCanvas(end)) {
        currentLayer.shapes.add(Shape(start, end, type, color));
      }
    }
    notifyListeners();
  }

  void updateLastShape(Offset end) {
    if (currentLayer.shapes.isNotEmpty && _isWithinCanvas(end)) {
      currentLayer.shapes.last.end = end;
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
    if (currentLayer.shapes.isNotEmpty) {
      currentLayer.shapes.removeLast();
      notifyListeners();
    }
  }

  void redo() {
    // Basic redo implementation (can be improved)
    notifyListeners();
  }
}
