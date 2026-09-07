part of 'app_provider.dart';

/// Owns the state of an in-progress pixel-brush (smudge/blur) or paint-mode
/// effect stroke, plus the per-session smudge source cache.
///
/// Follows the [WandSelectionManager] pattern: a plain state owner living on
/// [AppProvider], so the gesture widget only routes pointer events while the
/// stroke lifecycle and the commit pipeline live in the provider layer (see
/// [AppProviderPixelBrush]).
class PixelBrushStrokeSession {
  /// Canvas clip path active when the stroke began (may be null).
  ui.Path? clipPath;

  /// Monotonic token that invalidates a stale one-shot commit render when a
  /// new stroke starts (or this one is cleared) while it is still rasterizing.
  int generation = 0;

  /// Intensity captured when the current stroke started.
  double intensity = AppInteraction.pixelBrushDefaultIntensity;

  /// Whether the active gesture is a paint-mode effect stroke: it reuses the
  /// pixel-brush gesture capture but commits the armed Adjust effect on
  /// pointer-up instead of a smudge/blur dab.
  bool isEffectBrushStroke = false;

  /// Layer state captured before the stroke so it can be restored on undo.
  ImagePlacementLayerRestoreState? layerRestoreState;

  /// Which pixel-manipulation mode is active for the current stroke.
  PixelBrushMode mode = PixelBrushMode.smudge;

  /// Bounds enclosing the stroke's dab footprints; the committed patch's
  /// preferred bounds.
  ui.Rect? patchBounds;

  /// All accumulated stroke points since the stroke began (canvas space).
  final List<Offset> strokePoints = <Offset>[];

  // Smudge source cache: CPU pixels of a region of the selected layer, read
  // back once per session (the GPU→CPU readback is the fixed multi-second
  // stall) and kept current by blitting committed strokes back in.
  Uint8List? _sourceBytes;
  int _sourceHeight = 0;
  int _sourceRegionLeft = 0;
  int _sourceRegionTop = 0;
  List<int>? _sourceSignature;
  int _sourceWidth = 0;

  /// Whether a stroke gesture (pixel brush or effect brush) is being tracked.
  bool get isStrokeActive => layerRestoreState != null || isEffectBrushStroke;

  /// The cached source bytes, or null when the cache is cold.
  Uint8List? get sourceBytes => _sourceBytes;

  /// Left edge (canvas space) of the cached source region.
  int get sourceRegionLeft => _sourceRegionLeft;

  /// Top edge (canvas space) of the cached source region.
  int get sourceRegionTop => _sourceRegionTop;

  /// Width in pixels (and row stride) of the cached source region.
  int get sourceWidth => _sourceWidth;

  /// Appends a sampled pointer position to the active stroke, expanding the
  /// patch bounds by the dab footprint. Points closer than the resolved step
  /// spacing are skipped.
  void appendPoint(Offset position, double brushSize) {
    final double spacing = resolvePixelBrushStepSpacing(brushSize);
    if (strokePoints.isNotEmpty && (strokePoints.last - position).distance < spacing) {
      return;
    }
    strokePoints.add(position);

    final double radius = max(
      AppInteraction.smudgeMinimumRadius,
      brushSize * AppInteraction.smudgeBrushRadiusFactor,
    );
    final double padding = (radius.ceil() + AppInteraction.smudgeBoundsPadding).toDouble();
    final ui.Rect pointBounds = ui.Rect.fromLTRB(
      position.dx - padding,
      position.dy - padding,
      position.dx + padding + AppMath.one.toDouble(),
      position.dy + padding + AppMath.one.toDouble(),
    );
    patchBounds = patchBounds == null ? pointBounds : patchBounds!.expandToInclude(pointBounds);
  }

  /// Clears the in-progress stroke state, invalidating any in-flight commit
  /// render via the generation token. The source cache is kept (see
  /// [clearSourceCache]).
  void clearStroke() {
    generation++;
    strokePoints.clear();
    layerRestoreState = null;
    clipPath = null;
    patchBounds = null;
    isEffectBrushStroke = false;
  }

  /// Frees the smudge source region cache (a large CPU buffer) — on tool
  /// change or teardown.
  void clearSourceCache() {
    _sourceBytes = null;
    _sourceRegionLeft = 0;
    _sourceRegionTop = 0;
    _sourceWidth = 0;
    _sourceHeight = 0;
    _sourceSignature = null;
  }

  /// Whether the cached source region is valid for [signature] and fully
  /// covers the crop rectangle.
  bool isSourceCacheValidFor({
    required List<int> signature,
    required int cropLeft,
    required int cropTop,
    required int cropRight,
    required int cropBottom,
  }) {
    return _sourceBytes != null &&
        listEquals(_sourceSignature, signature) &&
        cropLeft >= _sourceRegionLeft &&
        cropTop >= _sourceRegionTop &&
        cropRight <= _sourceRegionLeft + _sourceWidth &&
        cropBottom <= _sourceRegionTop + _sourceHeight;
  }

  /// Stores freshly read-back source [bytes] covering the given region.
  void storeSourceCache({
    required Uint8List bytes,
    required int regionLeft,
    required int regionTop,
    required int regionWidth,
    required int regionHeight,
  }) {
    _sourceBytes = bytes;
    _sourceRegionLeft = regionLeft;
    _sourceRegionTop = regionTop;
    _sourceWidth = regionWidth;
    _sourceHeight = regionHeight;
  }

  /// Records the signature the cached source bytes correspond to.
  void setSourceSignature(List<int> signature) {
    _sourceSignature = signature;
  }

  /// Blits a patch's pixels back into the cached source region (destination in
  /// region-local coordinates, stride [sourceWidth]).
  void blitIntoSourceCache({
    required Uint8List region,
    required int regionWidth,
    required int regionHeight,
    required int destLeft,
    required int destTop,
  }) {
    final Uint8List? dest = _sourceBytes;
    if (dest == null) {
      return;
    }
    final int rowBytes = regionWidth * AppMath.bytesPerPixel;
    for (int row = AppMath.zero; row < regionHeight; row++) {
      final int destOffset = (((destTop + row) * _sourceWidth) + destLeft) * AppMath.bytesPerPixel;
      dest.setRange(destOffset, destOffset + rowBytes, region, row * rowBytes);
    }
  }
}
