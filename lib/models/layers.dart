// Imports
import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/list_helper.dart';
import 'package:fpaint/models/layer.dart';

// Exports
export 'package:fpaint/models/layer.dart';

class Layers {
  Layers(final Size size) {
    final Layer firstLayer = Layer(name: 'Background');

    firstLayer.addUserAction(
      UserAction(
        positions: [
          const Offset(0, 0),
          Offset(size.width, size.height),
        ],
        tool: Tools.rectangle,
        fillColor: Colors.white,
        brushColor: Colors.white,
        brushSize: 0,
      ),
    );

    _list.add(firstLayer);
    clearHasChanged();
  }

  final List<Layer> _list = [];

  void clear() {
    _list.clear();
    clearHasChanged();
  }

  int get length => _list.length;
  bool get isEmpty => _list.isEmpty;
  bool get isNotEmpty => _list.isNotEmpty;
  bool get hasChanged => _list.any((layer) => layer.hasChanged);

  void clearHasChanged() {
    for (final Layer layer in _list) {
      layer.hasChanged = false;
    }
  }

  bool isIndexInRange(final int indexLayer) =>
      indexLayer >= 0 && indexLayer < _list.length;
  int getLayerIndex(final Layer layer) {
    return _list.indexOf(layer);
  }

  Layer get(final int index) {
    ensureLayerAtIndex(index);
    return _list[index];
  }

  void ensureLayerAtIndex(final int index) {
    while (_list.length <= index) {
      _list.add(Layer(name: 'Layer ${_list.length + 1}'));
    }
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

  bool remove(final Layer layer) {
    return _list.remove(layer);
  }

  void removeByIndex(final int index) {
    if (isIndexInRange(index)) {
      _list.removeAt(index);
    }
  }

  List<Layer> get list => _list;

  void offset(final Offset offset) {
    for (final Layer layer in _list) {
      layer.offset(offset);
    }
  }

  void scale(final double scale) {
    for (final Layer layer in _list) {
      layer.scale(scale);
    }
  }

  Future<List<ColorUsage>> getTopColorUsed() async {
    List<ColorUsage> topColors = [];

    for (final Layer layer in _list) {
      final List<ColorUsage> colorsInLayer = await layer.getTopColorUsed();
      for (final ColorUsage colorUsed in colorsInLayer) {
        if (!topColors.any(
          (c) =>
              c.color == colorUsed.color &&
              c.percentage == colorUsed.percentage,
        )) {
          topColors.add(colorUsed);
        }
      }
    }

    topColors.sort((a, b) => b.percentage.compareTo(a.percentage));
    topColors = topColors.take(14).toList();
    return topColors;
  }
}
