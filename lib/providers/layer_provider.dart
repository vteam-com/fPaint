// Imports
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/render_helper.dart';
import 'package:fpaint/models/user_action.dart';
import 'package:provider/provider.dart';

// Exports
export 'package:fpaint/models/user_action.dart';

/// Represents a layer in the painting application.
///
/// A layer contains a stack of user actions, such as drawing, erasing, or adding images.
/// Layers can be made visible or invisible, and their opacity can be adjusted.
/// The layer also provides methods for rendering the layer to an image, managing the undo/redo stack,
/// and merging layers.

class LayerProvider extends ChangeNotifier {
  LayerProvider({
    required final String name,
    required final Size size,
    required this.onThumnailChanged,
    this.id = '',
    this.isSelected = false,
    final bool isVisible = true,
    final double opacity = 1.0,
  }) : _name = name {
    _size = size;
    _isVisible = isVisible;
    _opacity = opacity;
  }

  static LayerProvider of(
    final BuildContext context, {
    final bool listen = false,
  }) =>
      Provider.of<LayerProvider>(context, listen: listen);

  void update() {
    notifyListeners();
  }

  //-----------------------------------------------
  // name
  String _name;
  String get name => _name;
  set name(final String value) {
    _name = value;
    notifyListeners();
  }

  String id;
  final List<UserAction> _actionStack = <UserAction>[];
  final List<UserAction> redoStack = <UserAction>[];
  bool isSelected;
  bool preserveAlpha = true;
  Color? backgroundColor;
  ui.BlendMode blendMode = ui.BlendMode.srcOver;

  ///-------------------------------------------
  /// Modifed state
  bool hasChanged = true;
  final Debouncer _debounceTimer = Debouncer();
  final void Function() onThumnailChanged;
  //---------------------------------------------
  // Size
  Size _size = const Size(0, 0);

  Size get size => _size;

  set size(final Size value) {
    _size = value;
    clearCache();
  }

  List<ColorUsage> topColorsUsed = <ColorUsage>[];

