// Imports

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/canvas_resize.dart';
import 'package:fpaint/models/fill_model.dart';
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

  final Debouncer _debounceGradientFill = Debouncer();

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
  Offset canvasOffset = Offset.zero;

  void canvasClear(final Size size) {
    layers.clear();
    layers.size = size;
    layers.addWhiteBackgroundLayer();
    layers.selectedLayerIndex = 0;
    resetView();
  }

  Offset toCanvas(final Offset point) {
    return (point - canvasOffset) / layers.scale;
  }

  Offset fromCanvas(final Offset point) {
    return (point * layers.scale) + canvasOffset;
  }

  void applyScaleToCanvas({
    required final double scaleDelta,
    final ui.Offset? anchorPoint, // optional anchoer point
    final bool notifyListener = true,
  }) {
    // Step 1: Convert screen coordinates to canvas coordinates
    final Offset before =
        anchorPoint == null ? Offset.zero : this.toCanvas(anchorPoint);

    for (final GradientPoint point in this.fillModel.gradientPoints) {
      point.offset = this.toCanvas(point.offset);
    }

    // Step 2: Apply the scale change
    this.layers.scale = this.layers.scale * scaleDelta;

    // Step 3: Calculate the new position on the canvas
    final Offset after =
        anchorPoint == null ? Offset.zero : this.toCanvas(anchorPoint);

    // Step 4: Adjust the offset to keep the cursor anchored
    final Offset offsetDelta = (before - after);

    this.canvasOffset -= offsetDelta * this.layers.scale;

    for (final GradientPoint point in this.fillModel.gradientPoints) {
      point.offset = this.fromCanvas(point.offset);
    }
    if (notifyListener) {
      update();
    }
  }

  Offset get canvasCenter => Offset(
        this.canvasOffset.dx + (this.layers.width / 2) * this.layers.scale,
        this.canvasOffset.dy + (this.layers.height / 2) * this.layers.scale,
      );

  void regionErase() {
    if (selectorModel.path1 != null) {
      recordExecuteDrawingActionToSelectedLayer(
        action: UserActionDrawing(
          action: ActionType.cut,
          positions: <ui.Offset>[],
          path: Path.from(selectorModel.path1!),
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
    final ui.Rect bounds = selectorModel.path1!.getBounds();
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
    canvas.clipPath(selectorModel.path1!);

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
        final LayerProvider newLayerForPatedImage =
            layers.addTop(name: 'Pasted');
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
    canvasOffset = Offset.zero;
    layers.scale = 1;
    update();
  }

  //=============================================================================
  // All things Layers
  LayersProvider layers = LayersProvider(); // this is a singleton

  void recordExecuteDrawingActionToSelectedLayer({
    required final UserActionDrawing action,
  }) {
    if (selectorModel.isVisible) {
      action.clipPath = selectorModel.path1;
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

  void canvasPan({
    required final Offset offsetDelta,
    final bool notifyListener = true,
  }) {
    this.canvasOffset += offsetDelta;

    if (this.fillModel.isVisible) {
      this.fillModel.gradientPoints.forEach(
            (final GradientPoint point) => point.offset += offsetDelta,
          );
    }
    if (notifyListener) {
      update();
    }
  }

  /// Centers the canvas within the view.
  ///
  /// This method adjusts the position of the canvas so that it is centered
  /// within the available space. It ensures that the canvas is properly
  /// aligned and visible to the user.
  void canvasFitToContainer({
    required final double containerWidth,
    required final double containerHeight,
  }) {
    //
    // Step 1 Scale
    //
    final double scaleX = containerWidth / this.layers.width;
    final double scaleY = containerHeight / this.layers.height;
    final double targetScale = min(scaleX, scaleY) * 0.95;
    final double adjustedScale = targetScale / this.layers.scale;

    applyScaleToCanvas(
      scaleDelta: adjustedScale,
      anchorPoint: canvasOffset,
      notifyListener: false,
    );

    //
    // Step 2 Pan
    //
    final double offsetX =
        ((containerWidth - (this.layers.width * this.layers.scale)) / 2) -
            this.canvasOffset.dx;
    final double offsetY =
        ((containerHeight - (this.layers.height * this.layers.scale)) / 2) -
            this.canvasOffset.dy;
    final Offset offsetDelta = Offset(offsetX, offsetY);

    this.canvasPan(offsetDelta: offsetDelta, notifyListener: false);
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
        clipPath: selectorModel.isVisible ? selectorModel.path1 : null,
      ),
    );
  }

  void floodFillSolidAction(final Offset position) async {
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
        clipPath: selectorModel.isVisible ? selectorModel.path1 : null,
      ),
    );
  }

  void floodFillGradientAction(final FillModel fillModel) async {
    final Region region = await getRegionPathFromLayerImage(
      fillModel.mode == FillMode.solid
          ? fillModel.centerPoint
          : toCanvas(fillModel.centerPoint),
    );

    final ui.Path path = region.path
        .shift(Offset(region.left.toDouble(), region.top.toDouble()));

    final ui.Rect bounds = path.getBounds();

    final Gradient gradient;
    if (fillModel.mode == FillMode.radial) {
      final ui.Offset centerPoint = toCanvas(fillModel.centerPoint);

      gradient = RadialGradient(
        colors: fillModel.gradientPoints
            .map((final GradientPoint point) => point.color)
            .toList(),
        center: Alignment(
          ((centerPoint.dx - bounds.left) / bounds.width) * 2 - 1,
          ((centerPoint.dy - bounds.top) / bounds.height) * 2 - 1,
        ),
        radius: (fillModel.gradientPoints.last.offset -
                    fillModel.gradientPoints.first.offset)
                .distance /
            bounds.width,
      );
    } else {
      gradient = LinearGradient(
        colors: fillModel.gradientPoints
            .map((final GradientPoint point) => point.color)
            .toList(),
        // stops: <double>[0, 1],
        begin: Alignment(
          (fillModel.gradientPoints.first.offset.dx / bounds.width) * 2 - 1,
          (fillModel.gradientPoints.first.offset.dy / bounds.height) * 2 - 1,
        ),
        end: Alignment(
          (fillModel.gradientPoints.last.offset.dx / bounds.width) * 2 - 1,
          (fillModel.gradientPoints.last.offset.dy / bounds.height) * 2 - 1,
        ),
      );
    }

    recordExecuteDrawingActionToSelectedLayer(
      action: UserActionDrawing(
        action: ActionType.region,
        path: path,
        positions: <ui.Offset>[
          bounds.topLeft,
          bounds.bottomRight,
        ],
        gradient: gradient,
        clipPath: selectorModel.isVisible ? selectorModel.path1 : null,
      ),
    );
  }

  void updateGradientFill() {
    if (this.fillModel.isVisible) {
      _debounceGradientFill.run(
        () {
          this.undoProvider.undo();
          this.floodFillGradientAction(this.fillModel);
          this.update();
        },
      );
    }
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
  // Fill Widget
  FillModel fillModel = FillModel();

  //-------------------------
  Offset? eyeDropPositionForBrush;

  //-------------------------
  Offset? eyeDropPositionForFill;

  //-------------------------
  // Selector
  SelectorModel selectorModel = SelectorModel();

  bool isReadyForDrawing() {
    if (selectedAction == ActionType.selector) {
      return false;
    }
    return true;
  }

  void selectorCreationStart(final Offset position) {
    if (selectorModel.mode == SelectorMode.wand) {
      getRegionPathFromLayerImage(position).then((final Region region) {
        selectorModel.isVisible = true;
        if (selectorModel.math == SelectorMath.replace) {
          selectorModel.path1 = region.path.shift(region.offset);
        } else {
          selectorModel.path2 = region.path.shift(region.offset);
        }
        update();
      });
    } else {
      selectorModel.addP1(position);
      update();
    }
  }

  void selectorCreationAdditionalPoint(final Offset position) {
    if (selectorModel.mode == SelectorMode.wand) {
      // Ignore since the PointerDown it already did the job of drawing the shape of the selector
    } else {
      selectorModel.addP2(position);
      update();
    }
  }

  void selectorCreationEnd() {
    selectorModel.applyMath();
    update();
  }

  void selectAll() {
    selectorModel.isVisible = true;
    selectorCreationStart(Offset.zero);
    selectorModel.path1 = Path()
      ..addRect(
        Rect.fromPoints(Offset.zero, Offset(layers.width, layers.height)),
      );
  }

  Path? getPathAdjustToCanvasSizeAndPosition(final Path? path) {
    if (path != null) {
      final Matrix4 matrix = Matrix4.identity()
        ..translate(canvasOffset.dx, canvasOffset.dy)
        ..scale(layers.scale);
      return path.transform(matrix.storage);
    }
    return null;
  }

  void crop() async {
    final Rect bounds = selectorModel.path1!.getBounds();
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
        selectorModel.clear();
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

  void newDocumentFromClipboardImage() async {
    final ui.Image? clipboardImage = await getImageFromClipboard();
    if (clipboardImage != null) {
      final double width = clipboardImage.width.toDouble();
      final double height = clipboardImage.height.toDouble();
      this.canvasClear(Size(width, height));
      this.layers.selectedLayer.addImage(imageToAdd: clipboardImage);
      this.update();
    }
  }

  //=============================================================================
  /// Notifies all listeners that the model has been updated.
  /// This method should be called whenever the state of the model changes
  /// to ensure that any UI components observing the model are updated.
  void update() {
    notifyListeners();
  }
}
