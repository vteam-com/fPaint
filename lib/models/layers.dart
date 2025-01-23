// Imports
import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/models/shapes.dart';

// Exports
export 'package:fpaint/models/shapes.dart';

class PaintLayer {
  PaintLayer({required this.name});
  String name;
  List<Shape> shapes = [];
  bool isVisible = true;
}

class Layers {
  Layers(final Size size) {
    final PaintLayer firstLayer = PaintLayer(name: 'Layer1');

    firstLayer.shapes.add(
      Shape(
        Offset(0, 0),
        Offset(size.width, size.height),
        ShapeType.rectangle,
        Colors.white,
      ),
    );

    _list.add(firstLayer);
  }
  final List<PaintLayer> _list = [];

  int get length => _list.length;

  bool isIndexInRange(final int indexLayer) =>
      indexLayer >= 0 && indexLayer < _list.length;

  PaintLayer get(final int index) {
    return _list[index];
  }

  void add(final PaintLayer layerToAdd) {
    _list.add(layerToAdd);
  }

  void insert(final index, final PaintLayer layerToInsert) {
    _list.insert(index, layerToInsert);
  }

  void remove(final int index) {
    _list[index];
  }

  List<PaintLayer> get list => _list;
}
