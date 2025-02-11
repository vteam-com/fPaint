// Imports
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/models/render_helper.dart';

// Exports
export 'package:fpaint/models/user_action.dart';

/// Represents a layer in the painting application.
///
/// A layer contains a stack of user actions, such as drawing, erasing, or adding images.
/// Layers can be made visible or invisible, and their opacity can be adjusted.
/// The layer also provides methods for rendering the layer to an image, managing the undo/redo stack,
/// and merging layers.

class Layer {
  Layer({
    required this.name,
    this.id = '',
    this.isSelected = false,
    bool isVisible = true,
    opacity = 1.0,
  }) {
    _isVisible = isVisible;
    _opacity = opacity;
  }

  String name;
  String id;
  final List<UserAction> _actionStack = [];
  final List<UserAction> redoStack = [];
  bool isSelected;
  bool preserveAlpha = true;
  ui.BlendMode blendMode = ui.BlendMode.srcOver;

  ///-------------------------------------------
  /// Modifed state
  bool hasChanged = true;

  List<ColorUsage> topColorsUsed = [];

  void _cacheTopColorUsed() async {
    topColorsUsed = [];
    if (cachedThumnailImage != null) {
      final List<ColorUsage> imageColors =
          await getImageColors(cachedThumnailImage!);

      for (final ColorUsage colorUsage in imageColors) {
        if (!topColorsUsed.any((c) => c.color == colorUsage.color)) {
          topColorsUsed.add(colorUsage);
        }
      }
    }
  }

  Rect getArea() {
    if (_actionStack.isEmpty) {
      return Rect.zero;
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final UserAction action in _actionStack) {
      for (final ui.Offset position in action.positions) {
        minX = minX < position.dx ? minX : position.dx;
        minY = minY < position.dy ? minY : position.dy;
        maxX = maxX > position.dx ? maxX : position.dx;
        maxY = maxY > position.dy ? maxY : position.dy;
      }
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  ///---------------------------------------
  // Visibility
  //
  bool _isVisible = true;
  bool get isVisible => _isVisible;

  set isVisible(bool value) {
    _isVisible = value;
    clearCache();
  }

  ///---------------------------------------
  // Opacity
  //
  double _opacity = 1; // 0.0 to 1.0=100%

  double get opacity => _opacity;

  set opacity(double value) {
    _opacity = value;
    clearCache();
  }

  int get count => _actionStack.length;
  bool get isEmpty => _actionStack.isEmpty;

  void addUserAction(UserAction userAction) {
    _actionStack.add(userAction);
    hasChanged = true;
  }

  void offset(final Offset offset) {
    for (final UserAction action in _actionStack) {
      for (int i = 0; i < action.positions.length; i++) {
        action.positions[i] =
            action.positions[i].translate(offset.dx, offset.dy);
      }
    }
    clearCache();
  }

  void scale(final double scale) {
    for (final UserAction action in _actionStack) {
      for (int i = 0; i < action.positions.length; i++) {
        action.positions[i] = Offset(
          action.positions[i].dx * scale,
          action.positions[i].dy * scale,
        );
      }
    }
    clearCache();
  }

  UserAction? get lastUserAction =>
      _actionStack.isEmpty ? null : _actionStack.last;

  UserAction addImage({
    required final ui.Image imageToAdd,
    final ui.Offset offset = Offset.zero,
    final Tools tool = Tools.image,
  }) {
    final UserAction newAction = UserAction(
      tool: tool,
      positions: [
        offset,
        Offset(
          offset.dx + imageToAdd.width.toDouble(),
          offset.dy + imageToAdd.height.toDouble(),
        ),
      ],
      brush: MyBrush(
        color: Colors.transparent,
        size: 0,
      ),
      fillColor: Colors.transparent,
      image: imageToAdd,
    );

    _actionStack.add(newAction);
    clearCache();
    return newAction;
  }

  void lastActionAddPosition({required final Offset position}) {
    _actionStack.last.positions.add(position);
  }

  void lastActionUpdatePositionEnd({required final Offset end}) {
    if (_actionStack.isNotEmpty && _actionStack.last.positions.length >= 2) {
      _actionStack.last.positions.last = end;
    }
  }

  void undo() {
    if (_actionStack.isNotEmpty) {
      redoStack.add(_actionStack.removeLast());
      hasChanged = true;
      clearCache();
    }
  }

  void redo() {
    if (redoStack.isNotEmpty) {
      _actionStack.add(this.redoStack.removeLast());
      hasChanged = true;
      clearCache();
    }
  }

  void deleteRegion(final ui.Path path) {
    // TODO
    clearCache();
  }

  void mergeFrom(final Layer layerToMerge) {
    _actionStack.addAll(layerToMerge._actionStack);
    clearCache();
  }

  ui.Image? cachedThumnailImage;

  void clearCache() {
    cachedThumnailImage = null; // reset cache
  }

  Future<ui.Image> toImageForStorage(final Size size) async {
    return await renderImageWH(
      size.width.toInt(),
      size.height.toInt(),
    );
  }

  Future<ui.Image> getThumbnail(final Size size) async {
    if (cachedThumnailImage == null) {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = Canvas(recorder);
      renderLayer(canvas);
      final picture = recorder.endRecording();
      cachedThumnailImage =
          await picture.toImage(size.width.toInt(), size.height.toInt());
      _cacheTopColorUsed();
    }
    return cachedThumnailImage!;
  }

  Future<ui.Image> renderImageWH(final int width, final int height) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = Canvas(recorder);

    canvas.saveLayer(null, Paint());
    renderLayer(canvas);

    final ui.Picture picture = recorder.endRecording();
    return await picture.toImage(width, height);
  }

  void renderLayer(final Canvas canvas) {
    // Save a layer with opacity applied
    final Paint layerPaint = Paint()
      ..color = Colors.black.withAlpha((255 * opacity).toInt())
      ..blendMode = blendMode;
    canvas.saveLayer(null, layerPaint);

    // Render all actions within the saved layer
    for (final UserAction userAction in _actionStack) {
      switch (userAction.tool) {
        case Tools.pencil:
          renderPencil(
            canvas,
            userAction.positions.first,
            userAction.positions.last,
            userAction.brush!,
          );
          break;

        case Tools.brush:
          renderPath(
            canvas,
            userAction.positions,
            userAction.brush!,
            userAction.fillColor!,
          );
          break;

        case Tools.line:
          renderLine(
            canvas,
            userAction.positions.first,
            userAction.positions.last,
            userAction.brush!,
            userAction.fillColor!,
          );
          break;

        case Tools.circle:
          renderCircle(
            canvas,
            userAction.positions.first,
            userAction.positions.last,
            userAction.brush!,
            userAction.fillColor!,
          );
          break;

        case Tools.rectangle:
          renderRectangle(
            canvas,
            userAction.positions.first,
            userAction.positions.last,
            userAction.brush!,
            userAction.fillColor!,
          );
          break;

        case Tools.eraser:
          renderEraser(
            canvas,
            userAction.positions.first,
            userAction.positions.last,
            userAction.brush!.size,
          );
          break;

        case Tools.fill:
          renderFill(
            canvas,
            userAction.positions.first,
            userAction.fillColor!,
            userAction.image!,
          );
          break;

        case Tools.image:
          renderImage(canvas, userAction.positions.first, userAction.image!);
          break;
        case Tools.cut:
        case Tools.selector:
          // the rendering for this tool is done below
          break;
      }
    }

    // Restore the canvas to apply the opacity
    canvas.restore();
  }

  Path getPathUsingFloodFill({
    required final ui.Image image,
    required final Offset position,
    final int tolerance = 1,
  }) {
    final path = Path();
    final int width = image.width;
    final int height = image.height;

    final visited = List.generate(
      height,
      (y) => List.filled(width, false),
    );

    final queue = <Offset>[];
    queue.add(position);

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final int x = current.dx.round();
      final int y = current.dy.round();

      if (x < 0 || x >= width || y < 0 || y >= height) {
        continue;
      }
      if (visited[y][x]) {
        continue;
      }

      visited[y][x] = true;
      path.addRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1));

