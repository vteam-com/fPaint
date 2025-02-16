// Imports
import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/list_helper.dart';
import 'package:fpaint/providers/layer_provider.dart';
import 'package:provider/provider.dart';

// Exports
export 'package:fpaint/providers/layer_provider.dart';

/// Manages a collection of [LayerProvider] objects, providing methods to interact with and manipulate the layers.
///
/// The [LayersProvider] class is responsible for maintaining the list of layers, providing methods to add, remove, and
/// access individual layers. It also includes utility methods for performing common operations on the layers,
/// such as clearing the layer list, checking for changes, and managing the visibility of layers.
///
/// The class also provides methods for performing transformations on the layers, such as offsetting and scaling
/// the layers, as well as a method to get the top color usage across all layers.

class LayersProvider extends ChangeNotifier {
  factory LayersProvider() {
    return _instance;
  }

  LayersProvider._internal() {
    addWhiteBackgroundLayer();
    clearHasChanged();
  }
  static final LayersProvider _instance = LayersProvider._internal();

  static LayersProvider of(
    final BuildContext context, {
    final bool listen = false,
  }) =>
      Provider.of<LayersProvider>(context, listen: listen);

  void update() {
    notifyListeners();
  }

  Size _size = const Size(0, 0);

  void setSize(final Size size) {
    _size = size;
    _list.forEach((layer) => layer.size = size);
  }

  LayerProvider addWhiteBackgroundLayer() {
    final LayerProvider firstLayer =
        LayerProvider(name: 'Background', size: _size);

    firstLayer.addUserAction(
      UserAction(
        positions: [
          const Offset(0, 0),
          Offset(_size.width, _size.height),
        ],
        action: ActionType.rectangle,
        fillColor: Colors.white,
        brush: MyBrush(color: Colors.white, size: 0),
      ),
    );
    _list.add(firstLayer);
    return firstLayer;
  }

  final List<LayerProvider> _list = [];

  void clear() {
    _list.clear();
  }

  int get length => _list.length;
  bool get isEmpty => _list.isEmpty;
  bool get isNotEmpty => _list.isNotEmpty;
  bool get hasChanged => _list.any((layer) => layer.hasChanged);

  int _selectedLayerIndex = 0;
  int get selectedLayerIndex => _selectedLayerIndex;
  set selectedLayerIndex(final int index) {
    if (this.isIndexInRange(index)) {
      for (int i = 0; i < this.length; i++) {
        final LayerProvider layer = this.get(i);
        layer.id = (this.length - i).toString();
        layer.isSelected = i == index;
      }
      _selectedLayerIndex = index;
      this.get(_selectedLayerIndex).isSelected = true;
      notifyListeners();
    }
  }

  void layersToggleVisibility(final LayerProvider layer) {
    layer.isVisible = !layer.isVisible;
    notifyListeners();
  }

  void clearHasChanged() {
    for (final LayerProvider layer in _list) {
      layer.hasChanged = false;
    }
  }

  bool isIndexInRange(final int indexLayer) =>
      indexLayer >= 0 && indexLayer < _list.length;
  int getLayerIndex(final LayerProvider layer) {
    return _list.indexOf(layer);
  }

  LayerProvider get(final int index) {
    ensureLayerAtIndex(index);
    return _list[index];
  }

  void ensureLayerAtIndex(final int index) {
    while (_list.length <= index) {
      _list.add(
        LayerProvider(
          name: 'Layer ${_list.length + 1}',
          size: _size,
        ),
      );
    }
  }

  LayerProvider? getByName(final String name) {
    return _list.findFirstMatch((layer) => layer.name == name);
  }

  void add(final LayerProvider layerToAdd) {
    _list.insert(0, layerToAdd);
  }

  void insert(final index, final LayerProvider layerToInsert) {
    if (isIndexInRange(index)) {
      _list.insert(index, layerToInsert);
    } else {
      _list.add(layerToInsert);
    }
  }

  bool remove(final LayerProvider layer) {
    final wasRemoved = _list.remove(layer);
    this.selectedLayerIndex =
        (this.selectedLayerIndex > 0 ? this.selectedLayerIndex - 1 : 0);
    return wasRemoved;
  }

  void removeByIndex(final int index) {
    if (isIndexInRange(index)) {
      _list.removeAt(index);
    }
  }

  List<LayerProvider> get list => _list;

  void offset(final Offset offset) {
    for (final LayerProvider layer in _list) {
      layer.offset(offset);
    }
  }

  void scale(final double scale) {
    for (final LayerProvider layer in _list) {
      layer.scale(scale);
    }
  }

  void hideShowAllExcept(final LayerProvider exceptLayer, final bool show) {
    for (final LayerProvider layer in _list) {
      if (layer == exceptLayer) {
        layer.isVisible = true;
      } else {
        layer.isVisible = show;
      }
    }
  }

  /// Retrieves the top most used colors across all layers.
  ///
  /// This method iterates through all layers, collects the top color usage for each layer,
  /// and then aggregates the results to find the overall top 10 most used colors. The
  /// percentage for each color is calculated based on the total number of layers.
  ///
  /// Returns:
  ///   A list of [ColorUsage] objects representing the top 10 most used colors.
  Future<List<ColorUsage>> getTopColorUsed() async {
    List<ColorUsage> topColors = [];
    int totalLayers = _list.length;

    for (final LayerProvider layer in _list) {
      for (final ColorUsage colorUsed in layer.topColorsUsed) {
        final existingColor = topColors.firstWhere(
          (c) => c.color == colorUsed.color,
          orElse: () => colorUsed,
        );
        if (existingColor == colorUsed) {
          topColors.add(colorUsed);
        } else {
          existingColor.percentage += colorUsed.percentage / totalLayers;
        }
      }
    }

    topColors.sort((a, b) => b.percentage.compareTo(a.percentage));
    topColors = topColors.take(20).toList();
    return topColors;
  }
}