  void _cacheTopColorsUsed() async {
    topColorsUsed = <ColorUsage>[];
    if (_cachedThumnailImage != null) {
      final List<ColorUsage> imageColors =
          await getImageColors(_cachedThumnailImage!);

      for (final ColorUsage colorUsage in imageColors) {
        if (!topColorsUsed
            .any((final ColorUsage c) => c.color == colorUsage.color)) {
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

  set isVisible(final bool value) {
    _isVisible = value;
    clearCache();
  }

  ///---------------------------------------
  // Opacity
  //
  double _opacity = 1; // 0.0 to 1.0=100%

  double get opacity => _opacity;

  set opacity(final double value) {
    _opacity = value;
    clearCache();
  }

  int get count => _actionStack.length;
  bool get isEmpty => _actionStack.isEmpty;

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

  void addUserAction(final UserAction userAction) {
    _actionStack.add(userAction);
    hasChanged = true;
    clearCache();
  }

  UserAction addImage({
    required final ui.Image imageToAdd,
    final ui.Offset offset = Offset.zero,
    final ActionType tool = ActionType.image,
  }) {
    final UserAction newAction = UserAction(
      action: tool,
      positions: <ui.Offset>[
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

    this.addUserAction(newAction);
    return newAction;
  }

  void lastActionAppendPosition({required final Offset position}) {
    _actionStack.last.positions.add(position);
    clearCache();
  }

  void lastActionUpdatePosition(final Offset position) {
    _actionStack.last.positions.last = position;
    clearCache();
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

  void regionCut(final ui.Path path) {
    addUserAction(
      UserAction(
        action: ActionType.cut,
        positions: <ui.Offset>[],
        path: Path.from(path),
      ),
    );
    clearCache();
  }

  void mergeFrom(final LayerProvider layerToMerge) {
    _actionStack.addAll(layerToMerge._actionStack);
    clearCache();
  }

  //------------------------------------------------------
  // Thumbnail image
  //
  ui.Image? _cachedImage;
  ui.Image? _cachedThumnailImage;
  ui.Image? get thumbnailImage => _cachedThumnailImage;

  Future<void> updateThumbnail() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = Canvas(recorder);
    renderLayer(canvas);
    final ui.Picture picture = recorder.endRecording();

    // Cache the full size image of this layer
    _cachedImage = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );

    // Cache the thumbnail version
    _cachedThumnailImage = await resizeImage(
      _cachedImage!,
      scaleSizeTo(size, maxHeight: 64),
    );

    _cacheTopColorsUsed();

    // the latest thumbnail is ready
    this.onThumnailChanged();
  }

  void clearCache() {
    _cachedImage = null;
    _debounceTimer.run(() async {
      await updateThumbnail();
      notifyListeners();
    });
  }

  ui.Image toImageForStorage(final Size size) {
    return renderImageWH(
      size.width.toInt(),
      size.height.toInt(),
    );
  }

  ui.Image renderImageWH(final int width, final int height) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = Canvas(recorder);

    canvas.saveLayer(null, Paint());
    renderLayer(canvas);

    final ui.Picture picture = recorder.endRecording();
    return picture.toImageSync(width, height);
  }

  void applyAction(
    final Canvas canvas,
    final ui.Path? clipPath,
    final void Function(
      Canvas theCanvasToUse,
    ) actionFunction,
  ) {
    if (clipPath != null) {
      canvas.save();
      // Apply the clip path to restrict rendering to this area
      canvas.clipPath(clipPath, doAntiAlias: true);
    }

    actionFunction(canvas);

    if (clipPath != null) {
      canvas.restore();
    }
  }

  void renderLayer(final Canvas canvas) {
    if (_cachedImage != null) {
      //print('RenderLayer "$name" USE CACHE ');
      return canvas.drawImage(_cachedImage!, Offset.zero, Paint());
    }

    //print('RenderLayer "$name" FULL RENDER');

    // Save a layer with opacity applied
    final Paint layerPaint = Paint();
    layerPaint.color = Colors.black.withAlpha((255 * opacity).toInt());
    layerPaint.blendMode = blendMode;

    canvas.saveLayer(null, layerPaint);

    if (backgroundColor != null) {
      layerPaint.color = backgroundColor!;
      canvas.drawRect(
        Rect.fromPoints(const Offset(0, 0), Offset(size.width, size.height)),
        layerPaint,
      );
    }

    // Render all actions within the saved layer
    for (final UserAction userAction in _actionStack) {
      switch (userAction.action) {
        case ActionType.pencil:
          applyAction(
            canvas,
            userAction.clipPath,
            (final Canvas theCanvasToUse) => renderPencil(
              theCanvasToUse,
              userAction.positions.first,
              userAction.positions.last,
              userAction.brush!,
            ),
          );
          break;

        case ActionType.brush:
          applyAction(
            canvas,
            userAction.clipPath,
            (final Canvas theCanvasToUse) => renderPath(
              theCanvasToUse,
              userAction.positions,
              userAction.brush!,
              userAction.fillColor!,
            ),
          );
          break;

        case ActionType.line:
          applyAction(
            canvas,
            userAction.clipPath,
            (final Canvas theCanvasToUse) => renderLine(
              theCanvasToUse,
              userAction.positions.first,
              userAction.positions.last,
              userAction.brush!,
              userAction.fillColor!,
            ),
          );

          break;

        case ActionType.circle:
          applyAction(
            canvas,
            userAction.clipPath,
            (final Canvas theCanvasToUse) => renderCircle(
              theCanvasToUse,
              userAction.positions.first,
              userAction.positions.last,
              userAction.brush!,
              userAction.fillColor!,
            ),
          );
          break;

        case ActionType.rectangle:
          applyAction(
            canvas,
            userAction.clipPath,
            (final Canvas theCanvasToUse) => renderRectangle(
              theCanvasToUse,
              userAction.positions.first,
              userAction.positions.last,
              userAction.brush!,
              userAction.fillColor!,
            ),
          );
          break;

        case ActionType.fill:
          // the fill action is added to the layer
          // as a ActionType.region
          break;

        case ActionType.region:
          applyAction(
            canvas,
            userAction.clipPath,
            (final Canvas theCanvasToUse) => renderRegion(
              theCanvasToUse,
              userAction.path!,
              userAction.fillColor!,
            ),
          );
          break;

        case ActionType.eraser:
          applyAction(
            canvas,
            userAction.clipPath,
            (final Canvas theCanvasToUse) => renderPencilEraser(
              theCanvasToUse,
              userAction.positions.first,
              userAction.positions.last,
              userAction.brush!,
            ),
          );
          break;

        case ActionType.cut:
          renderRegionErase(canvas, userAction.path!);
          break;

        case ActionType.image:
          renderImage(canvas, userAction.positions.first, userAction.image!);
          break;

        case ActionType.selector:
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
    final ui.Path path = Path();
    final int width = image.width;
    final int height = image.height;

    final List<List<bool>> visited = List<List<bool>>.generate(
      height,
      (final int y) => List<bool>.filled(width, false),
    );

    final List<ui.Offset> queue = <Offset>[];
    queue.add(position);

    while (queue.isNotEmpty) {
      final ui.Offset current = queue.removeAt(0);
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

  String getHistoryStringForUndo() {
    return getHistoryString(_actionStack);
  }

  String getHistoryStringForRedo() {
    return getHistoryString(redoStack);
  }

  String getHistoryString(final List<UserAction> list) {
    try {
      return this.getActionsAsStrings(list, 20).join('\n');
    } catch (error) {
      debugPrint(error.toString());
      return 'error';
    }
  }

  List<String> getActionsAsStrings(
    final List<UserAction> list, [
    final int? numberOfHistoryAction,
  ]) {
    return list
        .take(numberOfHistoryAction ?? list.length)
        .map((final UserAction action) => action.toString())
        .toList()
        .reversed
        .toList();
  }
}
