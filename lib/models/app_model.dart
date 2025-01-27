// Imports
import 'package:flutter/material.dart';
import 'package:fpaint/models/layers.dart';
import 'package:provider/provider.dart';

// Exports
export 'package:fpaint/models/layers.dart';

class AppModel extends ChangeNotifier {
  /// Gets the [AppModel] instance from the provided [BuildContext].
  ///
  /// If [listen] is true, the returned [AppModel] instance will notify listeners
  /// when its state changes. Otherwise, the returned instance will not notify
  /// listeners.
  static AppModel get(
    final BuildContext context, {
    final bool listen = false,
  }) =>
      Provider.of<AppModel>(context, listen: listen);

  String loadedFileName = '';

  Size canvasSize = const Size(800, 600); // Default canvas size
  late Layers layers = Layers(canvasSize);

  double get width => canvasSize.width * scale;
  double get height => canvasSize.height * scale;
  Size get canvasSizeScaled => Size(width, height);

  // Selected Tool
  Tools _selectedTool = Tools.draw;

  Tools get selectedTool => _selectedTool;

  set selectedTool(Tools value) {
    _selectedTool = value;
    update();
  }

  /// Stores the starting position of a pan gesture for drawing operations.
  UserAction? currentUserAction;
  Offset? userActionStartingOffset;

  // Color for Stroke
  Color _colorForStroke = Colors.black;

  Color get brushColor => _colorForStroke;

  // Scale
  double _scale = 1;
  double get scale => _scale;

  // SidePanel Expanded/Collapsed
  bool _isSidePanelExpanded = true;

  bool get isSidePanelExpanded => _isSidePanelExpanded;

  set isSidePanelExpanded(bool value) {
    _isSidePanelExpanded = value;
    update();
  }

  /// Sets the scale of the canvas.
  ///
  /// The scale value is clamped between 10% and 400% to ensure a valid range.
  /// Calling this method will notify any listeners of the [AppModel] that the scale has changed.
  set scale(final double value) {
    _scale = value.clamp(10 / 100, 400 / 100);
    update();
  }

  set brushColor(Color value) {
    _colorForStroke = value;
    update();
  }

  // Color for Fill
  Color _colorForFill = Colors.lightBlue;

  Color get fillColor => _colorForFill;

  set fillColor(Color value) {
    _colorForFill = value;
    update();
  }

  // Line Weight
  double _lineWeight = 5;
  double get brusSize => _lineWeight;
  set brusSize(double value) {
    _lineWeight = value;
    update();
  }

  // Brush Style
  BrushStyle _brush = BrushStyle.solid;
  BrushStyle get brushStyle => _brush;
  set brushStyle(BrushStyle value) {
    _brush = value;
    update();
  }

  int _selectedLayerIndex = 0;
  int get selectedLayerIndex => _selectedLayerIndex;

  set selectedLayerIndex(final int index) {
    if (layers.isIndexInRange(index)) {
      for (int i = 0; i < layers.length; i++) {
        final Layer layer = layers.get(i);
        layer.id = i.toString();
        layer.isSelected = i == index;
      }
      _selectedLayerIndex = index;
      layers.get(_selectedLayerIndex).isSelected = true;
      update();
    }
  }

  Layer get selectedLayer => layers.get(selectedLayerIndex);

  Layer addLayerTop([String? name]) {
    return insertLayer(0, name);
  }

  Layer addLayerBottom([String? name]) {
    return insertLayer(layers.length, name);
  }

  Layer insertLayer(final int index, [String? name]) {
    name ??= 'Layer${layers.length}';
    final Layer newLayer = Layer(name: name);
    layers.insert(index, newLayer);
    selectedLayerIndex = layers.getLayerIndex(newLayer);
    return newLayer;
  }

  void removeLayer(final Layer layer) {
    layers.remove(layer);
    selectedLayerIndex = (selectedLayerIndex > 0 ? selectedLayerIndex - 1 : 0);
  }

  bool isVisible(final int layerIndex) {
    if (layers.isIndexInRange(layerIndex)) {
      return layers.get(layerIndex).isVisible;
    }
    return false;
  }

  void addUserAction({
    UserAction? action,
    Tools? type,
    Color? colorFill,
    Color? colorStroke,
    Offset? start,
    Offset? end,
  }) {
    if (action != null) {
      selectedLayer.addUserAction(action);
    } else if (start != null &&
        end != null &&
        type != null &&
        colorFill != null &&
        colorStroke != null) {
      if (_isWithinCanvas(start) && _isWithinCanvas(end)) {
        selectedLayer.addUserAction(
          UserAction(
            positions: [start, end],
            tool: type,
            fillColor: colorFill,
            brushColor: colorStroke,
            brushSize: this.brusSize,
          ),
        );
      }
    }
    update();
  }

  void updateLastUserAction(final Offset end) {
    selectedLayer.updateLastUserActionEndPosition(end);
    update();
  }

  void update() {
    notifyListeners();
  }

  bool _isWithinCanvas(Offset point) {
    return point.dx >= 0 &&
        point.dx <= canvasSize.width &&
        point.dy >= 0 &&
        point.dy <= canvasSize.height;
  }

  void toggleLayerVisibility(final Layer layer) {
    layer.isVisible = !layer.isVisible;
    update();
  }

  void undo() {
    selectedLayer.undo();
    update();
  }

  void redo() {
    selectedLayer.redo();
    update();
  }
}
