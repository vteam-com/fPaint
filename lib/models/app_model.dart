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
/// The `resizeCanvas` method allows resizing the canvas and scaling the layers accordingly.
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

  CanvasModel canvas = CanvasModel();
  late Layers layers = Layers(canvas.size);

  // Selected Tool
  ActionType _selectedTool = ActionType.brush;

  ActionType get selectedTool => _selectedTool;

  bool deviceSizeSmall = false;

  SelectorModel selector = SelectorModel();
  Rect selectorAdjusterRect = Rect.zero;

  void regionErase() {
    selectedLayer.regionCut(selector.path);
    update();
  }

  Future<void> regionCut() async {
    regionCopy();
    regionErase();
  }

  Future<void> paste() async {
    final ui.Image? image = await getImageFromClipboard();
    if (image == null) {
      return;
    }

    final newLayerForPatedImage = addLayerTop('Pasted');
    newLayerForPatedImage.addImage(
      imageToAdd: image,
      offset: const Offset(0, 0),
    );

    // Add the pasted image to the selected layer
    update();
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

  //-------------------------------------------
  bool get canvasResizeLockAspectRatio => canvas.canvasResizeLockAspectRatio;
  set canvasResizeLockAspectRatio(bool value) {
    canvas.canvasResizeLockAspectRatio = value;
    update();
  }

  //-------------------------------------------
  // Canvas Resize position

  int get canvasResizePosition => canvas.resizePosition;
  set canvasResizePosition(int value) {
    canvas.resizePosition = value;
    update();
  } // center

  void resizeCanvas(final int newWidth, final int newHeight) {
    final Size oldSize = canvas.size;
    final Size newSize = Size(newWidth.toDouble(), newHeight.toDouble());
    canvas.size = newSize;

    // Scale layers only when shrinking
    if (newWidth < oldSize.width || newHeight < oldSize.height) {
      final double scaleX = newWidth / oldSize.width;
      final double scaleY = newHeight / oldSize.height;
      final double scale = min(scaleX, scaleY);
      layers.scale(scale);
    }

    // Calculate the offset adjustment based on resize position
    Offset offset = CanvasResizePosition.anchorTranslate(
      canvas.resizePosition,
      oldSize,
      newSize,
    );
    layers.offset(offset);
    update();
  }

  set selectedTool(ActionType value) {
    _selectedTool = value;
    update();
  }

  Offset offset = Offset.zero;
  Offset? lastFocalPoint;

  /// Stores the starting position of a pan gesture for drawing operations.
  UserAction? currentUserAction;
  Offset? userActionStartingOffset;

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

  //----------------------------------------------------------------
  // SidePanel Expanded/Collapsed
  ShellMode shellMode = ShellMode.full;

  bool _isSidePanelExpanded = true;

  bool get isSidePanelExpanded => _isSidePanelExpanded;

  set isSidePanelExpanded(final bool value) {
    _isSidePanelExpanded = value;
    update();
  }

  void resetCanvasSizeAndPlacement() {
    this.offset = Offset.zero;
    this.lastFocalPoint = null;
    this.setCanvasScale(1); // this will notify
  }

  /// Sets the scale of the canvas.
  ///
  /// The scale value is clamped between 10% and 400% to ensure a valid range.
  /// Calling this method will notify any listeners of the [AppModel] that the scale has changed.
  void setCanvasScale(final double value) {
    canvas.scale = value;
    update();
  }

  set brushColor(Color value) {
    _colorForStroke = value;
    update();
  }

  // Color for Fill
  Color _colorForFill = Colors.lightBlue;

  /// The color used to fill the canvas.
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

  // Tolerance
  int _tolarance = 50; // Mid point 0..100
  int get tolerance => _tolarance;
  set tolerance(int value) {
    _tolarance = max(1, min(100, value));
    update();
  }

  int _selectedLayerIndex = 0;
  int get selectedLayerIndex => _selectedLayerIndex;

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

  Layer get selectedLayer => layers.get(selectedLayerIndex);
  bool get isCurrentSelectionReadyForAction => selectedLayer.isVisible;
  Layer addLayerTop([String? name]) {
    return insertLayer(0, name);
  }

  Layer addLayerBottom([String? name]) {
    return insertLayer(layers.length, name);
  }

  /// Inserts a new [Layer] at the specified [index] in the [layers] list.
  ///
  /// If [name] is not provided, a default name will be generated in the format `'Layer{layers.length}'`.
  ///
  /// This method will:
  /// - Create a new [Layer] instance with the provided or generated name.
  /// - Insert the new layer at the specified [index] in the [layers] list.
  /// - Set the [selectedLayerIndex] to the index of the newly inserted layer.
  /// - Call the [update()] method to notify any listeners of the change.
  ///
  /// Returns the newly inserted [Layer] instance.
  Layer insertLayer(final int index, [String? name]) {
    name ??= 'Layer${layers.length}';
    final Layer newLayer = Layer(name: name);
    layers.insert(index, newLayer);
    selectedLayerIndex = layers.getLayerIndex(newLayer);
    update();
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
    required UserAction action,
  }) {
    selectedLayer.addUserAction(action);
    update();
  }

  void updateLastUserAction({
    required final Offset end,
    ActionType? type,
    Color? colorFill,
    Color? colorStroke,
    Offset? start,
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
      selectedLayer.lastActionUpdatePositionEnd(end: end);
    }
    update();
  }

  void selectorStart(final Offset position) {
    // debugPrint('Selector start: $position');
    this.selector.addPosition(position);
    update();
  }

  void selectorMove(final Offset position) {
    // debugPrint('Selector MOVE: $position');
    this.selector.addPosition(position);
    update();
  }

  void selectorEndMovement() {
    // debugPrint('Selector END');
    this.selector.userIsCreatingTheSelector = false;
    update();
  }

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

  /// Notifies all listeners that the model has been updated.
  /// This method should be called whenever the state of the model changes
  /// to ensure that any UI components observing the model are updated.
  void update() {
    notifyListeners();
  }

  /// Toggles the visibility of the specified [Layer].
  ///
  /// This method updates the `isVisible` property of the given [Layer] to the
  /// opposite of its current value, and then calls the `update()` method to
  /// notify any observers of the change.
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

  Future<ui.Image> getImageForCurrentSelectedLayer() async {
    return await selectedLayer.toImageForStorage(canvas.size);
  }
}
