// Imports
import 'package:flutter/material.dart';
import 'package:fpaint/models/layers.dart';

// Exports
export 'package:fpaint/models/layers.dart';

class PaintModel extends ChangeNotifier {
  List<PaintLayer> layers = [PaintLayer(name: 'Layer1')];
  Size canvasSize = const Size(800, 600); // Default canvas size
  Offset offset = Offset(0, 0);

  int _currentLayerIndex = 0;
  int get currentLayerIndex => _currentLayerIndex;
  bool isIndexInRange(final int indexLayer) =>
      indexLayer >= 0 && indexLayer < layers.length;

  void setActiveLayer(final int layerIndex) {
    if (isIndexInRange(layerIndex)) {
      _currentLayerIndex = layerIndex;
      notifyListeners();
    }
  }

  PaintLayer get currentLayer => layers[currentLayerIndex];

  void addLayer() {
    final PaintLayer newLayer = PaintLayer(name: 'Layer${layers.length + 1}');
    layers.add(newLayer);
    setActiveLayer(layers.length - 1);
  }

  void removeLayer(int index) {
    if (layers.length > 1) {
      layers.removeAt(index);
      setActiveLayer(currentLayerIndex > 0 ? currentLayerIndex - 1 : 0);
    }
  }

  bool isVisible(final int layerIndex) {
    return layers[layerIndex].isVisible;
  }

  void addShape(
      {Shape? shape,
      Offset? start,
      Offset? end,
      ShapeType? type,
      Color? color}) {
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
      layers[layerIndex].isVisible = !layers[layerIndex].isVisible;
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
