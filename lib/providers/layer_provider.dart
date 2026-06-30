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

part 'layer_provider_live_preview.dart';
part 'layer_provider_transform.dart';

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
  // The live-preview API ([beginLivePixelBrushPreview], [setLivePixelBrushPatch],
  // [setLivePixelBrushImage], [clearLivePixelBrushPreview], [livePreviewBaseline])
  // lives in the `LayerLivePreview` extension (layer_provider_live_preview.dart).
  ui.Image? _livePreviewBaseline;
  ui.Image? _livePreviewPatchImage;
  ui.Rect? _livePreviewPatchBounds;

  //------------------------------------------------------
  // Freehand-stroke preview (brush / pencil / eraser)
  //
  // During a freehand stroke the layer composites a baseline captured once at
  // stroke start (all committed actions) plus only the in-progress action(s),
  // instead of replaying the whole action stack on every pointer-move frame.
  // This bounds per-frame cost to O(active stroke) rather than O(history).
  ui.Image? _strokeBaseline;
  int _strokeBaselineActionCount = 0;

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
    final ui.Image fullImage = await renderCanvasImage(
      width: size.width.toInt(),
      height: size.height.toInt(),
      draw: renderLayer,
    );
    final ui.Image thumbnail = await resizeImage(
      fullImage,
      scaleSizeTo(size, maxHeight: AppLayout.thumbnailMaxHeight),
    );
    // Dispose old textures before replacing; ui.Images are not GC-freed.
    _cachedImage?.dispose();
    _cachedThumbnailImage?.dispose();
    _cachedImage = fullImage;
    _cachedThumbnailImage = thumbnail;
    _cacheTopColorsUsed();
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
    _cachedImage = await renderCanvasImage(
      width: size.width.toInt(),
      height: size.height.toInt(),
      draw: renderLayer,
    );
  }

  /// Clears the cached image and thumbnail, and updates the thumbnail.
  void clearCache() {
    // Free GPU textures before dropping refs — else every edit leaks a full image.
    _cachedImage?.dispose();
    _cachedThumbnailImage?.dispose();
    _cachedImage = null;
    _cachedThumbnailImage = null;
    _debounceTimer.run(() async {
      await updateThumbnail();
      notifyListeners();
    });
  }

  /// Captures the current committed composite as the baseline for a freehand
  /// stroke (brush/pencil/eraser).
  ///
  /// Call once at stroke start, *before* the active action is appended. During
  /// the stroke [renderLayer] then draws this baseline plus only the in-progress
  /// action(s), avoiding a full action-stack replay on every pointer-move frame.
  /// The baseline is full-opacity content (it mirrors [_renderActionStack], not
  /// [renderLayer]) because the layer opacity/blend is applied by the group
  /// `saveLayer` when the baseline is composited.
  void beginStrokePreview() {
    _strokeBaseline?.dispose();
    _strokeBaseline = null;
    final int width = size.width.toInt();
    final int height = size.height.toInt();
    if (width <= 0 || height <= 0) {
      return;
    }
    _strokeBaselineActionCount = actionStack.length;
    _strokeBaseline = renderCanvasImageSync(
      width: width,
      height: height,
      draw: (final ui.Canvas canvas) {
        canvas.saveLayer(null, Paint());
        _renderActionStack(canvas);
        canvas.restore();
      },
    );
  }

  /// Clears the freehand-stroke baseline, returning [renderLayer] to its normal
  /// path. Call at stroke end (when `isUserDrawing` becomes false).
  ///
  /// Note: [clearCache] deliberately does *not* touch the baseline, because it
  /// fires at stroke start (via [appendDrawingAction]) right after the baseline
  /// is captured.
  void clearStrokePreview() {
    _strokeBaseline?.dispose();
    _strokeBaseline = null;
    _strokeBaselineActionCount = 0;
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
    return renderCanvasImageSync(
      width: width,
      height: height,
      draw: (final ui.Canvas canvas) {
        canvas.saveLayer(null, Paint());
        renderLayer(canvas);
      },
    );
  }

  /// Async counterpart to [toImageForStorage]/[renderImageWH].
  ///
  /// Uses `Picture.toImage()` rather than `toImageSync()`. This matters when the
  /// result is read back with `toByteData()`: reading back a `toImageSync()`
  /// image stalls the GPU for seconds on Impeller, whereas an async `toImage()`
  /// readback is milliseconds.
  Future<ui.Image> toImageForStorageAsync(final Size size) {
    return renderCanvasImage(
      width: size.width.toInt(),
      height: size.height.toInt(),
      draw: (final ui.Canvas canvas) {
        canvas.saveLayer(null, Paint());
        renderLayer(canvas);
      },
    );
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
    final Paint layerPaint = Paint()
      ..color = AppColors.black.withAlpha((AppLimits.rgbChannelMax * opacity).toInt())
      ..blendMode = blendMode;

    // Fast path: when the layer is just its cached raster (not mid-stroke, no
    // live preview), draw it directly with opacity/blend baked into the paint.
    // This avoids an offscreen `saveLayer` per layer every frame — the dominant
    // composite cost with many layers (e.g. an 8-layer document during a
    // smudge/blur stroke repaints all layers each frame).
    if (_livePreviewBaseline == null && _cachedImage != null && !isUserDrawing) {
      canvas.drawImage(_cachedImage!, Offset.zero, layerPaint);
      return;
    }

    // Past the cached fast path we either replay the action stack or run the
    // live-preview composite directly onto the *shared* canvas. Both can contain
    // destination-clearing blends (a committed `cut`/eraser action, or the
    // live-preview region erase), which would punch straight through the layers
    // already drawn beneath this one. A group `saveLayer` is therefore always
    // required here to contain those blends to this layer (it also applies the
    // opacity/blend mode to the composited result).
    canvas.saveLayer(null, layerPaint);

    if (_tryRenderLivePreview(canvas)) {
      canvas.restore();
      return;
    }

    // Fast freehand-stroke path: composite the baseline captured at stroke start
    // (all committed actions) plus only the in-progress action(s). This bounds
    // per-frame cost to O(active stroke) instead of O(history). Clear blends in
    // the active action (e.g. eraser) clear into the baseline within this group
    // `saveLayer`, exactly as a full replay would.
    if (_strokeBaseline != null && isUserDrawing) {
      canvas.drawImage(_strokeBaseline!, Offset.zero, Paint());
      for (int i = _strokeBaselineActionCount; i < actionStack.length; i++) {
        _renderAction(canvas, actionStack[i]);
      }
      canvas.restore();
      return;
    }

    if (_cachedImage != null && isUserDrawing == false) {
      canvas.drawImage(_cachedImage!, Offset.zero, Paint());
    } else {
      _renderActionStack(canvas);
    }

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
