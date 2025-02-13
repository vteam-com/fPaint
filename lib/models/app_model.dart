// Imports

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/canvas_model.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:provider/provider.dart';

// Exports
export 'package:fpaint/models/layers.dart';

/// The `AppModel` class is a `ChangeNotifier` that manages the state of a painting application.
/// It provides methods and properties for managing the canvas, layers, tools, colors, and other
/// aspects of the application.
///
/// The `get` method is a static method that retrieves an instance of the `AppModel` from the
/// provided `BuildContext`. If `listen` is `true`, the returned instance will notify listeners
/// when its state changes.
///
/// The `selectedTool` property represents the currently selected tool, which can be one of the
/// `Tools` enum values. The `brushColor` and `fillColor` properties represent the current
/// stroke and fill colors, respectively.
///
/// The `canvasReset` method allows resizing the canvas and scaling the layers accordingly.
/// The `setCanvasScale` method allows setting the scale of the canvas.
///
/// The `selectedLayerIndex` property represents the index of the currently selected layer,
/// and the `selectedLayer` property returns the currently selected layer.
/// The `addLayerTop`, `addLayerBottom`, and `insertLayer` methods allow adding and inserting
/// new layers.
///
/// The `addUserAction` and `updateLastUserAction` methods allow adding and updating user
/// actions on the currently selected layer.
///
/// The `evaluatTopColor` method calculates the top colors used in the painting and updates
/// the `topColors` property accordingly.
///
/// The `update` method notifies all listeners that the model has been updated.
enum ShellMode {
  hidden,
  minimal,
  full,
}

class AppModel extends ChangeNotifier {
  /// Gets the [AppModel] instance from the provided [BuildContext].
  ///
  /// If [listen] is true, the returned [AppModel] instance will notify listeners
  /// when its state changes. Otherwise, the returned instance will not notify
  /// listeners.
  static AppModel of(
    final BuildContext context, {
    final bool listen = false,
  }) =>
      Provider.of<AppModel>(context, listen: listen);

  String loadedFileName = '';

  bool deviceSizeSmall = false;
  bool centerImageInViewPort = true;

  //----------------------------------------------------
  // All things Canvas
  CanvasModel canvas = CanvasModel();

  int get canvasResizePosition => canvas.resizePosition;
  set canvasResizePosition(int value) {
    canvas.resizePosition = value;
    update();
  } // center

  void canvasReset(final Size size) {
    canvas.size = size;
    centerImageInViewPort = true;
    layers.clear();
    layers.addWhiteBackgroundLayer(size);
    resetView();
  }

  void canvasResize(final int width, final int height) {
    final Size oldSize = canvas.size;
    final Size newSize = Size(width.toDouble(), height.toDouble());
    canvas.size = newSize;

    if (width < oldSize.width || height < oldSize.height) {
      final double scale = min(width / oldSize.width, height / oldSize.height);
      layers.scale(scale);
    }

    Offset offset = CanvasResizePosition.anchorTranslate(
      canvas.resizePosition,
      oldSize,
      newSize,
    );
    layers.offset(offset);
    update();
  }

  void canvasSetScale(final double value) {
    canvas.scale = value;
    update();
  }

  Offset toCanvas(Offset point) {
    return (point - offset) / canvas.scale;
  }

  Offset fromCanvas(Offset point) {
    return (point * canvas.scale) + offset;
  }

  void regionErase() {
    selectedLayer.regionCut(selector.path);
    update();
  }

  Future<void> regionCut() async {
    regionCopy();
    regionErase();
  }

  Future<void> regionCopy() async {
    if (selector.path.getBounds().isEmpty) {
      // nothing to copy
      return;
    }

    final ui.Image image = await getImageForCurrentSelectedLayer();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    // Get the bounds of the selected path
    final Rect bounds = selector.path.getBounds();

    // Translate canvas so the clipped area is positioned at (0,0)
    canvas.translate(-bounds.left, -bounds.top);

    // Clip the canvas with the selected path
    canvas.clipPath(selector.path);

    // Draw the image, making sure to align it properly
    canvas.drawImage(image, Offset.zero, Paint());

    // Convert the recorded drawing into an image
    final ui.Image clippedImage = await recorder.endRecording().toImage(
          bounds.width.toInt(),
          bounds.height.toInt(),
        );

    // Copy the image to the clipboard
    await copyImageToClipboard(clippedImage);
  }

