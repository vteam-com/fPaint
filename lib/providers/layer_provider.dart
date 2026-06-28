// Imports
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/render_helper.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:provider/provider.dart';

/// Represents a layer in the painting application.
///
/// A layer contains a stack of user actions, such as drawing, erasing, or adding images.
/// Layers can be made visible or invisible, and their opacity can be adjusted.
/// The layer also provides methods for rendering the layer to an image, managing the undo/redo stack,
/// and merging layers.
class LayerProvider extends ChangeNotifier {
  LayerProvider({
    required this._name,
    required final Size size,
    required this.onThumbnailChanged,
    this.parentGroupName = '',
    this.id = '',
    final bool isSelected = false,
    final bool isVisible = true,
    final bool isLocked = false,
    final double opacity = 1.0,
  }) {
    _size = size;
    _isSelected = isSelected;
    _isVisible = isVisible;
    _isLocked = isLocked;
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

  bool _isSelected = false;

  /// Gets whether the layer is selected.
  bool get isSelected => _isSelected;

  /// Sets whether the layer is selected.
  set isSelected(final bool value) {
    if (_isSelected == value) {
      return;
    }
    _isSelected = value;
    notifyListeners();
  }

  ///---------------------------------------
  // Edit lock
  bool _isLocked = false;

  /// Gets whether the layer is locked against direct edits.
  bool get isLocked => _isLocked;

  /// Sets whether the layer is locked against direct edits.
  set isLocked(final bool value) {
    _isLocked = value;
    notifyListeners();
  }

  /// Whether to preserve the alpha channel when rendering the layer.
  bool preserveAlpha = true;

  /// The background color of the layer.
  Color? backgroundColor;

  /// The blend mode to use when rendering the layer.
  ui.BlendMode blendMode = ui.BlendMode.srcOver;

  ///-------------------------------------------
  /// Modified state

  /// Whether the layer has been modified.
  bool hasChanged = false;

  /// Whether the user is currently drawing on the layer.
  bool isUserDrawing = false;

  /// A debouncer to prevent excessive thumbnail updates.
  final Debouncer _debounceTimer = Debouncer();

  /// A callback function that is called when the thumbnail image changes.
  final void Function() onThumbnailChanged;
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
    if (_cachedThumbnailImage != null) {
      final List<ColorUsage> imageColors = await getImageColors(_cachedThumbnailImage!);

      for (final ColorUsage colorUsage in imageColors) {
        if (!topColorsUsed.any((final ColorUsage c) => c.color == colorUsage.color)) {
          topColorsUsed.add(colorUsage);
        }
      }
    }
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

      if (action.path != null) {
        action.path = action.path!.shift(offset);
      }

      if (action.clipPath != null) {
        action.clipPath = action.clipPath!.shift(offset);
      }

      if (action.textObject != null) {
        action.textObject!.position = action.textObject!.position.translate(offset.dx, offset.dy);
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

      // For image actions the draw origin must be the top-left of the
      // rotated bounding box, not the raw point-transform of the old origin.
      if (oldAction.action == ActionType.image && oldAction.image != null) {
        final double imageWidth = oldAction.image!.width.toDouble();
        final double imageHeight = oldAction.image!.height.toDouble();
        final Offset oldOrigin = oldAction.positions.first;
        // After 90° CW the image dimensions swap: newW = oldH, newH = oldW.
        final Offset newOrigin = Offset(
          oldCanvasHeight - oldOrigin.dy - imageHeight,
          oldOrigin.dx,
        );
        newPositions[0] = newOrigin;
        if (newPositions.length > 1) {
          newPositions[1] = Offset(
            newOrigin.dx + imageHeight,
            newOrigin.dy + imageWidth,
          );
        }
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
        matrix.setEntry(0, AppMath.triple, oldCanvasHeight); // Translation for x' = H-y
        matrix.setEntry(1, 0, 1.0);
        matrix.setEntry(1, 1, 0.0);
        matrix.setEntry(1, AppMath.triple, 0.0); // No translation for y'
        newPath = oldAction.path!.transform(matrix.storage);
      }

      ui.Path? newClipPath = oldAction.clipPath;
      if (oldAction.clipPath != null) {
        // Apply the same transformation
        final Matrix4 matrix = Matrix4.identity();
        matrix.setEntry(0, 0, 0.0);
        matrix.setEntry(0, 1, -1.0);
        matrix.setEntry(0, AppMath.triple, oldCanvasHeight);
        matrix.setEntry(1, 0, 1.0);
        matrix.setEntry(1, 1, 0.0);
        matrix.setEntry(1, AppMath.triple, 0.0);
        newClipPath = oldAction.clipPath!.transform(matrix.storage);
      }

      ui.Image? newImage = oldAction.image;
      if (oldAction.image != null) {
        final ui.Image originalImage = oldAction.image!;
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(recorder);
        final double newImageWidth = originalImage.height.toDouble();
        final double newImageHeight = originalImage.width.toDouble();

        canvas.translate(newImageWidth / AppMath.pair, newImageHeight / AppMath.pair);
        canvas.rotate(-pi / AppMath.pair); // 90 degrees clockwise (Flutter canvas +angle is CCW)
        canvas.drawImage(
          originalImage,
          Offset(-originalImage.width / AppMath.pair, -originalImage.height / AppMath.pair),
          Paint(),
        );
        newImage = await recorder.endRecording().toImage(
          newImageWidth.toInt(),
          newImageHeight.toInt(),
        );
      }

      // Rotate the text object position: (x,y) -> (H_old - y - textHeight, x)
      TextObject? newTextObject;
      if (oldAction.textObject != null) {
        final TextObject t = oldAction.textObject!;
        final Rect bounds = t.getBounds();
        newTextObject = TextObject(
          text: t.text,
          position: Offset(oldCanvasHeight - t.position.dy - bounds.height, t.position.dx),
          color: t.color,
          size: t.size,
          fontFamily: t.fontFamily,
          fontWeight: t.fontWeight,
          fontStyle: t.fontStyle,
          textAlign: t.textAlign,
        );
      }

      newActionStack.add(
        UserActionDrawing(
          action: oldAction.action,
          positions: newPositions,
          brush: oldAction.brush,
          fillColor: oldAction.fillColor,
          gradient: oldAction.gradient,
          halftoneFill: oldAction.halftoneFill,
          path: newPath,
          image: newImage,
          clipPath: newClipPath,
          textObject: newTextObject,
        ),
      );
    }

    actionStack.clear();
    actionStack.addAll(newActionStack);

    // The layer's own size will be updated by LayersProvider after all layers are processed.
    clearCache();
  }

