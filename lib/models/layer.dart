// Imports
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/widgets/transparent_background.dart';

// Exports
export 'package:fpaint/models/user_action.dart';

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
  String id = '';
  final List<UserAction> _actionStack = [];
  final List<UserAction> redoStack = [];
  bool isSelected;

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

  //
  // Visibility
  //
  bool _isVisible = true;
  bool get isVisible => _isVisible;

  set isVisible(bool value) {
    _isVisible = value;
    clearCache();
  }

  //
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
    clearCache();
  }

  UserAction? get lastUserAction =>
      _actionStack.isEmpty ? null : _actionStack.last;

  void addImage(
    ui.Image imageToAdd, {
    Tools tool = Tools.image,
    ui.Offset offset = Offset.zero,
  }) {
    _actionStack.add(
      UserAction(
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
      ),
    );
    clearCache();
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
      clearCache();
    }
  }

  void redo() {
    if (redoStack.isNotEmpty) {
      _actionStack.add(this.redoStack.removeLast());
      clearCache();
    }
  }

  ui.Image? cachedRendering;

  void clearCache() {
    cachedRendering = null; // reset cache
  }

  Future<ui.Image> toImage(final Size size) async {
    cachedRendering ??= await renderImageWH(
      size.width.toInt(),
      size.height.toInt(),
    );
    return cachedRendering!;
  }

  Future<ui.Image> toImageForStorage(final Size size) async {
    return await renderImageWH(
      size.width.toInt(),
      size.height.toInt(),
    );
  }

  Future<ui.Image> getThumbnail(final Size size) async {
    if (cachedRendering == null) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = TransparentBackgroundPainter(40);
      painter.paint(canvas, size);
      renderLayer(canvas);
      final picture = recorder.endRecording();
      cachedRendering =
          await picture.toImage(size.width.toInt(), size.height.toInt());
    }
    return cachedRendering!;
  }

  Future<ui.Image> renderImageWH(final int width, final int height) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = Canvas(recorder);

    canvas.saveLayer(null, Paint());
    renderLayer(canvas);

    final ui.Picture picture = recorder.endRecording();
    return await picture.toImage(width, height);
  }

  /// Each user action are painted on an image and removed
  Future<void> flattenUserActionsToImage() async {
    if (_actionStack.isEmpty) {
      return;
    }

    final Size size = Size(
      _actionStack
          .map(
            (a) => a.positions.map((p) => p.dx).reduce((a, b) => a > b ? a : b),
          )
          .reduce((a, b) => a > b ? a : b),
      _actionStack
          .map(
            (a) => a.positions.map((p) => p.dy).reduce((a, b) => a > b ? a : b),
          )
          .reduce((a, b) => a > b ? a : b),
    );

    final ui.Image image =
        await renderImageWH(size.width.toInt(), size.height.toInt());

    // Clear existing actions
    // _actionStack.clear();

    // Add new image action
    _actionStack.add(
      UserAction(
        tool: Tools.image,
        positions: [Offset.zero, Offset(size.width, size.height)],
        image: image,
        fillColor: Colors.transparent,
        brushColor: Colors.transparent,
        brushSize: 1,
      ),
    );

    clearCache();
  }

  void renderLayer(final Canvas canvas) {
    // Save a layer with opacity applied
    Paint layerPaint = Paint()
      ..color = Colors.black.withAlpha((255 * opacity).toInt());
    canvas.saveLayer(null, layerPaint);

    // Render all actions within the saved layer
    for (final UserAction userAction in _actionStack) {
      final Paint paint = Paint()
        ..color = userAction.fillColor
        ..strokeCap = StrokeCap.round
        ..strokeWidth = userAction.brushSize
        ..style = userAction.tool == Tools.circle ||
                userAction.tool == Tools.rectangle
            ? PaintingStyle.fill // Ensure fill for these tools
            : PaintingStyle.stroke; // Stroke for other tools

      switch (userAction.tool) {
        case Tools.draw:
          renderPath(canvas, paint, userAction);
          break;
        case Tools.line:
          renderLine(canvas, paint, userAction);
          break;
        case Tools.circle:
          renderCircle(canvas, paint, userAction);
          break;
        case Tools.rectangle:
          renderRectangle(canvas, paint, userAction);
          break;
        case Tools.eraser:
          renderEraser(canvas, paint, userAction);
          break;
        case Tools.fill:
        case Tools.image:
          renderImage(canvas, userAction);
          break;
      }
    }

    // Restore the canvas to apply the opacity
    canvas.restore();
  }

  void renderPath(Canvas canvas, Paint paint, UserAction userAction) {
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

  void renderLine(Canvas canvas, Paint paint, UserAction userAction) {
    final path = Path()
      ..moveTo(userAction.positions.first.dx, userAction.positions.first.dy)
      ..lineTo(userAction.positions.last.dx, userAction.positions.last.dy);
    paint.style = PaintingStyle.stroke;
    paint.color = userAction.brushColor;
    applyBrushStyle(canvas, paint, path, userAction);
  }

  void renderCircle(Canvas canvas, Paint paint, UserAction userAction) {
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

  void renderRectangle(Canvas canvas, Paint paint, UserAction userAction) {
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
    final width = image.width;
    final height = image.height;

    final visited = List.generate(
      height,
      (y) => List.filled(width, false),
    );

    final queue = <Offset>[];
    queue.add(position);

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final x = current.dx.round();
      final y = current.dy.round();

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

  void renderEraser(Canvas canvas, Paint paint, UserAction userAction) {
    paint.blendMode = BlendMode.clear;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = userAction.brushSize;
    canvas.drawLine(
      userAction.positions.first,
      userAction.positions.last,
      paint,
    );
  }

  void renderImage(Canvas canvas, UserAction userAction) {
    if (userAction.image != null) {
      canvas.drawImage(userAction.image!, userAction.positions.first, Paint());
    }
  }

  void applyBrushStyle(
    Canvas canvas,
    Paint paint,
    Path path,
    UserAction userAction,
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
    Path path,
    ui.Canvas canvas,
    ui.Paint paint,
    double dashWidth,
    double dashGap,
  ) {
    final Path dashedPath = createDashedPath(
      path,
      dashWidth: dashWidth,
      dashGap: dashGap,
    );
    canvas.drawPath(dashedPath, paint);
  }

  Path createDashedPath(
    Path source, {
    required double dashWidth,
    required double dashGap,
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

  List<String> actionHistory([int? numberOfHistoryAction]) {
    return _actionStack
        .take(numberOfHistoryAction ?? _actionStack.length)
        .map((final UserAction action) => action.toString())
        .toList();
  }
}
