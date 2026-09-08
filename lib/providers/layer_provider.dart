// Imports
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/draw_path_helper.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/models/layer_state_snapshot.dart';
import 'package:fpaint/models/render_helper.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/user_action_drawing.dart';

part 'layer_provider_display_cache.dart';
part 'layer_provider_live_preview.dart';
part 'layer_provider_snapshot.dart';
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
    required Size size,
    required this.onThumbnailChanged,
    this.isThumbnailVisible,
    this.parentGroupName = '',
    this.id = '',
    bool isSelected = false,
    bool isVisible = true,
    bool isLocked = false,
    double opacity = 1.0,
  }) {
    _size = size;
    _isSelected = isSelected;
    _isVisible = isVisible;
    _isLocked = isLocked;
    _opacity = opacity;
  }

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
  set name(String value) {
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
  set isSelected(bool value) {
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
  set isLocked(bool value) {
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
  final Debouncer _debounceTimer = Debouncer(AppDefaults.thumbnailDebounceDuration);

  /// A callback function that is called when the thumbnail image changes.
  final void Function() onThumbnailChanged;

  /// Whether the layers panel is on screen. When it is not, thumbnail rebuilds
  /// are deferred (see [thumbnailNeedsRebuild]) instead of run. Null means
  /// always visible.
  final bool Function()? isThumbnailVisible;

  /// Set when a thumbnail rebuild was skipped because the panel was hidden.
  bool thumbnailNeedsRebuild = false;
  //---------------------------------------------
  // Size
  Size _size = const Size(0, 0);

  /// Gets the size of the layer.
  Size get size => _size;

  /// Sets the size of the layer.
  set size(Size value) {
    _size = value;
    clearCache();
  }

  /// The list of top colors used in the layer.
  List<ColorUsage> topColorsUsed = <ColorUsage>[];

  /// Caches the top colors used in the layer.
  void _cacheTopColorsUsed() async {
    topColorsUsed = <ColorUsage>[];
    if (_cachedThumbnailImage != null) {
      final List<ColorUsage> imageColors = await getImageColors(
        _cachedThumbnailImage!,
      );

      for (final ColorUsage colorUsage in imageColors) {
        if (!topColorsUsed.any(
          (ColorUsage c) => c.color == colorUsage.color,
        )) {
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
  set isVisible(bool value) {
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
  set opacity(double value) {
    // Guard against no-op writes: the pixel-brush commit re-assigns the layer's
    // original (unchanged) opacity every stroke, and an unconditional clearCache
    // here would null the incrementally-composited cache and schedule a
    // full-canvas thumbnail rebuild on every commit.
    if (_opacity == value) {
      return;
    }
    _opacity = value;
    clearCache();
  }

  /// Gets the number of actions in the action stack.
  int get count => actionStack.length;

  /// Gets whether the action stack is empty.
  bool get isEmpty => actionStack.isEmpty;

  /// Offsets all actions in the layer by the given offset.
  void offset(Offset offset) {
    for (int index = 0; index < actionStack.length; index++) {
      final UserActionDrawing action = actionStack[index];
      for (int i = 0; i < action.positions.length; i++) {
        action.positions[i] = action.positions[i].translate(
          offset.dx,
          offset.dy,
        );
      }

      if (action.textObject != null) {
        action.textObject!.position = action.textObject!.position.translate(
          offset.dx,
          offset.dy,
        );
      }

      // Geometry lives on the concrete variant, so shifted paths are applied
      // through copyWith rather than mutated in place.
      final ui.Path? shiftedPath = action.path?.shift(offset);
      final ui.Path? shiftedClipPath = action.clipPath?.shift(offset);
      if (shiftedPath != null || shiftedClipPath != null) {
        actionStack[index] = action.copyWith(
          path: shiftedPath,
          clipPath: shiftedClipPath,
        );
      }
    }
    clearCache();
  }

  /// Scales all actions in the layer by the given scale factor.
  void scale(double scale) {
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
  void appendDrawingAction(UserActionDrawing userAction) {
    actionStack.add(userAction);
    hasChanged = true;
    clearCache();
  }

  /// Appends [userAction] without invalidating the render cache.
  ///
  /// For callers that keep the cache valid themselves — the pixel-brush commit
  /// composites its patch straight into [_cachedImage] (see
  /// [composePixelBrushLayerCache]/[installPixelBrushLayerCache]) rather than
  /// paying [clearCache]'s full-stack replay + thumbnail rebuild.
  void appendDrawingActionRetainingCache(UserActionDrawing userAction) {
    actionStack.add(userAction);
    hasChanged = true;
  }

  /// Adds an image to the layer.
  UserActionDrawing addImage({
    required ui.Image imageToAdd,
    ui.Offset offset = Offset.zero,
    ActionType tool = ActionType.image,
  }) {
    final UserActionDrawing newAction = ImageAction(
      action: tool,
      positions: <ui.Offset>[
        offset,
        Offset(
          offset.dx + imageToAdd.width.toDouble(),
          offset.dy + imageToAdd.height.toDouble(),
        ),
      ],
      brush: MyBrush(color: AppColors.transparent, size: 0),
      fillColor: AppColors.transparent,
      image: imageToAdd,
    );

    this.appendDrawingAction(newAction);

    return newAction;
  }

  /// Appends a position to the last action.
  void lastActionAppendPosition({required Offset position}) {
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
  // [clearLivePixelBrushPreview] (in the `LayerLivePreview` extension,
  // layer_provider_live_preview.dart) releases the baseline and patch images and
  // returns [renderLayer] to its normal path.
  ui.Image? _livePreviewBaseline;
  ui.Image? _livePreviewPatchImage;
  ui.Rect? _livePreviewPatchBounds;

  //------------------------------------------------------
  // Freehand-stroke preview (brush / pencil / eraser)
  //
  // During a freehand stroke the layer composites a baseline captured once at
  // stroke start (all committed actions) plus only the in-progress action(s),
  // instead of replaying the whole action stack on every pointer-move frame.
  // This keeps committed history out of the per-frame live preview.
  ui.Image? _strokeBaseline;
  ui.Image? _strokeBaselineDisplay;
  ui.Picture? _strokeBaselinePicture;
  int _strokeBaselineActionCount = 0;

  // Fold cursor for the in-progress stroke: tracks how much of the live stroke
  // has already been baked into [_strokeBaseline]. Each frame only the new
  // segments past this cursor are composited in, so per-frame cost stays
  // O(new points) instead of replaying the whole growing stroke (O(stroke) per
  // frame -> O(stroke^2) over a long drag). [_strokeFoldedActionIndex] is the
  // action currently being folded; [_strokeFoldedPointCount] is how many of its
  // points are already baked.
  int _strokeFoldedActionIndex = 0;
  int _strokeFoldedPointCount = 0;

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

  //------------------------------------------------------
  // Display-resolution projection cache
  //
  // The on-screen canvas is shown far smaller than its native size (a 62 MP
  // canvas fits a viewport at ~15%). Sampling the full-res [_cachedImage] every
  // frame — and rebuilding it per edit — is the dominant cost on large canvases.
  // [_displayCache] is a downscaled copy of this layer's committed content at
  // roughly the on-screen resolution; the live painter draws it (a small blit)
  // instead of the full-res cache. Full resolution is materialized only on
  // demand (export/transform/sampling) via [renderLayer]/[renderImageWH], which
  // never touch this cache. This is the Flutter analog of Krita's "Instant
  // Preview" / Level-of-Detail projection.
  ui.Image? _displayCache;

  /// The scale [_displayCache] was rendered at (displayCache size / canvas size).
  double _displayCacheScale = 0.0;

  /// Guards against overlapping async rebuilds of [_displayCache]. The display
  /// cache's read/write API lives in the `LayerDisplayCache` extension
  /// (layer_provider_display_cache.dart).
  bool _displayCacheBuilding = false;

  /// Clears the cached image and refreshes the thumbnail.
  void clearCache() {
    // Free the full-res render cache now — it is only read inside renderLayer,
    // which null-checks it every paint, so dropping it here can't be drawn stale.
    _cachedImage?.dispose();
    _cachedImage = null;
    // The live-display projection is derived from the same content, so a general
    // edit invalidates it too; the painter rebuilds it on the next frame. (The
    // pixel-brush commit does NOT go through clearCache — it updates the display
    // cache incrementally instead.)
    invalidateDisplayCache();
    // Do NOT dispose _cachedThumbnailImage here. The layers panel holds it in a
    // live ImagePainter, and clearCache only *schedules* the rebuild (debounced),
    // so freeing it now leaves that painter drawing a released image for the
    // frames until then — the "Canvas.drawImageRect called with non-genuine
    // Image" flood. updateThumbnail disposes the old thumbnail and swaps in the
    // new one in one synchronous step, then notifies, so the panel rebuilds
    // before the old texture is freed.
    _debounceTimer.run(() async {
      await updateThumbnail();
      notifyListeners();
    });
  }

  /// Cancels any pending thumbnail rebuilds.
  void cancelPendingThumbnailRebuild() => _debounceTimer.cancel();

  @override
  void dispose() {
    // Cancel the pending thumbnail-rebuild debounce so no timer outlives this
    // layer (e.g. a headless render that never mounts a UI to consume it).
    cancelPendingThumbnailRebuild();
    _cachedImage?.dispose();
    _cachedImage = null;
    _cachedThumbnailImage?.dispose();
    _cachedThumbnailImage = null;
    _strokeBaseline?.dispose();
    _strokeBaseline = null;
    _strokeBaselineDisplay?.dispose();
    _strokeBaselineDisplay = null;
    _strokeBaselinePicture?.dispose();
    _strokeBaselinePicture = null;
    super.dispose();
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
    _strokeBaselineDisplay?.dispose();
    _strokeBaselineDisplay = null;
    _strokeBaselinePicture?.dispose();
    _strokeBaselinePicture = null;

    _strokeBaselineActionCount = actionStack.length;
    _strokeFoldedActionIndex = _strokeBaselineActionCount;
    _strokeFoldedPointCount = 0;

    // Prefer the small on-screen projection. Taking ownership keeps
    // appendDrawingAction/clearCache from disposing it immediately afterwards.
    if (_displayCache != null && supportsIncrementalPixelBrushCache) {
      _strokeBaselineDisplay = _displayCache;
      _displayCache = null;
      _displayCacheScale = 0.0;
      return;
    }

    // Reuse the committed raster when no display projection is available.
    // Taking ownership keeps
    // appendDrawingAction/clearCache from disposing it immediately afterwards.
    if (_cachedImage != null && supportsIncrementalPixelBrushCache) {
      _strokeBaseline = _cachedImage;
      _cachedImage = null;
      return;
    }

    // Recording the committed actions avoids allocating and rasterizing a
    // full-canvas texture on pointer-down. The raster thread replays this
    // picture behind the small active tail until the stroke is committed.
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    _renderActionStack(canvas);
    _strokeBaselinePicture = recorder.endRecording();
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
    _strokeBaselineDisplay?.dispose();
    _strokeBaselineDisplay = null;
    _strokeBaselinePicture?.dispose();
    _strokeBaselinePicture = null;
    _strokeBaselineActionCount = 0;
    _strokeFoldedActionIndex = 0;
    _strokeFoldedPointCount = 0;
  }

  /// Draws the in-progress actions/segments not yet folded into the baseline,
  /// starting at ([_strokeFoldedActionIndex], [_strokeFoldedPointCount]).
  void _renderInProgressTail(ui.Canvas canvas) {
    final int count = actionStack.length;
    int index = _strokeFoldedActionIndex;
    int fromPoint = _strokeFoldedPointCount;
    while (index < count) {
      final UserActionDrawing action = actionStack[index];
      if (fromPoint < action.positions.length) {
        if (fromPoint <= AppMath.zero) {
          _renderAction(canvas, action);
        } else {
          _renderFreehandActionTail(canvas, action, fromPoint);
        }
      }
      if (index < count - AppMath.one) {
        index++;
        fromPoint = AppMath.zero;
      } else {
        break;
      }
    }
  }

  /// Renders only the undrawn tail of a growing pencil/eraser [action], starting
  /// one point back from [fromPoint] so the new segments connect to the already
  /// folded ones without re-drawing them. Only pencil/eraser grow point-by-point;
  /// other action types are always folded whole (via [_renderAction]).
  void _renderFreehandActionTail(
    ui.Canvas canvas,
    UserActionDrawing action,
    int fromPoint,
  ) {
    final List<Offset> tail = action.positions.sublist(fromPoint - AppMath.one);
    // Only freehand strokes can be extended incrementally; every other variant
    // re-renders whole.
    if (action is StrokeAction && (action.action == ActionType.pencil || action.action == ActionType.eraser)) {
      _renderStrokeAction(canvas, action, tail);
      return;
    }
    _renderAction(canvas, action);
  }

  /// Converts the layer to an image for storage.
  ui.Image toImageForStorage(Size size) {
    return renderImageWH(size.width.toInt(), size.height.toInt());
  }

  /// Renders the layer to an image with the given width and height.
  ui.Image renderImageWH(int width, int height) {
    final Rect bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    return renderCanvasImageSync(
      width: width,
      height: height,
      draw: (ui.Canvas canvas) => renderLayer(canvas, compositeBounds: bounds),
    );
  }

  /// Applies an action to the canvas, clipping it if necessary.
  void applyAction(
    Canvas canvas,
    ui.Path? clipPath,
    void Function(Canvas) actionFunction,
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
  void renderLayer(
    Canvas canvas, {
    Rect? compositeBounds,
  }) {
    final Paint layerPaint = Paint()
      ..color = AppColors.black.withAlpha(
        (AppLimits.rgbChannelMax * opacity).toInt(),
      )
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
    //
    // Use the current local clip rather than null bounds. At high zoom the full
    // document can transform to tens of thousands of device pixels; null bounds
    // made Impeller allocate that entire offscreen target even though the outer
    // viewport clips almost all of it. Explicit visible bounds keep the texture
    // viewport-sized and below the GPU's maximum texture dimension.
    final Rect visibleLayerBounds = (compositeBounds ?? canvas.getLocalClipBounds()).intersect(Offset.zero & size);
    if (visibleLayerBounds.isEmpty) {
      return;
    }
    canvas.saveLayer(visibleLayerBounds, layerPaint);
    _renderLayerContents(canvas);
    canvas.restore();
  }

  /// Renders this layer into a viewport-sized target before applying document
  /// pan and zoom. This keeps Impeller's offscreen allocation bounded by the
  /// window even when the document is zoomed far beyond GPU texture limits.
  void renderLayerInViewport(
    Canvas canvas, {
    required Rect viewportBounds,
    required Offset canvasOffset,
    required double canvasScale,
    required Rect visibleCanvasBounds,
  }) {
    final Paint layerPaint = Paint()
      ..color = AppColors.black.withAlpha(
        (AppLimits.rgbChannelMax * opacity).toInt(),
      )
      ..blendMode = blendMode;

    canvas.saveLayer(viewportBounds, layerPaint);
    canvas.translate(canvasOffset.dx, canvasOffset.dy);
    canvas.scale(canvasScale);
    canvas.clipRect(visibleCanvasBounds, doAntiAlias: false);
    _renderLayerContents(canvas);
    canvas.restore();
  }

  /// Draws layer-local content without opening an isolation group.
  void _renderLayerContents(Canvas canvas) {
    if (_tryRenderLivePreview(canvas)) {
      return;
    }

    // Fast freehand-stroke path: draw committed content from a frozen cache or
    // recorded picture, then replay only the active stroke. This avoids any
    // synchronous full-canvas rasterization while pointer events are arriving.
    if ((_strokeBaseline != null || _strokeBaselineDisplay != null || _strokeBaselinePicture != null) &&
        isUserDrawing) {
      final ui.Image? baseline = _strokeBaseline;
      if (baseline != null) {
        canvas.drawImage(baseline, Offset.zero, Paint());
      } else if (_strokeBaselineDisplay != null) {
        final ui.Image displayBaseline = _strokeBaselineDisplay!;
        canvas.drawImageRect(
          displayBaseline,
          Rect.fromLTWH(0, 0, displayBaseline.width.toDouble(), displayBaseline.height.toDouble()),
          Offset.zero & size,
          Paint()..filterQuality = FilterQuality.medium,
        );
      } else {
        canvas.drawPicture(_strokeBaselinePicture!);
      }
      _renderInProgressTail(canvas);
      return;
    }

    if (_cachedImage != null && isUserDrawing == false) {
      canvas.drawImage(_cachedImage!, Offset.zero, Paint());
    } else {
      _renderActionStack(canvas);
    }
  }

  /// Fast live-preview path: composites the captured baseline plus the current
  /// patch without replaying the action stack or touching the cache.
  ///
  /// Returns whether the live-preview path handled rendering.
  bool _tryRenderLivePreview(Canvas canvas) {
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
  void _renderActionStack(Canvas canvas) {
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
  ///
  /// Dispatches on the sealed action variant, so each branch reads exactly the
  /// payload its variant guarantees — no nullable re-checks, and the compiler
  /// flags any new variant that is not handled here.
  void _renderAction(Canvas canvas, UserActionDrawing userAction) {
    switch (userAction) {
      case StrokeAction():
        _renderStrokeAction(canvas, userAction, userAction.positions);

      case RegionAction():
        applyAction(
          canvas,
          userAction.clipPath,
          (Canvas theCanvasToUse) => renderRegion(
            theCanvasToUse,
            userAction.path,
            userAction.fillColor,
            userAction.gradient,
            userAction.halftoneFill,
          ),
        );

      case CutAction():
        renderRegionErase(canvas, userAction.path);

      case ImageAction():
        _renderImageAction(canvas, userAction);

      case TextAction():
        applyAction(
          canvas,
          userAction.clipPath,
          (Canvas theCanvasToUse) => renderText(theCanvasToUse, userAction.textObject),
        );

      case NonRenderingAction():
        // Paint bucket commits as a RegionAction; the selector renders through
        // the selection overlay. Nothing to draw here.
        break;
    }
  }

  /// Renders a [StrokeAction] over [points], which is the whole stroke or the
  /// unrendered tail of one.
  void _renderStrokeAction(Canvas canvas, StrokeAction action, List<Offset> points) {
    // Shape strokes are always constructed with a fill; falling back to the
    // brush color keeps a malformed action from crashing a whole-stack replay.
    final Color fillColor = action.fillColor ?? action.brush.color;
    switch (action.action) {
      case ActionType.pencil:
        applyAction(
          canvas,
          action.clipPath,
          (Canvas theCanvasToUse) => renderPencilStroke(theCanvasToUse, points, action.brush),
        );

      case ActionType.eraser:
        applyAction(
          canvas,
          action.clipPath,
          (Canvas theCanvasToUse) => renderPencilEraserStroke(theCanvasToUse, points, action.brush),
        );

      case ActionType.brush:
        applyAction(
          canvas,
          action.clipPath,
          (Canvas theCanvasToUse) => renderPath(
            theCanvasToUse,
            points,
            action.brush,
            fillColor,
          ),
        );

      case ActionType.line:
        applyAction(
          canvas,
          action.clipPath,
          (Canvas theCanvasToUse) => renderLine(
            theCanvasToUse,
            points.first,
            points.last,
            action.brush,
            fillColor,
          ),
        );

      case ActionType.circle:
        applyAction(
          canvas,
          action.clipPath,
          (Canvas theCanvasToUse) => renderCircle(
            theCanvasToUse,
            points.first,
            points.last,
            action.brush,
            fillColor,
          ),
        );

      case ActionType.rectangle:
        applyAction(
          canvas,
          action.clipPath,
          (Canvas theCanvasToUse) => renderRectangle(
            theCanvasToUse,
            points.first,
            points.last,
            action.brush,
            fillColor,
          ),
        );

      case ActionType.smudge:
      case ActionType.blurBrush:
      case ActionType.fill:
      case ActionType.region:
      case ActionType.cut:
      case ActionType.image:
      case ActionType.selector:
      case ActionType.text:
        // Not stroke-rendered: these arrive as their own action variants.
        break;
    }
  }

  /// Draws an [ImageAction]: a stamped image, or a committed smudge/blur patch.
  void _renderImageAction(Canvas canvas, ImageAction userAction) {
    if (userAction.action == ActionType.smudge || userAction.action == ActionType.blurBrush) {
      applyAction(
        canvas,
        userAction.clipPath,
        // Draw the committed patch with BlendMode.src (replace), not srcOver.
        // The patch already holds the final content for its region, so it must
        // REPLACE (including alpha, for smudge that thins transparency) rather
        // than composite. src also keeps edges opaque at any scale: replaying
        // this action under the display cache's fractional canvas.scale, a
        // clear-then-srcOver pair leaves alpha c+(1-c)² < 1 at anti-aliased
        // edges — the transparent ring that showed as a white rectangle around
        // the stroke. src gives c·1+(1-c)·1 = 1, so no seam and no separate cut.
        (Canvas theCanvasToUse) => theCanvasToUse.drawImage(
          userAction.image,
          userAction.positions.first,
          Paint()
            ..filterQuality = FilterQuality.medium
            ..blendMode = ui.BlendMode.src,
        ),
      );
      return;
    }

    renderImage(canvas, userAction.positions.first, userAction.image);
  }
}
