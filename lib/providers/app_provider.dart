// Imports

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/panels/tools/flood_fill.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';

// Exports
export 'package:fpaint/providers/layers_provider.dart';

class UserLayerAction {}

/// The `AppProvider` class is a `ChangeNotifier` that manages the state of the application,
/// including the canvas, layers, and selection tools. It provides methods for interacting
/// with the canvas, such as clearing the canvas, converting between canvas and screen
/// coordinates, and performing region-based operations like erasing and cutting.
class AppProvider extends ChangeNotifier {
  AppProvider() {
    this.canvasClear(layers.size);

    // this will initialize and load the preferencefor the first time
    try {
      this.preferences.getPref().then(
        (final _) {
          update();
        },
      );
    } catch (error) {
      // TODO
    }
  }

  final AppPreferences preferences = AppPreferences();
  bool get isPreferencesLoaded => preferences.isLoaded;

  final UndoProvider _undoProvider = UndoProvider();

  UndoProvider get undoProvider => _undoProvider;

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

  Offset toCanvas(final Offset point) {
    return (point - offset) / layers.scale;
  }

  Offset fromCanvas(final Offset point) {
    return (point * layers.scale) + offset;
  }

  void regionErase() {
    if (selector.path1 != null) {
      recordExecuteDrawingActionToSelectedLayer(
        action: UserActionDrawing(
          action: ActionType.cut,
          positions: <ui.Offset>[],
          path: Path.from(selector.path1!),
        ),
      );
      this.update();
    }
  }

  Future<void> regionCut() async {
    regionCopy();
    regionErase();
  }

  Future<void> regionCopy() async {
    final ui.Rect bounds = selector.path1!.getBounds();
    if (bounds.isEmpty) {
      // nothing to copy
      return;
    }

    final ui.Image image =
        layers.selectedLayer.toImageForStorage(this.layers.size);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    // Translate canvas so the clipped area is positioned at (0,0)
    canvas.translate(-bounds.left, -bounds.top);

    // Clip the canvas with the selected path
    canvas.clipPath(selector.path1!);

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
    final int currentIndex = layers.selectedLayerIndex;
    int newLayerIndex = -1;

    _undoProvider.executeAction(
      name: 'Paste',
      forward: () {
        final LayerProvider newLayerForPatedImage = layers.addTop('Pasted');
        newLayerIndex = layers.getLayerIndex(newLayerForPatedImage);
        newLayerForPatedImage.addImage(
          imageToAdd: image,
          offset: const Offset(0, 0),
        );
        // Add the pasted image to the selected layer
        update();
      },
      backward: () {
        // Step 1
        layers.removeByIndex(newLayerIndex);

        // Step 2 -restore the selected layer
        layers.selectedLayerIndex = currentIndex;
        update();
      },
    );
  }

  bool get canvasResizeLockAspectRatio => layers.canvasResizeLockAspectRatio;
  set canvasResizeLockAspectRatio(final bool value) {
    layers.canvasResizeLockAspectRatio = value;
    update();
  }

  //=============================================================================
  // SidePanel Expanded/Collapsed

  void resetView() {
    offset = Offset.zero;
    layers.scale = 1;
    update();
  }

  //=============================================================================
  // All things Layers
  LayersProvider layers = LayersProvider(); // this is a singleton

  void recordExecuteDrawingActionToSelectedLayer({
    required final UserActionDrawing action,
  }) {
    if (selector.isVisible) {
      action.clipPath = selector.path1;
    }

    _undoProvider.executeAction(
      name: action.action.name,
      forward: () => layers.selectedLayer.appendDrawingAction(action),
      backward: () => layers.selectedLayer.undo(),
    );

    layers.update();
  }

  void undoAction() {
    _undoProvider.undo();
    update();
  }

  void redoAction() {
    _undoProvider.redo();
    update();
  }

  /// Centers the canvas within the view.
  ///
  /// This method adjusts the position of the canvas so that it is centered
  /// within the available space. It ensures that the canvas is properly
  /// aligned and visible to the user.
  void canvasCenterAndFit({
    required final double containerWidth,
    required final double containerHeight,
    required final bool scaleToContainer,
    required final bool notifyListener,
  }) {
    double adjustedScale = this.layers.scale;
    if (scaleToContainer) {
      final double scaleX = containerWidth / this.layers.width;
      final double scaleY = containerHeight / this.layers.height;
      adjustedScale = (min(scaleX, scaleY) * 10).floor() / 10;
    }

    final double scaledWidth = (this.layers.width * adjustedScale);
    final double scaledHeight = (this.layers.height * adjustedScale);

    final double centerX = containerWidth / 2;
    final double centerY = containerHeight / 2;

    this.offset = Offset(
      centerX - (scaledWidth / 2),
      centerY - (scaledHeight / 2),
    );
    this.layers.scale = adjustedScale;
  }

  //=============================================================================
  // All things Tools/UserActions

  //-------------------------
  // Selected Tool
  ActionType _selectedAction = ActionType.brush;
  set selectedAction(final ActionType value) {
    _selectedAction = value;
    update();
  }

  ActionType get selectedAction => _selectedAction;

  //-------------------------
  // Line Weight

  double get brushSize => preferences.brushSize;
  set brushSize(final double value) {
    preferences.setBrushSize(value);
    update();
  }