  /// Flips all actions and content in the layer horizontally (left ↔ right).
  ///
  /// [canvasSize] is the current canvas size used to compute mirrored positions.
  Future<void> flipHorizontal(final Size canvasSize) => _flip(canvasSize, isHorizontal: true);

  /// Flips all actions and content in the layer vertically (top ↔ bottom).
  ///
  /// [canvasSize] is the current canvas size used to compute mirrored positions.
  Future<void> flipVertical(final Size canvasSize) => _flip(canvasSize, isHorizontal: false);

  /// Shared implementation for flipping layer content on one axis.
  Future<void> _flip(final Size canvasSize, {required final bool isHorizontal}) async {
    final double extent = isHorizontal ? canvasSize.width : canvasSize.height;
    final List<UserActionDrawing> newActionStack = <UserActionDrawing>[];

    for (final UserActionDrawing oldAction in actionStack) {
      final List<Offset> newPositions = List<Offset>.from(oldAction.positions);
      for (int i = 0; i < newPositions.length; i++) {
        final Offset oldPos = newPositions[i];
        newPositions[i] = isHorizontal ? Offset(extent - oldPos.dx, oldPos.dy) : Offset(oldPos.dx, extent - oldPos.dy);
      }

      // For image actions the draw origin must be the top-left of the
      // mirrored bounding box, not the raw point-mirror of the old origin.
      if (oldAction.action == ActionType.image && oldAction.image != null) {
        final double imageWidth = oldAction.image!.width.toDouble();
        final double imageHeight = oldAction.image!.height.toDouble();
        final Offset oldOrigin = oldAction.positions.first;
        final Offset newOrigin = isHorizontal
            ? Offset(extent - oldOrigin.dx - imageWidth, oldOrigin.dy)
            : Offset(oldOrigin.dx, extent - oldOrigin.dy - imageHeight);
        newPositions[0] = newOrigin;
        if (newPositions.length > 1) {
          newPositions[1] = Offset(
            newOrigin.dx + imageWidth,
            newOrigin.dy + imageHeight,
          );
        }
      }

      final ui.Path? newPath = _transformPath(oldAction.path, extent, isHorizontal: isHorizontal);
      final ui.Path? newClipPath = _transformPath(oldAction.clipPath, extent, isHorizontal: isHorizontal);
      final ui.Image? newImage = await _flipImage(oldAction.image, isHorizontal: isHorizontal);
      final TextObject? newTextObject = _flipTextObject(oldAction.textObject, extent, isHorizontal: isHorizontal);

      newActionStack.add(
        UserActionDrawing(
          action: oldAction.action,
          positions: newPositions,
          brush: oldAction.brush,
          fillColor: oldAction.fillColor,
          gradient: oldAction.gradient,
          halftoneFill: oldAction.halftoneFill,
          path: newPath,
          image: newImage,
          clipPath: newClipPath,
          textObject: newTextObject,
        ),
      );
    }

    actionStack.clear();
    actionStack.addAll(newActionStack);
    clearCache();
  }

