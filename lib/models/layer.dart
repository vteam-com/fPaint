// Imports
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/widgets/transparent_background.dart';

// Exports
export 'package:fpaint/models/user_action.dart';

class Layer {
  Layer({required this.name});
  String name;
  final List<UserAction> _actionStack = [];
  List<UserAction> redoStack = [];
  bool isSelected = false;

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
  double _opacity = 100; // 0 to 100 %

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

  void addImage(ui.Image imageToAdd, [ui.Offset offset = Offset.zero]) {
    _actionStack.add(
      UserAction(
        tool: Tools.image,
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

  void appendPositionToLastUserAction(Offset position) {
    _actionStack.last.positions.add(position);
    clearCache();
  }

  void updateLastUserActionEndPosition(Offset position) {
    if (_actionStack.isNotEmpty && _actionStack.last.positions.length >= 2) {
      _actionStack.last.positions.last = position;
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

  void renderLayer(final Canvas canvas) {
    // Save a layer with opacity applied
    Paint layerPaint = Paint()
      ..color = Colors.black.withAlpha((255 * (opacity / 100)).toInt());
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

  void renderEraser(Canvas canvas, Paint paint, UserAction userAction) {
    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
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
}
