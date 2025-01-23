import 'package:flutter/material.dart';

enum ShapeType {
  pencil,
  line,
  circle,
  rectangle,
}

class Shape {
  Offset start;
  Offset end;
  final ShapeType type;
  final Color color;

  Shape(
    this.start,
    this.end,
    this.type,
    this.color,
  );
}

class PaintLayer {
  List<Shape> shapes = [];
  bool isVisible = true;
}

class PaintModel extends ChangeNotifier {
  List<PaintLayer> layers = [PaintLayer()];

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
    layers.add(PaintLayer());
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
      currentLayer.shapes.add(shape);
    } else if (start != null && end != null && type != null && color != null) {
      currentLayer.shapes.add(Shape(start, end, type, color));
    }
    notifyListeners();
  }

  void updateLastShape(Offset end) {
    if (currentLayer.shapes.isNotEmpty) {
      currentLayer.shapes.last.end = end;
      notifyListeners();
    }
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