  Future<void> paste() async {
    final ui.Image? image = await getImageFromClipboard();
    if (image == null) {
      return;
    }

    final Layer newLayerForPatedImage = layersAddTop('Pasted');
    newLayerForPatedImage.addImage(
      imageToAdd: image,
      offset: const Offset(0, 0),
    );

    // Add the pasted image to the selected layer
    update();
  }

  bool get canvasResizeLockAspectRatio => canvas.canvasResizeLockAspectRatio;
  set canvasResizeLockAspectRatio(bool value) {
    canvas.canvasResizeLockAspectRatio = value;
    update();
  }

  Offset offset = Offset.zero;
  Offset? lastFocalPoint;

  /// Stores the starting position of a pan gesture for drawing operations.
  UserAction? currentUserAction;

  // Color for Stroke
  Color _colorForStroke = Colors.black;

  Color get brushColor => _colorForStroke;

  //----------------------------------------------------------------
  // SidePanel Expanded/Collapsed
  bool _showMenu = false;

  bool get showMenu => _showMenu;

  set showMenu(final bool value) {
    _showMenu = value;
    update();
  }

  void resetView() {
    lastFocalPoint = null;
    offset = Offset.zero;
    canvas.scale = 1;
    centerImageInViewPort = true;
    update();
  }

  //----------------------------------------------------------------
  // SidePanel Expanded/Collapsed
  ShellMode shellMode = ShellMode.full;

  bool _isSidePanelExpanded = true;

  bool get isSidePanelExpanded => _isSidePanelExpanded;

  set isSidePanelExpanded(final bool value) {
    _isSidePanelExpanded = value;
    update();
  }

  //----------------------------------------------------
  // All things Layers
  late Layers layers = Layers(canvas.size);
  int _selectedLayerIndex = 0;
  int get selectedLayerIndex => _selectedLayerIndex;
  Layer get selectedLayer => layers.get(selectedLayerIndex);
  bool get isCurrentSelectionReadyForAction => selectedLayer.isVisible;

  /// Sets the index of the currently selected layer.
  ///
  /// If the provided `index` is within the range of the `layers` list, this method will:
  /// - Update the `id` property of each layer to reflect its position in the list (from bottom to top).
  /// - Set the `isSelected` property of the layer at the provided `index` to `true`.
  /// - Set the `_selectedLayerIndex` private field to the provided `index`.
  /// - Call the `update()` method to notify any listeners of the change.
  ///
  /// If the provided `index` is not within the range of the `layers` list, this method will do nothing.
  set selectedLayerIndex(final int index) {
    if (layers.isIndexInRange(index)) {
      for (int i = 0; i < layers.length; i++) {
        final Layer layer = layers.get(i);
        layer.id = (layers.length - i).toString();
        layer.isSelected = i == index;
      }
      _selectedLayerIndex = index;
      layers.get(_selectedLayerIndex).isSelected = true;
      update();
    }
  }

  Layer layersAddTop([String? name]) => layerInsertAt(0, name);
  Layer layersAddBottom([String? name]) => layerInsertAt(layers.length, name);
  Layer layerInsertAt(final int index, [String? name]) {
    name ??= 'Layer${layers.length}';
    final Layer layer = Layer(name: name);
    layers.insert(index, layer);
    selectedLayerIndex = layers.getLayerIndex(layer);
    update();
    return layer;
  }

  void layersRemove(final Layer layer) {
    layers.remove(layer);
    selectedLayerIndex = (selectedLayerIndex > 0 ? selectedLayerIndex - 1 : 0);
  }

