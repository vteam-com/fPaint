// Imports
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/list_helper.dart';
import 'package:fpaint/models/app_model.dart';

// Exports
export 'package:fpaint/models/user_action.dart';

class PaintLayer {
  PaintLayer({required this.name});
  String name;
  List<UserAction> actionStack = [];
  List<UserAction> redoStack = [];
  bool isVisible = true;
  double opacity = 1;

  void addImage(ui.Image imageToAdd, ui.Offset offset) {
    actionStack.add(
      UserAction(
        type: Tools.image,
        start: offset,
        end: Offset(
          offset.dx + imageToAdd.width.toDouble(),
          offset.dy + imageToAdd.height.toDouble(),
        ),
        colorOutline: Colors.transparent,
        colorFill: Colors.transparent,
        brushSize: 0,
        image: imageToAdd,
      ),
    );
  }
}

class Layers {
  Layers(final Size size) {
    final PaintLayer firstLayer = PaintLayer(name: 'Background');

    firstLayer.actionStack.add(
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
  void clear() => _list.clear();
  int get length => _list.length;

  bool isIndexInRange(final int indexLayer) =>
      indexLayer >= 0 && indexLayer < _list.length;

  int getLayerIndex(final PaintLayer layer) {
    return _list.indexOf(layer);
  }

  PaintLayer get(final int index) {
    return _list[index];
  }

  PaintLayer? getByName(final String name) {
    return _list.findFirstMatch((layer) => layer.name == name);
  }

  void add(final PaintLayer layerToAdd) {
    _list.insert(0, layerToAdd);
  }

  void insert(final index, final PaintLayer layerToInsert) {
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

  List<PaintLayer> get list => _list;
}
