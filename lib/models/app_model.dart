// Imports

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/canvas_model.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/panels/tools/flood_fill.dart';
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

  //=============================================================================
  // All things Canvas
  CanvasModel canvas = CanvasModel();

  Offset offset = Offset.zero;

  int get canvasResizePosition => canvas.resizePosition;
  set canvasResizePosition(int value) {
    canvas.resizePosition = value;
    update();
  } // center

  void canvasReset(final Size size) {
    canvas.size = size;
    centerImageInViewPort = true;
    layers.clear();
    _selectedLayerIndex = 0;
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

  //=============================================================================
  // SidePanel Expanded/Collapsed
  bool _showMenu = false;
  bool get showMenu => _showMenu;
  set showMenu(final bool value) {
    _showMenu = value;
    update();
  }

  void resetView() {
    offset = Offset.zero;
    canvas.scale = 1;
    centerImageInViewPort = true;
    update();
  }

  //=============================================================================
  // Shell
  ShellMode shellMode = ShellMode.full;

  bool _isSidePanelExpanded = true;
  bool get isSidePanelExpanded => _isSidePanelExpanded;
  set isSidePanelExpanded(final bool value) {
    _isSidePanelExpanded = value;
    update();
  }

  //=============================================================================
  // All things Layers
  late Layers layers = Layers(canvas.size);
  Layer get selectedLayer => layers.get(selectedLayerIndex);

  int _selectedLayerIndex = 0;
  int get selectedLayerIndex => _selectedLayerIndex;
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

  bool get isCurrentSelectionReadyForAction => selectedLayer.isVisible;

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

  //=============================================================================
  // All things Tools/UserActions

  //-------------------------
  // Selected Tool
  ActionType _selectedAction = ActionType.brush;
  set selectedAction(ActionType value) {
    _selectedAction = value;
    update();
  }

  ActionType get selectedAction => _selectedAction;

  //-------------------------
  // Line Weight
  double _lineWeight = 5;
  double get brusSize => _lineWeight;
  set brusSize(double value) {
    _lineWeight = value;
    update();
  }

  //-------------------------
  // Brush Style
  BrushStyle _brushStyle = BrushStyle.solid;
  BrushStyle get brushStyle => _brushStyle;
  set brushStyle(BrushStyle value) {
    _brushStyle = value;
    update();
  }

  //-------------------------
  // Brush Color
  Color _brushColor = Colors.black;
  Color get brushColor => _brushColor;
  set brushColor(Color value) {
    _brushColor = value;
    update();
  }

  //-------------------------
  // Color for Fill
  Color _fillColor = Colors.lightBlue;
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
          action: type,
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
        action: selectedLayer.lastUserAction!.action,
        brush: selectedLayer.lastUserAction!.brush,
      ),
    );

    update();
  }

  void floodFillAction(final Offset position) async {
    final Region region = await getRegionPathFromLayerImage(position);

    selectedLayer.addRegion(
      path: region.path
          .shift(Offset(region.left.toDouble(), region.top.toDouble())),
      color: this.fillColor,
    );
    update();
  }

  Future<Region> getRegionPathFromLayerImage(ui.Offset position) async {
    final ui.Image img = await getImageForCurrentSelectedLayer();

    // Perform flood fill at the clicked position
    final Region region = await extractRegionByColorEdgeAndOffset(
      image: img,
      x: position.dx.toInt(),
      y: position.dy.toInt(),
      tolerance: this.tolerance,
    );
    return region;
  }

  //-------------------------
  // Selector
  SelectorModel selector = SelectorModel();

  void selectorStart(final Offset position) {
    if (!selector.isVisible) {
      if (selector.mode == SelectorMode.wand) {
        getRegionPathFromLayerImage(position).then((final Region region) {
          selector.isVisible = true;
          selector.path = region.path.shift(region.offset);
          update();
        });
      } else {
        selector.addP1(position);
        update();
      }
    }
  }

  void selectorMove(final Offset position) {
    if (selector.mode == SelectorMode.wand) {
      // Ignore since the PointerDown already did the job of drawing the shape of the selector
    } else {
      selector.addP2(position);
      update();
    }
  }

  void selectorEnd() {
    selector.p1 = null;
    update();
  }

  Path pathFromSelectorMode(
    final Offset viewPortPoint1,
    final Offset viewPortPoint2,
  ) {
    switch (this.selector.mode) {
      case SelectorMode.rectangle:
        return Path()..addRect(Rect.fromPoints(viewPortPoint1, viewPortPoint2));

      case SelectorMode.circle:
        return Path()..addOval(Rect.fromPoints(viewPortPoint1, viewPortPoint2));

      case SelectorMode.wand:
        final Rect bounds = selector.path.getBounds();

        // Step 2: Calculate the offset
        final Offset offset = Offset(
          min(viewPortPoint1.dx, viewPortPoint2.dx) - bounds.left,
          min(viewPortPoint1.dy, viewPortPoint2.dy) - bounds.top,
        );

        // Step 3: Shift the path to align with p1 and p2
        var alignedPath = selector.path.shift(offset);

        return alignedPath;
    }
  }

  //-------------------------
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

  //=============================================================================
  /// Notifies all listeners that the model has been updated.
  /// This method should be called whenever the state of the model changes
  /// to ensure that any UI components observing the model are updated.
  void update() {
    notifyListeners();
  }
}
