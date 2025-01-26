// Imports
import 'package:flutter/material.dart';
import 'package:fpaint/helpers/list_helper.dart';
import 'package:fpaint/models/layer.dart';

// Exports
export 'package:fpaint/models/layer.dart';

class Layers {
  Layers(final Size size) {
    final Layer firstLayer = Layer(name: 'Background');

    firstLayer.actionStack.add(
      UserAction(
        start: Offset(0, 0),
        end: Offset(size.width, size.height),
        type: Tools.rectangle,
        fillColor: Colors.white,
        brushColor: Colors.white,
        brushSize: 0,
      ),
    );

    _list.add(firstLayer);
  }
  final List<Layer> _list = [];
  void clear() => _list.clear();
  int get length => _list.length;

  bool isIndexInRange(final int indexLayer) =>
      indexLayer >= 0 && indexLayer < _list.length;

  int getLayerIndex(final Layer layer) {
    return _list.indexOf(layer);
  }

  Layer get(final int index) {
    return _list[index];
  }

  Layer? getByName(final String name) {
    return _list.findFirstMatch((layer) => layer.name == name);
  }

  void add(final Layer layerToAdd) {
    _list.insert(0, layerToAdd);
  }

  void insert(final index, final Layer layerToInsert) {
    if (isIndexInRange(index)) {
      _list.insert(index, layerToInsert);
    } else {
      _list.add(layerToInsert);
    }
  }

  void remove(final int index) {
    if (isIndexInRange(index)) {
      _list.removeAt(index);
    }
  }

  List<Layer> get list => _list;
}
