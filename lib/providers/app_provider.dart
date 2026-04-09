// Imports

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/image_placement_model.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:fpaint/services/fill_service.dart';
import 'package:vector_math/vector_math_64.dart';

// Exports
export 'package:fpaint/providers/layers_provider.dart';

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
      debugPrint('Failed to load preferences: $error');
      // Fall back to default preferences - they're already initialized
      update();
    }
  }

  /// The application preferences.
  final AppPreferences preferences = AppPreferences();

  /// Preferred app locale, or null to follow system locale.
  Locale? get preferredLocale => preferences.preferredLocale;

  /// Preferred app language code, or null to follow system locale.
  String? get languageCode => preferences.languageCode;

  /// Sets the preferred app language code and notifies listeners.
  Future<void> setLanguageCode(final String? value) async {
    await preferences.setLanguageCode(value);
    update();
  }

  /// Whether the preferences are loaded.
  bool get isPreferencesLoaded => preferences.isLoaded;

  final UndoProvider _undoProvider = UndoProvider();

  /// Gets the undo provider.
  UndoProvider get undoProvider => _undoProvider;

  final Debouncer _debounceGradientFill = Debouncer();

  final FillService _fillService = FillService();

  /// Gets the [AppProvider] instance from the provided [BuildContext].
  ///
  /// If [listen] is true, the returned [AppProvider] instance will notify listeners
  /// when its state changes. Otherwise, the returned instance will not notify
  /// listeners.
  static AppProvider of(
    final BuildContext context, {
    final bool listen = false,
  }) => Provider.of<AppProvider>(context, listen: listen);

  //=============================================================================
  // All things Canvas

  /// The offset of the canvas.
  Offset canvasOffset = Offset.zero;

  /// Clears the canvas.
  void canvasClear(final Size size) {
    layers.clear();
    // Ensure layers.size is explicitly set from the size parameter
    layers.size = size;
    layers.addWhiteBackgroundLayer();
    layers.selectedLayerIndex = 0;
    resetView();
  }

  /// Converts a screen point to a canvas point.
  Offset toCanvas(final Offset point) {
    return (point - canvasOffset) / layers.scale;
  }

  /// Converts a canvas point to a screen point.
  Offset fromCanvas(final Offset point) {
    return (point * layers.scale) + canvasOffset;
  }

  /// Applies a scale to the canvas.
  void applyScaleToCanvas({
    required final double scaleDelta,
    final ui.Offset? anchorPoint, // optional anchoer point
    final bool notifyListener = true,
  }) {
    // Step 1: Convert screen coordinates to canvas coordinates
    final Offset before = anchorPoint == null ? Offset.zero : this.toCanvas(anchorPoint);

    for (final GradientPoint point in this.fillModel.gradientPoints) {
      point.offset = this.toCanvas(point.offset);
    }

    // Step 2: Apply the scale change
    this.layers.scale = this.layers.scale * scaleDelta;

    // Step 3: Calculate the new position on the canvas
    final Offset after = anchorPoint == null ? Offset.zero : this.toCanvas(anchorPoint);

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

  /// Gets the center of the canvas.
  Offset get canvasCenter => Offset(
    this.canvasOffset.dx + (this.layers.width / AppMath.pair) * this.layers.scale,
    this.canvasOffset.dy + (this.layers.height / AppMath.pair) * this.layers.scale,
  );

  /// Erases a region on the canvas.
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

  /// Cuts a region on the canvas.
  Future<void> regionCut() async {
    regionCopy();
    regionErase();
  }

  /// Copies a region on the canvas.
  Future<void> regionCopy() async {
    final ui.Rect bounds = selectorModel.path1!.getBounds();
    if (bounds.isEmpty) {
      // nothing to copy
      return;
    }

    final ui.Image image = layers.selectedLayer.toImageForStorage(this.layers.size);

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

  /// Pastes an image from the clipboard onto the canvas.
  Future<void> paste() async {
    final ui.Image? image = await getImageFromClipboard();
    if (image == null) {
      return;
    }

    // Center the image on the visible canvas area.
    final Offset center = Offset(
      layers.size.width / AppMath.pair,
      layers.size.height / AppMath.pair,
    );
    final Offset initialPosition = Offset(
      center.dx - image.width / AppMath.pair,
      center.dy - image.height / AppMath.pair,
    );

    imagePlacementModel.start(
      imageToPlace: image,
      initialPosition: initialPosition,
    );
    update();
  }

  /// Commits the interactively placed image to a new layer.
  Future<void> confirmImagePlacement() async {
    final ui.Image? sourceImage = imagePlacementModel.image;
    if (sourceImage == null) {
      imagePlacementModel.clear();
      update();
      return;
    }

    // Bake scale + rotation into a new rasterised image.
    final double outWidth = imagePlacementModel.displayWidth;
    final double outHeight = imagePlacementModel.displayHeight;
    final double rotation = imagePlacementModel.rotation;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    canvas.translate(outWidth / AppMath.pair, outHeight / AppMath.pair);
    canvas.rotate(rotation);
    canvas.translate(-outWidth / AppMath.pair, -outHeight / AppMath.pair);
    canvas.drawImageRect(
      sourceImage,
      Rect.fromLTWH(
        0,
        0,
        sourceImage.width.toDouble(),
        sourceImage.height.toDouble(),
      ),
      Rect.fromLTWH(0, 0, outWidth, outHeight),
      Paint()..filterQuality = FilterQuality.high,
    );

    final ui.Image bakedImage = await recorder.endRecording().toImage(outWidth.ceil(), outHeight.ceil());

    final Offset offset = imagePlacementModel.position;
    final int currentIndex = layers.selectedLayerIndex;
    int newLayerIndex = -1;

    _undoProvider.executeAction(
      name: 'Paste',
      forward: () {
        final LayerProvider newLayer = layers.addTop(name: 'Pasted');
        newLayerIndex = layers.getLayerIndex(newLayer);
        newLayer.addImage(imageToAdd: bakedImage, offset: offset);
        update();
      },
      backward: () {
        layers.removeByIndex(newLayerIndex);
        layers.selectedLayerIndex = currentIndex;
        update();
      },
    );

    imagePlacementModel.clear();
    update();
  }

  /// Cancels an in-progress image placement.
  void cancelImagePlacement() {
    imagePlacementModel.clear();
    update();
  }

  /// Gets whether the canvas resize lock aspect ratio is enabled.
  bool get canvasResizeLockAspectRatio => layers.canvasResizeLockAspectRatio;

  /// Sets whether the canvas resize lock aspect ratio is enabled.
  set canvasResizeLockAspectRatio(final bool value) {
    layers.canvasResizeLockAspectRatio = value;
    update();
  }

  //=============================================================================
  // SidePanel Expanded/Collapsed

  /// Resets the view.
  void resetView() {
    canvasOffset = Offset.zero;
    layers.scale = 1;
    update();
  }

  //=============================================================================
  // All things Layers

  /// The layers provider.
  LayersProvider layers = LayersProvider(); // this is a singleton

  /// Records and executes a drawing action to the selected layer.
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

  /// Undoes an action.
  void undoAction() {
    _undoProvider.undo();
    update();
  }

  /// Redoes an action.
  void redoAction() {
    _undoProvider.redo();
    update();
  }

  /// Pans the canvas.
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
        ((containerWidth - (this.layers.width * this.layers.scale)) / AppMath.pair) - this.canvasOffset.dx;
    final double offsetY =
        ((containerHeight - (this.layers.height * this.layers.scale)) / AppMath.pair) - this.canvasOffset.dy;
    final Offset offsetDelta = Offset(offsetX, offsetY);

    this.canvasPan(offsetDelta: offsetDelta, notifyListener: false);
  }

  //=============================================================================
  // All things Tools/UserActions

  //-------------------------
  // Selected Tool
  ActionType _selectedAction = ActionType.brush;

  /// Sets the selected action.
  set selectedAction(final ActionType value) {
    _selectedAction = value;

    if (value != ActionType.fill) {
      // Stop the Flood fill tool when switching to other tools
      fillModel.clear();
    }
    update();
  }

  /// Gets the selected action.
  ActionType get selectedAction => _selectedAction;

  //-------------------------
  // Line Weight

  /// Gets the brush size.
  double get brushSize => preferences.brushSize;

  /// Sets the brush size.
  set brushSize(final double value) {
    preferences.setBrushSize(value);
    update();
  }

  //-------------------------
  // Brush Style
  BrushStyle _brushStyle = BrushStyle.solid;

  /// Gets the brush style.
  BrushStyle get brushStyle => _brushStyle;

  /// Sets the brush style.
  set brushStyle(final BrushStyle value) {
    _brushStyle = value;
    update();
  }

  //-------------------------
  // Brush Color

  /// Gets the brush color.
  Color get brushColor => preferences.brushColor;

  /// Sets the brush color.
  set brushColor(final Color value) {
    preferences.setBrushColor(value);
    update();
  }

  //-------------------------
  // Color for Fill

  /// Gets the fill color.
  Color get fillColor => preferences.fillColor;

  /// Sets the fill color.
  set fillColor(final Color value) {
    preferences.setFillColor(value);
    update();
  }

  //-------------------------
  // Tolerance
  int _tolarance = AppDefaults.tolerance; // Mid point 0..100

  /// Gets the tolerance.
  int get tolerance => _tolarance;

  /// Sets the tolerance.
  set tolerance(final int value) {
    _tolarance = max(1, min(AppLimits.percentMax, value));
    update();
  }

  /// Updates an action.
  void updateAction({
    final Offset? start,
    required final Offset end,
    final ActionType? type,
    final Color? colorFill,
    final Color? colorBrush,
  }) {
    if (start != null && type != null && colorFill != null && colorBrush != null) {
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

  /// Updates the end of an action.
  void updateActionEnd(final Offset position) {
    if (layers.selectedLayer.lastUserAction != null) {
      layers.selectedLayer.lastUserAction!.positions.last = position;
    }
  }

  /// Appends a line from the last user action.
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

  /// Performs a flood fill with a solid color.
  void floodFillSolidAction(final Offset position) async {
    final ui.Image sourceImage = layers.selectedLayer.toImageForStorage(layers.size);
    final UserActionDrawing action = await _fillService.createFloodFillSolidAction(
      sourceImage: sourceImage,
      position: position,
      fillColor: this.fillColor,
      tolerance: this.tolerance,
      clipPath: selectorModel.isVisible ? selectorModel.path1 : null,
    );

    recordExecuteDrawingActionToSelectedLayer(action: action);
  }

  /// Performs a flood fill with a gradient.
  void floodFillGradientAction(final FillModel fillModel) async {
    final ui.Image sourceImage = layers.selectedLayer.toImageForStorage(layers.size);
    final UserActionDrawing action = await _fillService.createFloodFillGradientAction(
      sourceImage: sourceImage,
      fillModel: fillModel,
      tolerance: this.tolerance,
      clipPath: selectorModel.isVisible ? selectorModel.path1 : null,
      toCanvas: this.toCanvas,
    );

    recordExecuteDrawingActionToSelectedLayer(action: action);
  }

  /// Updates the gradient fill.
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

  /// Gets the region path from a layer image.
  Future<FillRegion> getRegionPathFromLayerImage(final ui.Offset position) async {
    return _fillService.getRegionPathFromImage(
      image: layers.selectedLayer.toImageForStorage(layers.size),
      position: position,
      tolerance: this.tolerance,
    );
  }

  //-------------------------
  // Fill Widget

  /// The fill model.
  FillModel fillModel = FillModel();

  //-------------------------
  /// The eye drop position for the brush.
  Offset? eyeDropPositionForBrush;

  //-------------------------
  /// The eye drop position for the fill.
  Offset? eyeDropPositionForFill;

  //-------------------------
  // Selector

  /// The selector model.
  SelectorModel selectorModel = SelectorModel();

  /// The image placement model for interactive paste.
  final ImagePlacementModel imagePlacementModel = ImagePlacementModel();

  /// Starts a selector creation.
  void selectorCreationStart(final Offset position) {
    if (selectorModel.mode == SelectorMode.wand) {
      getRegionPathFromLayerImage(position).then((final FillRegion region) {
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

  /// Adds an additional point to the selector creation.
  void selectorCreationAdditionalPoint(final Offset position) {
    if (selectorModel.mode == SelectorMode.wand) {
      // Ignore since the PointerDown it already did the job of drawing the shape of the selector
    } else {
      selectorModel.addP2(position);
      update();
    }
  }

  /// Ends the selector creation.
  void selectorCreationEnd() {
    selectorModel.applyMath();
    update();
  }

  /// Selects all.
  void selectAll() {
    selectorModel.isVisible = true;
    selectorCreationStart(Offset.zero);
    selectorModel.path1 = Path()
      ..addRect(
        Rect.fromPoints(Offset.zero, Offset(layers.width, layers.height)),
      );
  }

  /// Gets the path adjusted to the canvas size and position.
  Path? getPathAdjustToCanvasSizeAndPosition(final Path? path) {
    if (path != null) {
      final Matrix4 matrix = Matrix4.identity()
        ..translateByVector3(Vector3(canvasOffset.dx, canvasOffset.dy, 0.0))
        ..scaleByVector3(Vector3(layers.scale, layers.scale, layers.scale));
      return path.transform(matrix.storage);
    }
    return null;
  }

  /// Crops the canvas to the current selection bounds.
  Future<void> crop() async {
    final Path? selectionPath = selectorModel.path1;
    if (selectionPath == null) {
      return;
    }

    final int originalWidth = layers.width.toInt();
    final int originalHeight = layers.height.toInt();
    final ui.Path cropPath = Path.from(selectionPath);

    // Derive crop bounds from a rasterized selection mask to avoid geometry edge cases.
    final ui.PictureRecorder maskRecorder = ui.PictureRecorder();
    final ui.Canvas maskCanvas = ui.Canvas(maskRecorder);
    maskCanvas.drawPath(
      cropPath,
      ui.Paint()
        ..color = const ui.Color.fromARGB(
          AppLimits.rgbChannelMax,
          AppLimits.rgbChannelMax,
          AppLimits.rgbChannelMax,
          AppLimits.rgbChannelMax,
        )
        ..style = ui.PaintingStyle.fill,
    );
    final ui.Image selectionMask = await maskRecorder.endRecording().toImage(
      originalWidth,
      originalHeight,
    );

    final Rect? maskBounds = await getNonTransparentBounds(selectionMask);
    if (maskBounds == null || maskBounds.width <= 0 || maskBounds.height <= 0) {
      return;
    }

    final Rect canvasRect = Rect.fromLTWH(0, 0, layers.width, layers.height);
    final Rect bounds = maskBounds.intersect(canvasRect);
    if (bounds.width <= 0 || bounds.height <= 0) {
      return;
    }

    final Size originalSize = layers.size;

    final Map<LayerProvider, List<UserActionDrawing>> originalActions = <LayerProvider, List<UserActionDrawing>>{};
    final Map<LayerProvider, List<UserActionDrawing>> originalRedoActions = <LayerProvider, List<UserActionDrawing>>{};
    final Map<LayerProvider, bool> originalHasChanged = <LayerProvider, bool>{};
    final Map<LayerProvider, Color?> originalBackgroundColors = <LayerProvider, Color?>{};
    final Map<LayerProvider, ui.Image> croppedImages = <LayerProvider, ui.Image>{};

    Rect? finalContentBounds;

    for (final LayerProvider layer in layers.list) {
      originalActions[layer] = List<UserActionDrawing>.from(layer.actionStack);
      originalRedoActions[layer] = List<UserActionDrawing>.from(layer.redoStack);
      originalHasChanged[layer] = layer.hasChanged;
      originalBackgroundColors[layer] = layer.backgroundColor;

      final ui.Image layerImage = layer.renderImageWH(originalWidth, originalHeight);

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      canvas.save();
      canvas.clipPath(cropPath);
      canvas.drawImage(layerImage, Offset.zero, ui.Paint());
      canvas.restore();

      final ui.Image maskedImage = await recorder.endRecording().toImage(originalWidth, originalHeight);
      final ui.Image layerCrop = cropImage(maskedImage, bounds);
      croppedImages[layer] = layerCrop;

      final Rect? layerBounds = await getNonTransparentBounds(layerCrop);
      if (layerBounds != null && layerBounds.width > 0 && layerBounds.height > 0) {
        if (finalContentBounds == null) {
          finalContentBounds = layerBounds;
        } else {
          finalContentBounds = finalContentBounds.expandToInclude(layerBounds);
        }
      }
    }

    final Rect effectiveBounds = finalContentBounds == null
        ? Rect.fromLTWH(0, 0, bounds.width, bounds.height)
        : Rect.fromLTRB(
            finalContentBounds.left.floorToDouble(),
            finalContentBounds.top.floorToDouble(),
            finalContentBounds.right.ceilToDouble(),
            finalContentBounds.bottom.ceilToDouble(),
          );

    if (effectiveBounds.width <= 0 || effectiveBounds.height <= 0) {
      return;
    }

    final Map<LayerProvider, ui.Image> finalImages = <LayerProvider, ui.Image>{};
    for (final LayerProvider layer in layers.list) {
      finalImages[layer] = cropImage(croppedImages[layer]!, effectiveBounds);
    }

    _undoProvider.executeAction(
      name: 'Crop',
      forward: () {
        layers.size = Size(effectiveBounds.width, effectiveBounds.height);

        for (final LayerProvider layer in layers.list) {
          layer.actionStack.clear();
          layer.redoStack.clear();
          layer.backgroundColor = null;
          layer.addImage(
            imageToAdd: finalImages[layer]!,
            offset: Offset.zero,
          );
        }

        selectorModel.clear();
        update();
      },
      backward: () {
        layers.size = originalSize;

        for (final LayerProvider layer in layers.list) {
          layer.actionStack
            ..clear()
            ..addAll(originalActions[layer]!);
          layer.redoStack
            ..clear()
            ..addAll(originalRedoActions[layer]!);
          layer.hasChanged = originalHasChanged[layer]!;
          layer.backgroundColor = originalBackgroundColors[layer];
          layer.clearCache();
        }

        update();
      },
    );
  }

  /// Creates a new document from an image in the clipboard.
  void newDocumentFromClipboardImage() async {
    final ui.Image? clipboardImage = await getImageFromClipboard();
    if (clipboardImage != null) {
      final double width = clipboardImage.width.toDouble();
      final double height = clipboardImage.height.toDouble();
      final Size newCanvasSize = Size(width, height);
      this.canvasClear(newCanvasSize);
      this.layers.selectedLayer.addImage(imageToAdd: clipboardImage);
      this.update();
    } else {
      // Ensure this else block is empty or also has its JULES_DEBUG print statement removed.
    }
  }

  /// Rotates the canvas 90 degrees clockwise.
  Future<void> rotateCanvas90() async {
    await layers.rotateCanvas90Clockwise();
    // After rotation, the view might need to be reset or adjusted.
    // For now, a simple resetView() will ensure it's centered and at 1.0 scale.
    // A more sophisticated approach might try to maintain zoom or fit to screen.
    resetView(); // This also calls update()
  }

  TextObject? selectedTextObject;

  //=============================================================================
  /// Notifies all listeners that the model has been updated.
  /// This method should be called whenever the state of the model changes
  /// to ensure that any UI components observing the model are updated.
  void update() {
    notifyListeners();
  }
}
