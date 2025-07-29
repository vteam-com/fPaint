// Imports
import 'dart:async';
import 'dart:math'; // Added for pi
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/render_helper.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:provider/provider.dart';

// Exports
export 'package:fpaint/models/user_action_drawing.dart';

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
    this.parentGroupName = '',
    this.id = '',
    this.isSelected = false,
    final bool isVisible = true,
    final double opacity = 1.0,
  }) : _name = name {
    _size = size;
    _isVisible = isVisible;
    _opacity = opacity;
  }

  /// Retrieves the [LayerProvider] instance from the given [BuildContext].
  ///
  /// The [listen] parameter determines whether the widget should rebuild when the
  /// [LayerProvider]'s state changes.
  static LayerProvider of(
    final BuildContext context, {
    final bool listen = false,
  }) => Provider.of<LayerProvider>(context, listen: listen);

  /// Notifies listeners that the layer has been updated.
  void update() {
    notifyListeners();
  }

  //-----------------------------------------------
  // name
  String _name;

  /// Gets the name of the layer.
  String get name => _name;

  /// Sets the name of the layer.
  set name(final String value) {
    _name = value;
    notifyListeners();
  }

  /// The parent group name of the layer.
  String parentGroupName;

  /// The ID of the layer.
  String id;

  /// The stack of user actions performed on the layer.
  final List<UserActionDrawing> actionStack = <UserActionDrawing>[];

  /// The stack of user actions that have been undone.
  final List<UserActionDrawing> redoStack = <UserActionDrawing>[];

  /// Whether the layer is selected.
  bool isSelected;

  /// Whether to preserve the alpha channel when rendering the layer.
  bool preserveAlpha = true;

  /// The background color of the layer.
  Color? backgroundColor;

  /// The blend mode to use when rendering the layer.
  ui.BlendMode blendMode = ui.BlendMode.srcOver;

  ///-------------------------------------------
  /// Modifed state

  /// Whether the layer has been modified.
  bool hasChanged = false;

  /// Whether the user is currently drawing on the layer.
  bool isUserDrawing = false;

  /// A debouncer to prevent excessive thumbnail updates.
  final Debouncer _debounceTimer = Debouncer();

  /// A callback function that is called when the thumbnail image changes.
  final void Function() onThumnailChanged;
  //---------------------------------------------
  // Size
  Size _size = const Size(0, 0);

  /// Gets the size of the layer.
  Size get size => _size;

  /// Sets the size of the layer.
  set size(final Size value) {
    _size = value;
    clearCache();
  }

  /// The list of top colors used in the layer.
  List<ColorUsage> topColorsUsed = <ColorUsage>[];

  /// Caches the top colors used in the layer.
  void _cacheTopColorsUsed() async {
    topColorsUsed = <ColorUsage>[];
    if (_cachedThumnailImage != null) {
      final List<ColorUsage> imageColors = await getImageColors(_cachedThumnailImage!);

      for (final ColorUsage colorUsage in imageColors) {
        if (!topColorsUsed.any((final ColorUsage c) => c.color == colorUsage.color)) {
          topColorsUsed.add(colorUsage);
        }
      }
    }
  }

  /// Gets the area of the layer that contains content.
  Rect getArea() {
    if (actionStack.isEmpty) {
      return Rect.zero;
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final UserActionDrawing action in actionStack) {
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

  /// Gets whether the layer is visible.
  bool get isVisible => _isVisible;

  /// Sets whether the layer is visible.
  set isVisible(final bool value) {
    _isVisible = value;
    clearCache();
  }

  ///---------------------------------------
  // Opacity
  //
  double _opacity = 1; // 0.0 to 1.0=100%

  /// Gets the opacity of the layer.
  double get opacity => _opacity;

  /// Sets the opacity of the layer.
  set opacity(final double value) {
    _opacity = value;
    clearCache();
  }

  /// Gets the number of actions in the action stack.
  int get count => actionStack.length;

  /// Gets whether the action stack is empty.
  bool get isEmpty => actionStack.isEmpty;

  /// Offsets all actions in the layer by the given offset.
  void offset(final Offset offset) {
    for (final UserActionDrawing action in actionStack) {
      for (int i = 0; i < action.positions.length; i++) {
        action.positions[i] = action.positions[i].translate(offset.dx, offset.dy);
      }
    }
    clearCache();
  }

  /// Scales all actions in the layer by the given scale factor.
  void scale(final double scale) {
    for (final UserActionDrawing action in actionStack) {
      for (int i = 0; i < action.positions.length; i++) {
        action.positions[i] = Offset(
          action.positions[i].dx * scale,
          action.positions[i].dy * scale,
        );
      }
    }
    clearCache();
  }

  /// Rotates all actions and content in the layer by 90 degrees clockwise.
  ///
  /// [oldCanvasSize] is the size of the canvas *before* rotation (width, height will be swapped after this).
  Future<void> rotate90Clockwise(final Size oldCanvasSize) async {
    final double oldCanvasHeight = oldCanvasSize.height;

    final List<UserActionDrawing> newActionStack = <UserActionDrawing>[];

    for (final UserActionDrawing oldAction in actionStack) {
      final List<Offset> newPositions = List<Offset>.from(oldAction.positions);
      for (int i = 0; i < newPositions.length; i++) {
        final Offset oldPos = newPositions[i];
        // Clockwise: (x,y) -> (H_old - y, x)
        newPositions[i] = Offset(oldCanvasHeight - oldPos.dy, oldPos.dx);
      }

      ui.Path? newPath = oldAction.path;
      if (oldAction.path != null) {
        // Matrix for: x' = H - y; y' = x
        // [ 0 -1 H ]
        // [ 1  0 0 ]
        // [ 0  0 1 ]
        final Matrix4 matrix = Matrix4.identity();
        matrix.setEntry(0, 0, 0.0);
        matrix.setEntry(0, 1, -1.0);
        matrix.setEntry(0, 3, oldCanvasHeight); // Translation for x' = H-y
        matrix.setEntry(1, 0, 1.0);
        matrix.setEntry(1, 1, 0.0);
        matrix.setEntry(1, 3, 0.0); // No translation for y'
        newPath = oldAction.path!.transform(matrix.storage);
      }

      ui.Path? newClipPath = oldAction.clipPath;
      if (oldAction.clipPath != null) {
        // Apply the same transformation
        final Matrix4 matrix = Matrix4.identity();
        matrix.setEntry(0, 0, 0.0);
        matrix.setEntry(0, 1, -1.0);
        matrix.setEntry(0, 3, oldCanvasHeight);
        matrix.setEntry(1, 0, 1.0);
        matrix.setEntry(1, 1, 0.0);
        matrix.setEntry(1, 3, 0.0);
        newClipPath = oldAction.clipPath!.transform(matrix.storage);
      }

      ui.Image? newImage = oldAction.image;
      if (oldAction.image != null) {
        final ui.Image originalImage = oldAction.image!;
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(recorder);
        final double newImageWidth = originalImage.height.toDouble();
        final double newImageHeight = originalImage.width.toDouble();

        canvas.translate(newImageWidth / 2, newImageHeight / 2);
        canvas.rotate(-pi / 2); // 90 degrees clockwise (Flutter canvas +angle is CCW)
        canvas.drawImage(
          originalImage,
          Offset(-originalImage.width / 2, -originalImage.height / 2),
          Paint(),
        );
        newImage = await recorder.endRecording().toImage(
          newImageWidth.toInt(),
          newImageHeight.toInt(),
        );
      }

      newActionStack.add(
        UserActionDrawing(
          action: oldAction.action,
          positions: newPositions,
          brush: oldAction.brush,
          fillColor: oldAction.fillColor,
          gradient: oldAction.gradient,
          path: newPath,
          image: newImage,
          clipPath: newClipPath,
        ),
      );
    }

    actionStack.clear();
    actionStack.addAll(newActionStack);

    // The layer's own size will be updated by LayersProvider after all layers are processed.
    clearCache();
  }

  /// Gets the last user action performed on the layer.
  UserActionDrawing? get lastUserAction => actionStack.isEmpty ? null : actionStack.last;

  /// Appends a drawing action to the action stack.
  void appendDrawingAction(final UserActionDrawing userAction) {
    actionStack.add(userAction);
    hasChanged = true;
    clearCache();
  }

  /// Adds an image to the layer.
  UserActionDrawing addImage({
    required final ui.Image imageToAdd,
    final ui.Offset offset = Offset.zero,
    final ActionType tool = ActionType.image,
  }) {
    final UserActionDrawing newAction = UserActionDrawing(
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

    this.appendDrawingAction(newAction);

    return newAction;
  }

  /// Appends a position to the last action.
  void lastActionAppendPosition({required final Offset position}) {
    actionStack.last.positions.add(position);
  }

  /// Updates the last position of the last action.
  void lastActionUpdatePosition(final Offset position) {
    actionStack.last.positions.last = position;
  }

  /// Undoes the last action performed on the layer.
  void undo() {
    if (actionStack.isNotEmpty) {
      redoStack.add(actionStack.removeLast());
      hasChanged = true;
      clearCache();
    }
  }

  /// Redoes the last action that was undone.
  void redo() {
    if (redoStack.isNotEmpty) {
      actionStack.add(this.redoStack.removeLast());
      hasChanged = true;
      clearCache();
    }
  }

  //------------------------------------------------------
  // Thumbnail image
  //
  ui.Image? _cachedImage;

  /// The cached thumbnail image of the layer.
  ui.Image? _cachedThumnailImage;

  /// Gets the thumbnail image of the layer.
  ui.Image? get thumbnailImage => _cachedThumnailImage;

  /// Updates the thumbnail image of the layer.
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

  /// Clears the cached image and thumbnail, and updates the thumbnail.
  void clearCache() {
    _cachedImage = null;
    _cachedThumnailImage = null;
    _debounceTimer.run(() async {
      await updateThumbnail();
      notifyListeners();
    });
  }

  /// Converts the layer to an image for storage.
  ui.Image toImageForStorage(final Size size) {
    return renderImageWH(
      size.width.toInt(),
      size.height.toInt(),
    );
  }

  /// Renders the layer to an image with the given width and height.
  ui.Image renderImageWH(final int width, final int height) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = Canvas(recorder);

    canvas.saveLayer(null, Paint());
    renderLayer(canvas);

    final ui.Picture picture = recorder.endRecording();
    return picture.toImageSync(width, height);
  }

  /// Applies an action to the canvas, clipping it if necessary.
  void applyAction(
    final Canvas canvas,
    final ui.Path? clipPath,
    final void Function(
      Canvas theCanvasToUse,
    )
    actionFunction,
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

  /// Renders the layer to the given canvas.
  void renderLayer(final Canvas canvas) {
    if (_cachedImage != null && isUserDrawing == false) {
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
    for (final UserActionDrawing userAction in actionStack) {
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
              userAction.fillColor,
              userAction.gradient,
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
        case ActionType.text:
          applyAction(
            canvas,
            userAction.clipPath,
            (final Canvas theCanvasToUse) => renderText(
              theCanvasToUse,
              userAction.textObject!,
            ),
          );
          break;
      }
    }

    // Restore the canvas to apply the opacity
    canvas.restore();
  }

  /// Gets a path using flood fill.
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
}
