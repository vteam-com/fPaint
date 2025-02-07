// Imports
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/app_model.dart';

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
    clearCache();
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
      brushColor: Colors.transparent,
      fillColor: Colors.transparent,
      brushSize: 0,
      image: imageToAdd,
    );

    _actionStack.add(newAction);
    clearCache();
    return newAction;
  }

  void lastActionAddPosition({required final Offset position}) {
    _actionStack.last.positions.add(position);
    clearCache();
  }

  void lastActionUpdatePositionEnd({required final Offset end}) {
    if (_actionStack.isNotEmpty && _actionStack.last.positions.length >= 2) {
      _actionStack.last.positions.last = end;
      clearCache();
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
          final Paint paint = Paint();
          paint.color = userAction.brushColor;
          paint.strokeWidth = userAction.brushSize;
          paint.style = PaintingStyle.stroke;
          paint.strokeCap = StrokeCap.square;
          renderPencil(canvas, paint, userAction);
          break;

        case Tools.brush:
          final Paint paint = Paint();
          paint.color = userAction.fillColor;
          paint.strokeCap = StrokeCap.round;
          paint.strokeWidth = userAction.brushSize;
          paint.style = PaintingStyle.stroke;
          renderPath(canvas, paint, userAction);
          break;

        case Tools.line:
          final Paint paint = Paint();
          paint.color = userAction.fillColor;
          paint.strokeCap = StrokeCap.round;
          paint.strokeWidth = userAction.brushSize;
          paint.style = PaintingStyle.stroke;
          renderLine(canvas, paint, userAction);
          break;

        case Tools.circle:
          final Paint paint = Paint();
          paint.color = userAction.fillColor;
          paint.strokeCap = StrokeCap.round;
          paint.strokeWidth = userAction.brushSize;
          paint.style = PaintingStyle.fill;
          renderCircle(canvas, paint, userAction);
          break;

        case Tools.rectangle:
          final Paint paint = Paint();
          paint.color = userAction.fillColor;
          paint.strokeCap = StrokeCap.round;
          paint.strokeWidth = userAction.brushSize;
          paint.style = PaintingStyle.fill;
          renderRectangle(canvas, paint, userAction);
          break;

        case Tools.eraser:
          final Paint paint = Paint();
          paint.color = userAction.fillColor;
          paint.strokeCap = StrokeCap.round;
          paint.strokeWidth = userAction.brushSize;
          paint.style = PaintingStyle.stroke;
          renderEraser(canvas, paint, userAction);
          break;

        case Tools.fill:
          final Paint paint = Paint();
          paint.color = userAction.fillColor;
          paint.strokeCap = StrokeCap.round;
          paint.strokeWidth = userAction.brushSize;
          paint.style = PaintingStyle.stroke;
          renderImage(canvas, userAction);

        case Tools.image:
          renderImage(canvas, userAction);
          break;
      }
    }

    // Restore the canvas to apply the opacity
    canvas.restore();
  }

  void renderPath(
    final Canvas canvas,
    final Paint paint,
    final UserAction userAction,
  ) {
    final path = Path()
      ..moveTo(
        userAction.positions.first.dx,
        userAction.positions.first.dy,
      );
    for (final ui.Offset position in userAction.positions) {
      path.lineTo(position.dx, position.dy);
    }
    paint.style = PaintingStyle.stroke;
    paint.color = userAction.brushColor;
    applyBrushStyle(canvas, paint, path, userAction);
  }

  void renderLine(
    final Canvas canvas,
    final Paint paint,
    final UserAction userAction,
  ) {
    final path = Path()
      ..moveTo(userAction.positions.first.dx, userAction.positions.first.dy)
      ..lineTo(userAction.positions.last.dx, userAction.positions.last.dy);
    paint.style = PaintingStyle.stroke;
    paint.color = userAction.brushColor;
    applyBrushStyle(canvas, paint, path, userAction);
  }

  void renderCircle(
    final Canvas canvas,
    final Paint paint,
    final UserAction userAction,
  ) {
    final radius =
        (userAction.positions.first - userAction.positions.last).distance / 2;
    final center = Offset(
      (userAction.positions.first.dx + userAction.positions.last.dx) / 2,
      (userAction.positions.first.dy + userAction.positions.last.dy) / 2,
    );
    canvas.drawCircle(center, radius, paint);
    paint.style = PaintingStyle.stroke;
    paint.color = userAction.brushColor;
    final path = Path()
      ..addOval(
        Rect.fromCircle(
          center: center,
          radius: radius,
        ),
      );
    applyBrushStyle(canvas, paint, path, userAction);
  }

  void renderRectangle(
    final Canvas canvas,
    final Paint paint,
    final UserAction userAction,
  ) {
    if (userAction.positions.length == 2) {
      final rect = Rect.fromPoints(
        userAction.positions.first,
        userAction.positions.last,
      );
      canvas.drawRect(rect, paint);
      paint.style = PaintingStyle.stroke;
      paint.color = userAction.brushColor;
      final path = Path()..addRect(rect);
      applyBrushStyle(canvas, paint, path, userAction);
    }
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

  void renderPencil(
    final Canvas canvas,
    final Paint paint,
    final UserAction userAction,
  ) {
    paint.blendMode = BlendMode.srcATop;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = userAction.brushSize;
    canvas.drawLine(
      userAction.positions.first,
      userAction.positions.last,
      paint,
    );
  }

  void renderEraser(
    final Canvas canvas,
    final Paint paint,
    final UserAction userAction,
  ) {
    paint.blendMode = BlendMode.clear;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = userAction.brushSize;
    canvas.drawLine(
      userAction.positions.first,
      userAction.positions.last,
      paint,
    );
  }

  void renderImage(final Canvas canvas, final UserAction userAction) {
    if (userAction.image != null) {
      canvas.drawImage(userAction.image!, userAction.positions.first, Paint());
    }
  }

  void applyBrushStyle(
    final Canvas canvas,
    final Paint paint,
    final Path path,
    final UserAction userAction,
  ) {
    if (userAction.brushStyle == BrushStyle.dash) {
      drawPath(
        path,
        canvas,
        paint,
        userAction.brushSize * 3,
        userAction.brushSize * 2,
      );
    } else {
      canvas.drawPath(path, paint);
    }
  }

  void drawPath(
    final Path path,
    final ui.Canvas canvas,
    final ui.Paint paint,
    final double dashWidth,
    final double dashGap,
  ) {
    final Path dashedPath = createDashedPath(
      path,
      dashWidth: dashWidth,
      dashGap: dashGap,
    );
    canvas.drawPath(dashedPath, paint);
  }

  Path createDashedPath(
    final Path source, {
    required final double dashWidth,
    required final double dashGap,
  }) {
    final Path dashedPath = Path();
    for (final ui.PathMetric pathMetric in source.computeMetrics()) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        final double nextDashLength = distance + dashWidth;
        dashedPath.addPath(
          pathMetric.extractPath(
            distance,
            nextDashLength.clamp(0.0, pathMetric.length),
          ),
          Offset.zero,
        );
        distance = nextDashLength + dashGap;
      }
    }
    return dashedPath;
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

  Future<List<ColorUsage>> getTopColorUsed() async {
    final colors = <ColorUsage>[];
    if (cachedThumnailImage != null) {
      final List<ColorUsage> imageColors =
          await getImageColors(cachedThumnailImage!);

      for (final ColorUsage colorUsage in imageColors) {
        if (!colors.any((c) => c.color == colorUsage.color)) {
          colors.add(colorUsage);
        }
      }
    }
    return colors;
  }
}