      // Add adjacent pixels to queue
      queue.add(Offset(x + 1, y.toDouble()));
      queue.add(Offset(x - 1, y.toDouble()));
      queue.add(Offset(x.toDouble(), y + 1));
      queue.add(Offset(x.toDouble(), y - 1));
    }

    return path;
  }

  List<String> actionHistory([final int? numberOfHistoryAction]) {
    return _actionStack
        .take(numberOfHistoryAction ?? _actionStack.length)
        .map((final UserAction action) => action.toString())
        .toList()
        .reversed
        .toList();
  }

  Future<ui.Image> blendWithPreserveAlpha({
    required ui.Image baseImage,
    required ui.Image topImage,
    required BlendMode blendMode,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw the base layer
    canvas.drawImage(baseImage, Offset.zero, Paint());

    // Create a paint object with the blend mode
    Paint paint = Paint()..blendMode = blendMode;

    // Save the alpha channel of the base image
    final alphaRecorder = ui.PictureRecorder();
    final alphaCanvas = Canvas(alphaRecorder);
    alphaCanvas.drawImage(
      baseImage,
      Offset.zero,
      Paint()
        ..colorFilter =
            const ui.ColorFilter.mode(Colors.black, BlendMode.srcIn),
    );
    final alphaPicture = alphaRecorder.endRecording();
    final alphaImage =
        await alphaPicture.toImage(baseImage.width, baseImage.height);

    // Apply the blend mode
    canvas.drawImage(topImage, Offset.zero, paint);

    // Restore the original alpha
    canvas.drawImage(
      alphaImage,
      Offset.zero,
      Paint()..blendMode = BlendMode.dstIn,
    );

    // Convert the picture to an image
    final picture = recorder.endRecording();
    return picture.toImage(baseImage.width, baseImage.height);
  }
}
