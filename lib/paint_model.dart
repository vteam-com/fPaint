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

  Shape(this.start, this.end, this.type, this.color);
}

class PaintLayer {
  List<Shape> shapes = [];
}

class PaintModel extends ChangeNotifier {
  List<PaintLayer> layers = [PaintLayer()];
  int currentLayerIndex = 0;

  PaintLayer get currentLayer => layers[currentLayerIndex];

  void addLayer() {
    layers.add(PaintLayer());
    currentLayerIndex = layers.length - 1;
    notifyListeners();
  }

  void removeLayer(int index) {
    if (layers.length > 1) {
      layers.removeAt(index);
      currentLayerIndex = currentLayerIndex > 0 ? currentLayerIndex - 1 : 0;
      notifyListeners();
    }
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