  bool layersIsLayerVisible(final int layerIndex) {
    if (layers.isIndexInRange(layerIndex)) {
      return layers.get(layerIndex).isVisible;
    }
    return false;
  }

  void layersAddActionToSelectedLayer({
    required UserAction action,
  }) {
    selectedLayer.addUserAction(action);
    update();
  }

  void layersToggleVisibility(final Layer layer) {
    layer.isVisible = !layer.isVisible;
    update();
  }

  void layersUndo() {
    selectedLayer.undo();
    update();
  }

  void layersRedo() {
    selectedLayer.redo();
    update();
  }

  Future<ui.Image> getImageForCurrentSelectedLayer() async {
    return await selectedLayer.toImageForStorage(canvas.size);
  }

  //----------------------------------------------------
  // All things Tools/UserActions

  //-------------------------
  // Selected Tool
  ActionType _selectedTool = ActionType.brush;

  set selectedTool(ActionType value) {
    _selectedTool = value;
    update();
  }

  ActionType get selectedTool => _selectedTool;

  //-------------------------
  // Brush
  set brushColor(Color value) {
    _colorForStroke = value;
    update();
  }

  //-------------------------
  // Brush Style
  BrushStyle _brush = BrushStyle.solid;
  BrushStyle get brushStyle => _brush;
  set brushStyle(BrushStyle value) {
    _brush = value;
    update();
  }

  //-------------------------
  // Line Weight
  double _lineWeight = 5;
  double get brusSize => _lineWeight;
  set brusSize(double value) {
    _lineWeight = value;
    update();
  }

  //-------------------------
  // Color for Fill
  Color _fillColor = Colors.lightBlue;

  /// The color used to fill the canvas.
  Color get fillColor => _fillColor;

  set fillColor(Color value) {
    _fillColor = value;
    update();
  }

  //-------------------------
  // Tolerance
  int _tolarance = 50; // Mid point 0..100
  int get tolerance => _tolarance;
  set tolerance(int value) {
    _tolarance = max(1, min(100, value));
    update();
  }

  void updateAction({
    Offset? start,
    required final Offset end,
    ActionType? type,
    Color? colorFill,
    Color? colorStroke,
  }) {
    if (start != null &&
        type != null &&
        colorFill != null &&
        colorStroke != null) {
      selectedLayer.addUserAction(
        UserAction(
          positions: [start, end],
          tool: type,
          brush: MyBrush(
            color: colorStroke,
            size: this.brusSize,
          ),
          fillColor: colorFill,
        ),
      );
    } else {
      updateActionEnd(end);
    }
    update();
  }

  void updateActionEnd(final Offset position) {
    selectedLayer.lastUserAction!.positions.last = position;
  }

  void appendLineFromLastUserAction(final Offset positionEndOfNewLine) {
    selectedLayer.addUserAction(
      UserAction(
        positions: [
          selectedLayer.lastUserAction!.positions.last,
          positionEndOfNewLine,
        ],
        tool: selectedLayer.lastUserAction!.tool,
        brush: selectedLayer.lastUserAction!.brush,
      ),
    );

    update();
  }

  //-------------------------
  // Selector
  SelectorModel selector = SelectorModel();

  void selectorStart(final Offset position) {
    if (!selector.isVisible) {
      selector.addP1(position);
      update();
    }
  }

  void selectorMove(final Offset position) {
    selector.addP2(position);
    update();
  }

  void selectorEnd() {
    selector.p1 = null;
    update();
  }

  //----------------------------------------------------
  // Top Colors used
  List<ColorUsage> topColors = [
    ColorUsage(Colors.white, 1),
    ColorUsage(Colors.black, 1),
  ];

  void evaluatTopColor() {
    this.layers.getTopColorUsed().then((topColorsFound) {
      topColors = topColorsFound;
      update();
    });
  }

  //----------------------------------------------------
  /// Notifies all listeners that the model has been updated.
  /// This method should be called whenever the state of the model changes
  /// to ensure that any UI components observing the model are updated.
  void update() {
    notifyListeners();
  }
}
