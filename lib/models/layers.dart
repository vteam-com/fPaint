// Imports
import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';

// Exports
export 'package:fpaint/models/user_action.dart';

class PaintLayer {
  PaintLayer({required this.name});
  String name;
  List<UserAction> shapes = [];
  List<UserAction> redoStack = [];
  bool isVisible = true;
}

class Layers {
  Layers(final Size size) {
    final PaintLayer firstLayer = PaintLayer(name: 'Background');

    firstLayer.shapes.add(
      UserAction(
        start: Offset(0, 0),
        end: Offset(size.width, size.height),
        type: Tools.rectangle,
        colorFill: Colors.white,
        colorOutline: Colors.white,
        brushSize: 0,
      ),
    );

    _list.add(firstLayer);
  }
  final List<PaintLayer> _list = [];

  int get length => _list.length;

  bool isIndexInRange(final int indexLayer) =>
      indexLayer >= 0 && indexLayer < _list.length;

  int getLayerIndex(final PaintLayer layer) {
    return _list.indexOf(layer);
  }

  PaintLayer get(final int index) {
    return _list[index];
  }

  void add(final PaintLayer layerToAdd) {
    _list.insert(0, layerToAdd);
  }

  void insert(final index, final PaintLayer layerToInsert) {
    _list.insert(index, layerToInsert);
  }

  void remove(final int index) {
    if (isIndexInRange(index)) {
      _list.removeAt(index);
    }
  }

  List<PaintLayer> get list => _list;
}