  //-------------------------
  // Brush Style
  BrushStyle _brushStyle = BrushStyle.solid;
  BrushStyle get brushStyle => _brushStyle;
  set brushStyle(final BrushStyle value) {
    _brushStyle = value;
    update();
  }

  //-------------------------
  // Brush Color
  Color get brushColor => preferences.brushColor;
  set brushColor(final Color value) {
    preferences.setBrushColor(value);
    update();
  }

  //-------------------------
  // Color for Fill
  Color get fillColor => preferences.fillColor;
  set fillColor(final Color value) {
    preferences.setFillColor(value);
    update();
  }

  //-------------------------
  // Tolerance
  int _tolarance = 50; // Mid point 0..100
  int get tolerance => _tolarance;
  set tolerance(final int value) {
    _tolarance = max(1, min(100, value));
    update();
  }

  void updateAction({
    final Offset? start,
    required final Offset end,
    final ActionType? type,
    final Color? colorFill,
    final Color? colorBrush,
  }) {
    if (start != null &&
        type != null &&
        colorFill != null &&
        colorBrush != null) {
      recordExecuteDrawingActionToSelectedLayer(
        action: UserActionDrawing(
          positions: <ui.Offset>[start, end],
          action: type,
          brush: MyBrush(
            color: colorBrush,
            size: this.brushSize,
          ),
          fillColor: colorFill,
        ),
      );
    } else {
      updateActionEnd(end);
    }
  }

  void updateActionEnd(final Offset position) {
    layers.selectedLayer.lastUserAction!.positions.last = position;
  }

  void appendLineFromLastUserAction(final Offset positionEndOfNewLine) {
    recordExecuteDrawingActionToSelectedLayer(
      action: UserActionDrawing(
        positions: <ui.Offset>[
          layers.selectedLayer.lastUserAction!.positions.last,
          positionEndOfNewLine,
        ],
        action: layers.selectedLayer.lastUserAction!.action,
        brush: layers.selectedLayer.lastUserAction!.brush,
        clipPath: selector.isVisible ? selector.path1 : null,
      ),
    );
  }

  void floodFillAction(final Offset position) async {
    final Region region = await getRegionPathFromLayerImage(position);

    final ui.Path path = region.path
        .shift(Offset(region.left.toDouble(), region.top.toDouble()));

    final ui.Rect bounds = path.getBounds();

    recordExecuteDrawingActionToSelectedLayer(
      action: UserActionDrawing(
        action: ActionType.region,
        path: path,
        positions: <ui.Offset>[
          bounds.topLeft,
          bounds.bottomRight,
        ],
        fillColor: this.fillColor,
        clipPath: selector.isVisible ? selector.path1 : null,
      ),
    );
  }

  Future<Region> getRegionPathFromLayerImage(final ui.Offset position) async {
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

  bool isReadyForDrawing() {
    if (selectedAction == ActionType.selector) {
      return false;
    }
    return true;
  }

  void selectorCreationStart(final Offset position) {
    if (selector.mode == SelectorMode.wand) {
      getRegionPathFromLayerImage(position).then((final Region region) {
        selector.isVisible = true;
        if (selector.math == SelectorMath.replace) {
          selector.path1 = region.path.shift(region.offset);
        } else {
          selector.path2 = region.path.shift(region.offset);
        }
        update();
      });
    } else {
      selector.addP1(position);
      update();
    }
  }

  void selectorCreationAdditionalPoint(final Offset position) {
    if (selector.mode == SelectorMode.wand) {
      // Ignore since the PointerDown it already did the job of drawing the shape of the selector
    } else {
      selector.addP2(position);
      update();
    }
  }

  void selectorCreationEnd() {
    selector.applyMath();
    update();
  }

  void selectAll() {
    selector.isVisible = true;
    selectorCreationStart(Offset.zero);
    selector.path1 = Path()
      ..addRect(
        Rect.fromPoints(Offset.zero, Offset(layers.width, layers.height)),
      );
  }

  Path? getPathAdjustToCanvasSizeAndPosition(final Path? path) {
    if (path != null) {
      final Matrix4 matrix = Matrix4.identity()
        ..translate(offset.dx, offset.dy)
        ..scale(layers.scale);
      return path.transform(matrix.storage);
    }
    return null;
  }

  void crop() async {
    final Rect bounds = selector.path1!.getBounds();
    final Offset selectionOffset = Offset(-bounds.left, -bounds.top);
    final Size originalSize = layers.size;

    _undoProvider.executeAction(
      name: 'Crop',
      forward: () {
        this.layers.offsetContent(selectionOffset);

        // Resize each layer and its content to crop to the bounds
        this.layers.canvasResize(
              bounds.width.toInt(),
              bounds.height.toInt(),
              CanvasResizePosition.topLeft,
            );

        // Clear the selector
        selector.clear();
        update();
      },
      backward: () {
        // Uncrop: restore the original size and offset
        this.layers.canvasResize(
              originalSize.width.toInt(),
              originalSize.height.toInt(),
              CanvasResizePosition.topLeft,
            );
        this.layers.offsetContent(-selectionOffset);
        update();
      },
    );
  }

  //=============================================================================
  /// Notifies all listeners that the model has been updated.
  /// This method should be called whenever the state of the model changes
  /// to ensure that any UI components observing the model are updated.
  void update() {
    notifyListeners();
  }
}
