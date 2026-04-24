import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/transform_helper.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/fill_service.dart';
import 'package:vector_math/vector_math_64.dart';

/// Selection, region, transform, effect, and crop operations.
extension AppProviderSelection on AppProvider {
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
      update();
    }
  }

  /// Cuts a region on the canvas.
  Future<void> regionCut() async {
    regionCopy();
    regionErase();
  }

  /// Copies a region on the canvas.
  Future<void> regionCopy() async {
    final ui.Image? clippedImage = await createSelectionImage();
    if (clippedImage == null) {
      return;
    }

    await copyImageToClipboard(clippedImage);
  }

  /// Duplicates the current selection without touching system clipboard data.
  Future<void> regionDuplicate() async {
    final ui.Image? clippedImage = await createSelectionImage();
    if (clippedImage == null) {
      return;
    }

    startImagePlacement(clippedImage);
  }

  /// Pastes an image from the clipboard onto the canvas.
  Future<void> paste() async {
    final ui.Image? image = await getImageFromClipboard();
    if (image == null) {
      return;
    }

    startImagePlacement(image);
  }

  /// Renders the active selection bounds into a standalone clipped image.
  ///
  /// When no selection exists the entire active layer is used as the
  /// implicit target (auto-select-all).
  ///
  /// Returns `null` when the computed selection bounds are empty.
  Future<ui.Image?> createSelectionImage() async {
    _ensureSelection();

    final ui.Rect bounds = selectorModel.path1!.getBounds();
    if (bounds.isEmpty) {
      return null;
    }

    final ui.Image image = layers.selectedLayer.toImageForStorage(layers.size);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    canvas.translate(-bounds.left, -bounds.top);
    canvas.clipPath(selectorModel.path1!);
    canvas.drawImage(image, Offset.zero, Paint());

    return recorder.endRecording().toImage(
      bounds.width.toInt(),
      bounds.height.toInt(),
    );
  }

  /// Starts interactive placement for [image], centered on the current canvas.
  void startImagePlacement(final ui.Image image) {
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

    undoProvider.executeAction(
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

  /// Begins a perspective/skew transform on the current selection.
  Future<void> startTransform() async {
    if (!selectorModel.isVisible || selectorModel.path1 == null) {
      return;
    }

    final Rect bounds = selectorModel.path1!.getBounds();
    if (bounds.width <= 0 || bounds.height <= 0) {
      return;
    }

    final ui.Image layerImage = layers.selectedLayer.toImageForStorage(layers.size);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.translate(-bounds.left, -bounds.top);
    canvas.clipPath(selectorModel.path1!);
    canvas.drawImage(layerImage, Offset.zero, Paint());

    final ui.Image clippedImage = await recorder.endRecording().toImage(
      bounds.width.ceil(),
      bounds.height.ceil(),
    );

    transformModel.start(image: clippedImage, bounds: bounds);
    update();
  }

  /// Commits the current transform, erasing the original selection region
  /// and placing the warped result as a new image action.
  Future<void> confirmTransform() async {
    final ui.Image? sourceImage = transformModel.sourceImage;
    if (sourceImage == null) {
      transformModel.clear();
      update();
      return;
    }

    final ui.Image transformedImage = await renderTransformedImage(
      sourceImage,
      transformModel.corners,
      AppInteraction.transformGridSubdivisions,
    );

    final Path erasePath = Path.from(selectorModel.path1!);
    final Rect quadBounds = transformModel.quadBounds;
    final Offset imageOffset = Offset(quadBounds.left, quadBounds.top);

    replaceRegion(
      name: 'Transform',
      erasePath: erasePath,
      replacement: transformedImage,
      offset: imageOffset,
    );

    selectorModel.clear();
    transformModel.clear();
    update();
  }

  /// Cancels an in-progress transform operation.
  void cancelTransform() {
    transformModel.clear();
    update();
  }

  /// Applies a [SelectionEffect] to the pixels under the current selection,
  /// replacing the original region with the processed result.
  ///
  /// When no selection exists the entire active layer is used as the
  /// implicit target (auto-select-all).
  Future<void> applyEffect(final SelectionEffect effect) async {
    _ensureSelection();

    final ui.Image? clippedImage = await createSelectionImage();
    if (clippedImage == null) {
      return;
    }

    final Rect bounds = selectorModel.path1!.getBounds();

    final ui.Image processedImage = await effect.apply(clippedImage);

    replaceRegion(
      name: effect.name,
      erasePath: Path.from(selectorModel.path1!),
      replacement: processedImage,
      offset: Offset(bounds.left, bounds.top),
    );

    update();
  }

  /// Flips the selected region horizontally (left ↔ right).
  ///
  /// When no selection exists the entire active layer is used as the
  /// implicit target (auto-select-all).
  Future<void> flipSelectionHorizontal(final String actionName) async {
    await _flipSelection(actionName, isHorizontal: true);
  }

  /// Flips the selected region vertically (top ↔ bottom).
  ///
  /// When no selection exists the entire active layer is used as the
  /// implicit target (auto-select-all).
  Future<void> flipSelectionVertical(final String actionName) async {
    await _flipSelection(actionName, isHorizontal: false);
  }

  /// Shared implementation for selection-aware flipping.
  Future<void> _flipSelection(
    final String actionName, {
    required final bool isHorizontal,
  }) async {
    _ensureSelection();

    final ui.Image? clippedImage = await createSelectionImage();
    if (clippedImage == null) {
      return;
    }

    final Rect bounds = selectorModel.path1!.getBounds();
    final ui.Image flippedImage = await flipImage(
      clippedImage,
      isHorizontal: isHorizontal,
    );

    replaceRegion(
      name: actionName,
      erasePath: Path.from(selectorModel.path1!),
      replacement: flippedImage,
      offset: Offset(bounds.left, bounds.top),
    );

    update();
  }

  /// Rotates the selected region 90 degrees clockwise.
  ///
  /// The rotated image is centered within the original selection bounds.
  /// When no selection exists the entire active layer is used as the
  /// implicit target (auto-select-all).
  Future<void> rotateSelection90(final String actionName) async {
    _ensureSelection();

    final ui.Image? clippedImage = await createSelectionImage();
    if (clippedImage == null) {
      return;
    }

    final Rect bounds = selectorModel.path1!.getBounds();
    final ui.Image rotatedImage = await rotateImage90(clippedImage);

    // The rotated image has swapped dimensions.  Center it within the
    // original selection bounds so the visual anchor stays consistent.
    final double dx = bounds.left + (bounds.width - rotatedImage.width) / AppMath.pair;
    final double dy = bounds.top + (bounds.height - rotatedImage.height) / AppMath.pair;

    replaceRegion(
      name: actionName,
      erasePath: Path.from(selectorModel.path1!),
      replacement: rotatedImage,
      offset: Offset(dx, dy),
    );

    update();
  }

  /// Erases [erasePath] from the selected layer and places [replacement] at
  /// [offset], wrapped in an undoable action named [name].
  void replaceRegion({
    required final String name,
    required final Path erasePath,
    required final ui.Image replacement,
    required final Offset offset,
  }) {
    undoProvider.executeAction(
      name: name,
      forward: () {
        layers.selectedLayer.appendDrawingAction(
          UserActionDrawing(
            action: ActionType.cut,
            positions: <ui.Offset>[],
            path: erasePath,
          ),
        );
        layers.selectedLayer.addImage(
          imageToAdd: replacement,
          offset: offset,
        );
        update();
      },
      backward: () {
        layers.selectedLayer.undo(); // undo add image
        layers.selectedLayer.undo(); // undo cut
        update();
      },
    );
  }

  /// Starts a selector creation.
  void selectorCreationStart(final Offset position) {
    selectorModel.isDrawing = true;
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
      // Ignore since the PointerDown already did the job
    } else {
      selectorModel.addP2(position);
      update();
    }
  }

  /// Ends the selector creation.
  void selectorCreationEnd() {
    selectorModel.isDrawing = false;
    selectorModel.applyMath();
    update();
  }

  /// Ensures a selection exists. If no selection path is set, selects the
  /// entire canvas so that operations can treat the full layer as the target.
  void _ensureSelection() {
    if (selectorModel.path1 == null) {
      selectAll();
    }
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

  /// Gets the region path from a layer image.
  Future<FillRegion> getRegionPathFromLayerImage(final ui.Offset position) async {
    return fillService.getRegionPathFromImage(
      image: layers.selectedLayer.toImageForStorage(layers.size),
      position: position,
      tolerance: tolerance,
    );
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

    undoProvider.executeAction(
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
}