  /// Transforms a path for a flip operation.
  ui.Path? _transformPath(
    final ui.Path? path,
    final double extent, {
    required final bool isHorizontal,
  }) {
    if (path == null) {
      return null;
    }
    final Matrix4 matrix = Matrix4.identity();
    if (isHorizontal) {
      matrix.setEntry(0, 0, -1.0);
      matrix.setEntry(0, AppMath.triple, extent);
    } else {
      matrix.setEntry(1, 1, -1.0);
      matrix.setEntry(1, AppMath.triple, extent);
    }
    return path.transform(matrix.storage);
  }

  /// Flips an image horizontally or vertically.
  ///
  /// Delegates to the shared [flipImage] helper.
  Future<ui.Image?> _flipImage(
    final ui.Image? image, {
    required final bool isHorizontal,
  }) async {
    if (image == null) {
      return null;
    }
    return flipImage(image, isHorizontal: isHorizontal);
  }

  /// Flips a text object's position for a flip operation.
  TextObject? _flipTextObject(
    final TextObject? textObject,
    final double extent, {
    required final bool isHorizontal,
  }) {
    if (textObject == null) {
      return null;
    }
    final Rect bounds = textObject.getBounds();
    final Offset oldPos = textObject.position;
    final Offset newPos = isHorizontal
        ? Offset(extent - oldPos.dx - bounds.width, oldPos.dy)
        : Offset(oldPos.dx, extent - oldPos.dy - bounds.height);
    return TextObject(
      text: textObject.text,
      position: newPos,
      color: textObject.color,
      size: textObject.size,
      fontFamily: textObject.fontFamily,
      fontWeight: textObject.fontWeight,
      fontStyle: textObject.fontStyle,
      textAlign: textObject.textAlign,
    );
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
        color: AppColors.transparent,
        size: 0,
      ),
      fillColor: AppColors.transparent,
      image: imageToAdd,
    );

    this.appendDrawingAction(newAction);

    return newAction;
  }

  /// Appends a position to the last action.
  void lastActionAppendPosition({required final Offset position}) {
    actionStack.last.positions.add(position);
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
  // Live pixel-brush preview
  //
  // During a smudge/blur stroke the layer bypasses the action stack and renders
  // from a pre-captured baseline + an incrementally updated patch instead.
  // This avoids clearCache(), action-stack manipulation, and full action replay
  // on every pointer-move event.
  //
  ui.Image? _livePreviewBaseline;
  ui.Image? _livePreviewPatchImage;
  ui.Rect? _livePreviewPatchBounds;

  /// Captures the current layer rendering as the baseline for a pixel-brush stroke.
  ///
  /// Must be called once at the start of a stroke, before any points are
  /// appended. The captured image is composited with subsequent patch updates
  /// by [renderLayer] without touching the action stack or the cache.
  void beginLivePixelBrushPreview() {
    _livePreviewBaseline = renderImageWH(size.width.toInt(), size.height.toInt());
    _livePreviewPatchImage = null;
    _livePreviewPatchBounds = null;
  }

  /// Updates the live patch image composited over the baseline during a stroke.
  void setLivePixelBrushPatch(final ui.Image? image, final ui.Rect? bounds) {
    _livePreviewPatchImage = image;
    _livePreviewPatchBounds = bounds;
  }

  /// Clears all live preview state, returning [renderLayer] to its normal path.
  void clearLivePixelBrushPreview() {
    _livePreviewBaseline = null;
    _livePreviewPatchImage = null;
    _livePreviewPatchBounds = null;
  }

  //------------------------------------------------------
  // Thumbnail image
  //
  ui.Image? _cachedImage;

  /// The cached thumbnail image of the layer.
  ui.Image? _cachedThumbnailImage;

  /// Gets the cached full-resolution image of the layer.
  ui.Image? get cachedImage => _cachedImage;

  /// Gets the thumbnail image of the layer.
  ui.Image? get thumbnailImage => _cachedThumbnailImage;

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
    _cachedThumbnailImage = await resizeImage(
      _cachedImage!,
      scaleSizeTo(size, maxHeight: AppLayout.thumbnailMaxHeight),
    );

    _cacheTopColorsUsed();

    // the latest thumbnail is ready
    this.onThumbnailChanged();
  }

  /// Ensures the per-layer render cache is populated so compositing is fast.
  ///
  /// When [_cachedImage] is already set this is a no-op. Otherwise the layer is
  /// rendered once and the result cached, so subsequent [renderLayer] calls take
  /// the fast [Canvas.drawImage] path rather than replaying the full action stack.
  Future<void> ensureCachePrimed() async {
    if (_cachedImage != null) {
      return;
    }
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = Canvas(recorder);
    renderLayer(canvas);
    _cachedImage = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
  }

  /// Clears the cached image and thumbnail, and updates the thumbnail.
  void clearCache() {
    _cachedImage = null;
    _cachedThumbnailImage = null;
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
      Canvas,
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
  ///
  /// Orchestrates the three rendering paths: a fast live-preview composite, the
  /// cached raster, or a full replay of the action stack. The per-action drawing
  /// lives in [_renderAction] so this method stays a thin dispatcher.
  void renderLayer(final Canvas canvas) {
    // Save a layer with opacity and blend mode applied
    final Paint layerPaint = Paint();
    layerPaint.color = AppColors.black.withAlpha((AppLimits.rgbChannelMax * opacity).toInt());
    layerPaint.blendMode = blendMode;

    canvas.saveLayer(null, layerPaint);

    if (_tryRenderLivePreview(canvas)) {
      // Restore the canvas to apply the opacity and blend mode
      canvas.restore();
      return;
    }

    if (_cachedImage != null && isUserDrawing == false) {
      canvas.drawImage(_cachedImage!, Offset.zero, Paint());
    } else {
      _renderActionStack(canvas);
    }

    // Restore the canvas to apply the opacity and blend mode
    canvas.restore();
  }

  /// Fast live-preview path: composites the captured baseline plus the current
  /// patch without replaying the action stack or touching the cache.
  ///
  /// Returns whether the live-preview path handled rendering.
  bool _tryRenderLivePreview(final Canvas canvas) {
    final ui.Image? baseline = _livePreviewBaseline;
    if (baseline == null) {
      return false;
    }

    canvas.drawImage(baseline, Offset.zero, Paint());
    final ui.Image? patch = _livePreviewPatchImage;
    final ui.Rect? patchBounds = _livePreviewPatchBounds;
    if (patch != null && patchBounds != null) {
      renderRegionErase(canvas, Path()..addRect(patchBounds));
      canvas.drawImage(patch, patchBounds.topLeft, Paint());
    }
    return true;
  }

  /// Replays the full action stack onto [canvas], first painting the optional
  /// background fill.
  void _renderActionStack(final Canvas canvas) {
    if (backgroundColor != null) {
      final Paint bgPaint = Paint();
      bgPaint.color = backgroundColor!;
      canvas.drawRect(
        Rect.fromPoints(const Offset(0, 0), Offset(size.width, size.height)),
        bgPaint,
      );
    }

    for (final UserActionDrawing userAction in actionStack) {
      _renderAction(canvas, userAction);
    }
  }

  /// Renders a single [userAction] onto [canvas] using the matching draw helper.
  void _renderAction(final Canvas canvas, final UserActionDrawing userAction) {
    switch (userAction.action) {
      case ActionType.pencil:
        applyAction(
          canvas,
          userAction.clipPath,
          (final Canvas theCanvasToUse) => renderPencilStroke(
            theCanvasToUse,
            userAction.positions,
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

      case ActionType.smudge:
      case ActionType.blurBrush:
        if (userAction.image != null) {
          applyAction(
            canvas,
            userAction.clipPath,
            (final Canvas theCanvasToUse) => renderImage(
              theCanvasToUse,
              userAction.positions.first,
              userAction.image!,
            ),
          );
        }
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
            userAction.halftoneFill,
          ),
        );
        break;

      case ActionType.eraser:
        applyAction(
          canvas,
          userAction.clipPath,
          (final Canvas theCanvasToUse) => renderPencilEraserStroke(
            theCanvasToUse,
            userAction.positions,
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
        // the rendering for this tool is done elsewhere
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
}
