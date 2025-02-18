// Imports

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/panels/tools/flood_fill.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:provider/provider.dart';

// Exports
export 'package:fpaint/providers/layers_provider.dart';

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
/// brush and fill colors, respectively.
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
class AppProvider extends ChangeNotifier {
  AppProvider() {
    this.canvasClear(layers.size);
  }

  /// Gets the [AppProvider] instance from the provided [BuildContext].
  ///
  /// If [listen] is true, the returned [AppProvider] instance will notify listeners
  /// when its state changes. Otherwise, the returned instance will not notify
  /// listeners.
  static AppProvider of(
    final BuildContext context, {
    final bool listen = false,
  }) =>
      Provider.of<AppProvider>(context, listen: listen);

  //=============================================================================
  // All things Canvas
  Offset offset = Offset.zero;

  void canvasClear(final Size size) {
    layers.clear();
    layers.size = size;
    layers.addWhiteBackgroundLayer();
    layers.selectedLayerIndex = 0;
    resetView();
  }

  Offset toCanvas(Offset point) {
    return (point - offset) / layers.scale;
  }

  Offset fromCanvas(Offset point) {
    return (point * layers.scale) + offset;
  }

  void regionErase() {
    layers.selectedLayer.regionCut(selector.path);
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

    final ui.Image image =
        layers.selectedLayer.toImageForStorage(this.layers.size);

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

    final LayerProvider newLayerForPatedImage = layers.addTop('Pasted');
    newLayerForPatedImage.addImage(
      imageToAdd: image,
      offset: const Offset(0, 0),
    );

    // Add the pasted image to the selected layer
    update();
  }

  bool get canvasResizeLockAspectRatio => layers.canvasResizeLockAspectRatio;
  set canvasResizeLockAspectRatio(bool value) {
    layers.canvasResizeLockAspectRatio = value;
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
    layers.scale = 1;
    update();
  }

  //=============================================================================
  // All things Layers
  LayersProvider layers = LayersProvider(); // this is a singleton

  void addActionToSelectedLayer({
    required UserAction action,
  }) {
    if (selector.isVisible) {
      action.clipPath = selector.path;
    }
    layers.selectedLayer.addUserAction(action);
    update();
  }

  void layersUndo() {
    layers.selectedLayer.undo();
    update();
  }

  void layersRedo() {
    layers.selectedLayer.redo();
    update();
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
    Color? colorBrush,
  }) {
    if (start != null &&
        type != null &&
        colorFill != null &&
        colorBrush != null) {
      layers.selectedLayer.addUserAction(
        UserAction(
          positions: <ui.Offset>[start, end],
          action: type,
          brush: MyBrush(
            color: colorBrush,
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
    layers.selectedLayer.lastUserAction!.positions.last = position;
  }

  void appendLineFromLastUserAction(final Offset positionEndOfNewLine) {
    layers.selectedLayer.addUserAction(
      UserAction(
        positions: <ui.Offset>[
          layers.selectedLayer.lastUserAction!.positions.last,
          positionEndOfNewLine,
        ],
        action: layers.selectedLayer.lastUserAction!.action,
        brush: layers.selectedLayer.lastUserAction!.brush,
        clipPath: selector.isVisible ? selector.path : null,
      ),
    );

    update();
  }

  void floodFillAction(final Offset position) async {
    final Region region = await getRegionPathFromLayerImage(position);

    final ui.Path path = region.path
        .shift(Offset(region.left.toDouble(), region.top.toDouble()));

    final ui.Rect bounds = path.getBounds();

    this.layers.selectedLayer.addUserAction(
          UserAction(
            action: ActionType.region,
            path: path,
            positions: <ui.Offset>[
              bounds.topLeft,
              bounds.bottomRight,
            ],
            fillColor: this.fillColor,
            clipPath: selector.isVisible ? selector.path : null,
          ),
        );

    update();
  }

  Future<Region> getRegionPathFromLayerImage(ui.Offset position) async {
    final ui.Image img = layers.selectedLayer.toImageForStorage(layers.size);

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
      // Ignore since the PointerDown it already did the job of drawing the shape of the selector
    } else {
      selector.addP2(position);
      update();
    }
  }

  void selectorEnd() {
    selector.p1 = null;
    update();
  }

  void selectAll() {
    selector.isVisible = true;
    selectorStart(Offset.zero);
    selector.path = Path();
    selector.path.addRect(
      Rect.fromPoints(Offset.zero, Offset(layers.width, layers.height)),
    );
  }

  Path getPathAdjustToCanvasSizeAndPosition() {
    final Matrix4 matrix = Matrix4.identity()
      ..translate(offset.dx, offset.dy)
      ..scale(layers.scale);
    return selector.path.transform(matrix.storage);
  }

  //=============================================================================
  /// Notifies all listeners that the model has been updated.
  /// This method should be called whenever the state of the model changes
  /// to ensure that any UI components observing the model are updated.
  void update() {
    notifyListeners();
  }
}
