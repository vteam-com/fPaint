part of 'layer_provider.dart';

/// One whole-canvas geometric mapping (a 90° rotation or an axis flip),
/// expressed once for every kind of geometry an action carries.
class _CanvasGeometryOp {
  const _CanvasGeometryOp({
    required this.mapPoint,
    required this.mapBox,
    required this.pathMatrix,
    required this.mapImage,
  });

  /// Maps a single canvas point.
  final Offset Function(Offset point) mapPoint;

  /// Maps an axis-aligned box at [origin] of [size] to its transformed box.
  /// Image and text placement use the box's new top-left, not the raw
  /// point-mapping of the old origin.
  final Rect Function(Offset origin, Size size) mapBox;

  /// The same mapping as an affine matrix, applied to paths and clip paths.
  final Matrix4 pathMatrix;

  /// Produces the transformed copy of an action's raster.
  final Future<ui.Image> Function(ui.Image image) mapImage;
}

/// Canvas rotate/flip transforms for [LayerProvider].
///
/// Extracted into a `part of` extension to keep [LayerProvider] under fCheck's
/// per-class LOC limit (same rationale as [LayerLivePreview]). These rebuild the
/// action stack with transformed copies and return the original GPU textures
/// they replaced, so the caller can dispose them through a reachability check.
extension LayerTransform on LayerProvider {
  /// Rotates all actions and content in the layer by 90 degrees clockwise.
  ///
  /// [oldCanvasSize] is the size of the canvas *before* rotation (width, height will be swapped after this).
  ///
  /// Returns the original GPU textures replaced by rotated copies. The caller
  /// ([LayersProvider.rotateCanvas90Clockwise]) disposes them through a
  /// reachability check, so a texture an undo record can still restore is kept.
  Future<List<ui.Image>> rotate90Clockwise(Size oldCanvasSize) {
    final double oldCanvasHeight = oldCanvasSize.height;
    // Clockwise: (x, y) -> (H_old - y, x)
    // [ 0 -1 H ]
    // [ 1  0 0 ]
    // [ 0  0 1 ]
    final Matrix4 matrix = Matrix4.identity()
      ..setEntry(0, 0, 0.0)
      ..setEntry(0, 1, -1.0)
      ..setEntry(0, AppMath.triple, oldCanvasHeight)
      ..setEntry(1, 0, 1.0)
      ..setEntry(1, 1, 0.0)
      ..setEntry(1, AppMath.triple, 0.0);

    // The layer's own size will be updated by LayersProvider after all layers are processed.
    return _transformActionStack(
      _CanvasGeometryOp(
        mapPoint: (Offset point) => Offset(oldCanvasHeight - point.dy, point.dx),
        // After 90° CW the box dimensions swap: newW = oldH, newH = oldW.
        mapBox: (Offset origin, Size size) => Rect.fromLTWH(
          oldCanvasHeight - origin.dy - size.height,
          origin.dx,
          size.height,
          size.width,
        ),
        pathMatrix: matrix,
        mapImage: rotateImage90,
      ),
    );
  }

  /// Flips all actions and content in the layer horizontally (left ↔ right).
  ///
  /// [canvasSize] is the current canvas size used to compute mirrored positions.
  /// Returns the original textures replaced by flipped copies (see [_flip]).
  Future<List<ui.Image>> flipHorizontal(Size canvasSize) => _flip(canvasSize, isHorizontal: true);

  /// Flips all actions and content in the layer vertically (top ↔ bottom).
  ///
  /// [canvasSize] is the current canvas size used to compute mirrored positions.
  /// Returns the original textures replaced by flipped copies (see [_flip]).
  Future<List<ui.Image>> flipVertical(Size canvasSize) => _flip(canvasSize, isHorizontal: false);

  /// Shared implementation for flipping layer content on one axis.
  ///
  /// Returns the original GPU textures replaced by flipped copies. The caller
  /// disposes them through a reachability check, so a texture an undo record can
  /// still restore is kept rather than freed.
  Future<List<ui.Image>> _flip(Size canvasSize, {required bool isHorizontal}) {
    final double extent = isHorizontal ? canvasSize.width : canvasSize.height;
    final Matrix4 matrix = Matrix4.identity();
    if (isHorizontal) {
      matrix
        ..setEntry(0, 0, -1.0)
        ..setEntry(0, AppMath.triple, extent);
    } else {
      matrix
        ..setEntry(1, 1, -1.0)
        ..setEntry(1, AppMath.triple, extent);
    }

    return _transformActionStack(
      _CanvasGeometryOp(
        mapPoint: (Offset point) =>
            isHorizontal ? Offset(extent - point.dx, point.dy) : Offset(point.dx, extent - point.dy),
        mapBox: (Offset origin, Size size) => isHorizontal
            ? Rect.fromLTWH(extent - origin.dx - size.width, origin.dy, size.width, size.height)
            : Rect.fromLTWH(origin.dx, extent - origin.dy - size.height, size.width, size.height),
        pathMatrix: matrix,
        mapImage: (ui.Image image) => flipImage(image, isHorizontal: isHorizontal),
      ),
    );
  }

  /// Rebuilds the action stack with every action's geometry mapped through
  /// [op], then drops the stale render cache.
  ///
  /// Returns the original GPU textures replaced by transformed copies; the
  /// caller disposes them through a reachability check.
  Future<List<ui.Image>> _transformActionStack(_CanvasGeometryOp op) async {
    final List<UserActionDrawing> newActionStack = <UserActionDrawing>[];
    final List<ui.Image> replacedImages = <ui.Image>[];

    for (final UserActionDrawing oldAction in actionStack) {
      final List<Offset> newPositions = oldAction.positions.map(op.mapPoint).toList();

      // For image actions the draw origin must be the top-left of the
      // transformed bounding box, not the raw point-transform of the old origin.
      final ui.Image? oldImage = oldAction.image;
      if (oldAction.action == ActionType.image && oldImage != null) {
        final Rect imageBox = op.mapBox(
          oldAction.positions.first,
          Size(oldImage.width.toDouble(), oldImage.height.toDouble()),
        );
        newPositions[0] = imageBox.topLeft;
        if (newPositions.length > 1) {
          newPositions[1] = imageBox.bottomRight;
        }
      }

      ui.Image? newImage;
      if (oldImage != null) {
        newImage = await op.mapImage(oldImage);
        replacedImages.add(oldImage);
      }

      final TextObject? oldText = oldAction.textObject;
      TextObject? newTextObject;
      if (oldText != null) {
        final Rect bounds = oldText.getBounds();
        newTextObject = oldText.copyWith(position: op.mapBox(bounds.topLeft, bounds.size).topLeft);
      }

      // copyWith preserves the concrete action variant while swapping in the
      // transformed geometry.
      newActionStack.add(
        oldAction.copyWith(
          positions: newPositions,
          path: oldAction.path?.transform(op.pathMatrix.storage),
          image: newImage,
          clipPath: oldAction.clipPath?.transform(op.pathMatrix.storage),
          textObject: newTextObject,
        ),
      );
    }

    actionStack.clear();
    actionStack.addAll(newActionStack);

    clearCache();
    return replacedImages;
  }
}
